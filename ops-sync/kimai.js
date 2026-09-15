// Kimai client, event→project matcher, and calendar-vs-timesheet gap analysis.
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { TZ, localDay, fromKimaiIso, toKimaiLocal, weekStart, addDays, fmtHours, todayLocal } from "./tz.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const MAP_PATH = process.env.OPS_KIMAI_MAP ?? path.join(__dirname, "kimai-map.json");

export function kimaiBase() {
  return (process.env.KIMAI_API_URL || "https://time.cloudigan.net/api").replace(/\/+$/, "");
}

export function kimaiWebBase() {
  return kimaiBase().replace(/\/api$/, "");
}

export function isKimaiConfigured() {
  return Boolean(process.env.KIMAI_API_TOKEN);
}

export function loadKimaiMap() {
  const base = fs.existsSync(MAP_PATH) ? JSON.parse(fs.readFileSync(MAP_PATH, "utf8")) : { lifeAreas: ["cloudigan"], customers: {} };
  const extraPath = process.env.OPS_KIMAI_MAP_EXTRA || path.join(process.env.OPS_SYNC_DATA || path.join(__dirname, "data"), "kimai-map-extra.json");
  if (fs.existsSync(extraPath)) {
    try {
      const extra = JSON.parse(fs.readFileSync(extraPath, "utf8"));
      base.customers = { ...(base.customers ?? {}), ...(extra.customers ?? {}) };
      if (extra.projectOverrides) base.projectOverrides = { ...(base.projectOverrides ?? {}), ...extra.projectOverrides };
    } catch {
      /* ignore corrupt extra map */
    }
  }
  return base;
}

export function saveKimaiMapExtra(patch) {
  const extraPath = process.env.OPS_KIMAI_MAP_EXTRA || path.join(process.env.OPS_SYNC_DATA || path.join(__dirname, "data"), "kimai-map-extra.json");
  const current = fs.existsSync(extraPath) ? JSON.parse(fs.readFileSync(extraPath, "utf8")) : { customers: {}, projectOverrides: {} };
  if (patch.customers) {
    current.customers = current.customers || {};
    for (const [name, aliases] of Object.entries(patch.customers)) {
      const prev = current.customers[name] ?? [];
      current.customers[name] = [...new Set([...prev, ...aliases])];
    }
  }
  if (patch.projectOverrides) current.projectOverrides = { ...(current.projectOverrides ?? {}), ...patch.projectOverrides };
  fs.mkdirSync(path.dirname(extraPath), { recursive: true });
  fs.writeFileSync(extraPath, JSON.stringify(current, null, 2));
  return current;
}

export function invalidateCatalog() {
  catalogCache = { at: 0, value: null };
}

async function kimaiFetch(pathname, init = {}) {
  const res = await fetch(`${kimaiBase()}${pathname}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${process.env.KIMAI_API_TOKEN}`,
      Accept: "application/json",
      "Content-Type": "application/json",
      ...(init.headers ?? {}),
    },
  });
  const text = await res.text();
  let data;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = text;
  }
  if (!res.ok) throw new Error(`Kimai ${pathname}: ${res.status} ${typeof data === "string" ? data : data?.message ?? ""}`);
  return data;
}

// ---- catalog (customers / projects / activities) with a short cache ----
let catalogCache = { at: 0, value: null };

export async function loadCatalog(force = false) {
  if (!isKimaiConfigured()) return { customers: [], projects: [], activities: [] };
  if (!force && catalogCache.value && Date.now() - catalogCache.at < 10 * 60 * 1000) return catalogCache.value;
  const [customers, projects, activities] = await Promise.all([
    kimaiFetch("/customers?visible=1&size=200"),
    kimaiFetch("/projects?visible=1&size=200"),
    kimaiFetch("/activities?visible=1&size=200"),
  ]);
  const value = {
    customers: Array.isArray(customers) ? customers : [],
    projects: Array.isArray(projects) ? projects : [],
    activities: Array.isArray(activities) ? activities : [],
  };
  catalogCache = { at: Date.now(), value };
  return value;
}

function escapeRe(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/** Build a matcher from the catalog + kimai-map.json */
export function buildMatcher(catalog, map = loadKimaiMap()) {
  const customersById = new Map(catalog.customers.map((c) => [c.id, c]));
  const projectsByCustomer = new Map();
  for (const p of catalog.projects) {
    const list = projectsByCustomer.get(p.customer) ?? [];
    list.push(p);
    projectsByCustomer.set(p.customer, list);
  }

  // rules: [{ re, customerId }]
  const rules = [];
  for (const c of catalog.customers) {
    const aliases = new Set([c.name.toLowerCase(), ...(map.customers?.[c.name] ?? []).map((a) => a.toLowerCase())]);
    for (const a of aliases) {
      if (a.length < 3) continue;
      rules.push({ re: new RegExp(`\\b${escapeRe(a)}\\b`, "i"), customerId: c.id, weight: a.length });
    }
    // Project prefixes: "HPE - General Work" → HPE (case-sensitive whole word)
    for (const p of projectsByCustomer.get(c.id) ?? []) {
      const m = /^([A-Za-z]{2,10})\s*-\s*/.exec(p.name);
      if (m && m[1].length >= 2 && m[1] !== "Z") {
        rules.push({ re: new RegExp(`\\b${escapeRe(m[1])}\\b`), customerId: c.id, weight: m[1].length + 0.5 });
      }
    }
  }
  rules.sort((a, b) => b.weight - a.weight);

  const ignore = (map.ignoreTitles ?? []).map((s) => new RegExp(s, "i"));
  const preferContains = (map.preferProjectContaining ?? "General Work").toLowerCase();

  function pickProject(customer) {
    const override = map.projectOverrides?.[customer.name];
    const list = projectsByCustomer.get(customer.id) ?? [];
    if (override) {
      const hit = catalog.projects.find((p) => p.name === override);
      if (hit) return hit;
    }
    return list.find((p) => p.name.toLowerCase().includes(preferContains)) ?? list[0] ?? null;
  }

  function pickActivity(project) {
    const forProject = catalog.activities.filter((a) => a.project === project?.id);
    const globals = catalog.activities.filter((a) => a.project == null);
    const want = (map.defaultActivity ?? "General Work").toLowerCase();
    return (
      forProject.find((a) => a.name.toLowerCase() === want) ??
      globals.find((a) => a.name.toLowerCase() === want) ??
      forProject[0] ??
      globals[0] ??
      null
    );
  }

  const defaultProject = catalog.projects.find((p) => p.name === map.defaultProject) ?? null;
  const lifeAreas = new Set(map.lifeAreas ?? ["cloudigan"]);

  return {
    lifeAreas,
    isIgnored(title) {
      return ignore.some((re) => re.test(title ?? ""));
    },
    isWorkArea(lifeArea) {
      return lifeAreas.has(lifeArea);
    },
    /** Returns { customer, project, activity, matched } or null if not a work event */
    suggest(event) {
      const title = event.title ?? "";
      const inArea = lifeAreas.has(event.lifeArea);
      let customer = null;
      for (const r of rules) {
        if (r.re.test(title)) {
          customer = customersById.get(r.customerId) ?? null;
          break;
        }
      }
      if (!inArea && !(customer && map.alsoMatchOtherAreas)) return null;
      if (this.isIgnored(title)) return null;

      // Customer matched but has no Kimai project yet → log against the default project, keep the customer name
      const matched = Boolean(customer);
      let project = customer ? pickProject(customer) : null;
      const noProject = Boolean(customer && !project);
      if (!project) project = defaultProject;
      if (!project) return null;
      if (!customer) customer = customersById.get(project.customer) ?? null;
      const activity = pickActivity(project);
      return {
        matched,
        noProject,
        customerId: customer?.id ?? null,
        customer: customer?.name ?? null,
        projectId: project.id,
        project: project.name,
        activityId: activity?.id ?? null,
        activity: activity?.name ?? null,
      };
    },
  };
}

export async function getCustomer(id) {
  return kimaiFetch(`/customers/${id}`);
}

export async function createCustomer({ name, comment = "", timeBudgetHours = 0, email = "", company = "" }) {
  const created = await kimaiFetch("/customers", {
    method: "POST",
    body: JSON.stringify({
      name,
      comment: comment || null,
      visible: true,
      billable: true,
      country: "US",
      currency: "USD",
      timezone: TZ,
      company: company || null,
      email: email || null,
      timeBudget: Math.round(Number(timeBudgetHours || 0) * 3600),
    }),
  });
  invalidateCatalog();
  return created;
}

export async function patchCustomer(id, fields) {
  const body = { ...fields };
  if (fields.timeBudgetHours != null) {
    body.timeBudget = Math.round(Number(fields.timeBudgetHours) * 3600);
    delete body.timeBudgetHours;
  }
  const updated = await kimaiFetch(`/customers/${id}`, { method: "PATCH", body: JSON.stringify(body) });
  invalidateCatalog();
  return updated;
}

export async function createProject({ name, customerId, comment = "", timeBudgetHours = 0 }) {
  const created = await kimaiFetch("/projects", {
    method: "POST",
    body: JSON.stringify({
      name,
      customer: customerId,
      comment: comment || null,
      visible: true,
      billable: true,
      globalActivities: true,
      timeBudget: Math.round(Number(timeBudgetHours || 0) * 3600),
    }),
  });
  invalidateCatalog();
  return created;
}

export async function fetchTimesheetsForCustomer(customerId) {
  if (!isKimaiConfigured()) return [];
  const params = new URLSearchParams({
    customer: String(customerId),
    begin: "2020-01-01T00:00:00",
    size: "500",
    order: "ASC",
    orderBy: "begin",
  });
  const rows = await kimaiFetch(`/timesheets?${params}`);
  return (Array.isArray(rows) ? rows : []).map((t) => ({
    id: t.id,
    begin: fromKimaiIso(t.begin),
    end: t.end ? fromKimaiIso(t.end) : null,
    durationMinutes: t.end ? Math.round((t.duration ?? 0) / 60) : Math.round((Date.now() - new Date(fromKimaiIso(t.begin)).getTime()) / 60000),
    projectId: typeof t.project === "object" ? t.project?.id : t.project,
    billable: t.billable !== false,
    description: t.description ?? "",
  }));
}

const INTERNAL_CUSTOMERS = new Set(["cloudigan internal", "personal"]);

/**
 * Hours purchased vs used for every visible Kimai customer.
 * timeBudget lives on the customer (seconds). budgetType === "month" counts only this month.
 */
export async function analyzeQuotas() {
  if (!isKimaiConfigured()) return { configured: false, customers: [] };
  const catalog = await loadCatalog();
  const warnPct = Number(process.env.OPS_QUOTA_WARN_PCT || 80);
  const criticalPct = Number(process.env.OPS_QUOTA_CRITICAL_PCT || 95);
  const monthStart = todayLocal().slice(0, 7) + "-01";
  const rows = [];

  for (const c of catalog.customers) {
    if (INTERNAL_CUSTOMERS.has(c.name.toLowerCase())) continue;
    let detail;
    try {
      detail = await getCustomer(c.id);
    } catch (err) {
      if (String(err.message).includes("404")) {
        invalidateCatalog();
        continue;
      }
      throw err;
    }
    const budgetSeconds = Number(detail.timeBudget || 0);
    const monthly = String(detail.budgetType || "").toLowerCase() === "month";
    const sheets = await fetchTimesheetsForCustomer(c.id);
    const counted = sheets.filter((t) => t.billable && (!monthly || (t.begin && t.begin.slice(0, 10) >= monthStart)));
    const usedMinutes = counted.reduce((s, t) => s + (t.durationMinutes || 0), 0);
    const purchasedMinutes = Math.round(budgetSeconds / 60);
    const remainingMinutes = purchasedMinutes > 0 ? purchasedMinutes - usedMinutes : null;
    const usedPct = purchasedMinutes > 0 ? Math.round((usedMinutes / purchasedMinutes) * 100) : null;
    let level = "none";
    if (purchasedMinutes > 0) {
      if (usedPct >= 100 || remainingMinutes <= 0) level = "over";
      else if (usedPct >= criticalPct || remainingMinutes <= 60) level = "critical";
      else if (usedPct >= warnPct) level = "warn";
      else level = "ok";
    }
    const projects = catalog.projects.filter((p) => p.customer === c.id).map((p) => ({ id: p.id, name: p.name }));
    rows.push({
      id: c.id,
      name: c.name,
      monthly,
      purchasedMinutes,
      usedMinutes,
      remainingMinutes,
      usedPct,
      level,
      purchased: purchasedMinutes ? fmtHours(purchasedMinutes) : "no quota",
      used: fmtHours(usedMinutes),
      remaining: remainingMinutes == null ? "—" : remainingMinutes < 0 ? `over ${fmtHours(-remainingMinutes)}` : fmtHours(remainingMinutes),
      projects,
      kimaiUrl: `${kimaiWebBase()}/en/admin/customer/${c.id}/details`,
    });
  }

  const rank = { over: 0, critical: 1, warn: 2, ok: 3, none: 4 };
  rows.sort((a, b) => (rank[a.level] ?? 9) - (rank[b.level] ?? 9) || a.name.localeCompare(b.name));
  return {
    configured: true,
    warnPct,
    criticalPct,
    customers: rows,
    alerts: rows.filter((r) => r.level === "warn" || r.level === "critical" || r.level === "over"),
    kimaiUrl: kimaiWebBase(),
  };
}

// ---- timesheets ----

export async function fetchTimesheets(dayFrom, dayTo = dayFrom) {
  if (!isKimaiConfigured()) return [];
  // No `user` param: Kimai defaults to the token owner (user=self returns 400 on 2.x)
  const params = new URLSearchParams({
    begin: `${dayFrom}T00:00:00`,
    end: `${dayTo}T23:59:59`,
    size: "500",
    order: "ASC",
    orderBy: "begin",
  });
  const rows = await kimaiFetch(`/timesheets?${params}`);
  return (Array.isArray(rows) ? rows : []).map((t) => ({
    id: t.id,
    begin: fromKimaiIso(t.begin),
    end: t.end ? fromKimaiIso(t.end) : null,
    durationMinutes: t.end ? Math.round((t.duration ?? 0) / 60) : Math.round((Date.now() - new Date(fromKimaiIso(t.begin)).getTime()) / 60000),
    projectId: typeof t.project === "object" ? t.project?.id : t.project,
    activityId: typeof t.activity === "object" ? t.activity?.id : t.activity,
    description: t.description ?? "",
    running: !t.end,
  }));
}

export async function fetchActiveTimesheet() {
  if (!isKimaiConfigured()) return null;
  const rows = await kimaiFetch("/timesheets/active");
  const t = Array.isArray(rows) ? rows[0] : rows?.id ? rows : null;
  if (!t) return null;
  const projectId = typeof t.project === "object" ? t.project?.id : t.project;
  const activityId = typeof t.activity === "object" ? t.activity?.id : t.activity;
  let project = typeof t.project === "object" ? t.project?.name : null;
  let customer = typeof t.project === "object" ? t.project?.customer?.name : null;
  let activity = typeof t.activity === "object" ? t.activity?.name : null;
  if (!project || !activity) {
    try {
      const cat = await loadCatalog();
      const p = cat.projects.find((x) => x.id === projectId);
      project = project ?? p?.name ?? null;
      customer = customer ?? (p ? cat.customers.find((c) => c.id === p.customer)?.name ?? null : null);
      activity = activity ?? cat.activities.find((a) => a.id === activityId)?.name ?? null;
    } catch {
      /* names are cosmetic */
    }
  }
  const begin = fromKimaiIso(t.begin);
  return {
    id: t.id,
    begin,
    elapsedMinutes: begin ? Math.round((Date.now() - new Date(begin).getTime()) / 60000) : null,
    projectId,
    project,
    customer,
    activityId,
    activity,
    description: t.description ?? "",
  };
}

/** Deep link that prefills Kimai's "create timesheet" form */
export function kimaiCreateLink({ start, end, projectId, activityId, description }) {
  const q = new URLSearchParams();
  if (start) q.set("begin", toKimaiLocal(start));
  if (end) q.set("end", toKimaiLocal(end));
  if (projectId) q.set("project", String(projectId));
  if (activityId) q.set("activity", String(activityId));
  if (description) q.set("description", description.slice(0, 200));
  return `${kimaiWebBase()}/en/timesheet/create?${q}`;
}

// ---- gap analysis ----

function overlapMinutes(aStart, aEnd, bStart, bEnd) {
  const s = Math.max(new Date(aStart).getTime(), new Date(bStart).getTime());
  const e = Math.min(new Date(aEnd).getTime(), new Date(bEnd).getTime());
  return Math.max(0, Math.round((e - s) / 60000));
}

/** Union coverage of [start,end) by intervals, in minutes */
function coveredMinutes(start, end, intervals) {
  const s0 = new Date(start).getTime();
  const e0 = new Date(end).getTime();
  const clipped = intervals
    .map((i) => [Math.max(s0, new Date(i.begin).getTime()), Math.min(e0, new Date(i.end ?? new Date().toISOString()).getTime())])
    .filter(([a, b]) => b > a)
    .sort((a, b) => a[0] - b[0]);
  let total = 0;
  let cur = null;
  for (const [a, b] of clipped) {
    if (!cur) cur = [a, b];
    else if (a <= cur[1]) cur[1] = Math.max(cur[1], b);
    else {
      total += cur[1] - cur[0];
      cur = [a, b];
    }
  }
  if (cur) total += cur[1] - cur[0];
  return Math.round(total / 60000);
}

/**
 * Compare calendar work blocks for `day` against Kimai entries.
 * events = deduped events from calendar.json
 */
export async function analyzeDay(day, events, opts = {}) {
  const map = loadKimaiMap();
  const catalog = await loadCatalog();
  const matcher = buildMatcher(catalog, map);
  const threshold = Number(opts.thresholdMinutes ?? process.env.OPS_TIMELOG_THRESHOLD_MIN ?? map.gapThresholdMinutes ?? 30);
  const projectsById = new Map(catalog.projects.map((p) => [p.id, p]));
  const customersById = new Map(catalog.customers.map((c) => [c.id, c]));
  const activitiesById = new Map(catalog.activities.map((a) => [a.id, a]));

  const nowIso = new Date().toISOString();
  const blocks = [];
  for (const e of events) {
    if (e.allDay) continue;
    if (localDay(e.start) !== day) continue;
    const durationMin = Math.round((new Date(e.end) - new Date(e.start)) / 60000);
    if (durationMin <= 0 || durationMin >= 12 * 60) continue;
    const suggestion = matcher.suggest(e);
    if (!suggestion) continue;
    blocks.push({ ...e, minutes: durationMin, kimai: suggestion });
  }
  blocks.sort((a, b) => a.start.localeCompare(b.start));

  const entries = isKimaiConfigured() ? await fetchTimesheets(day) : [];
  const logged = entries.map((t) => {
    const p = projectsById.get(t.projectId);
    return {
      ...t,
      project: p?.name ?? null,
      customer: p ? customersById.get(p.customer)?.name ?? null : null,
      activity: activitiesById.get(t.activityId)?.name ?? null,
    };
  });

  const gaps = [];
  const analyzedBlocks = blocks.map((b) => {
    const covered = coveredMinutes(b.start, b.end, entries);
    const gap = Math.max(0, b.minutes - covered);
    const ended = b.end <= nowIso;
    const row = {
      uid: b.uid,
      title: b.title,
      start: b.start,
      end: b.end,
      minutes: b.minutes,
      coveredMinutes: covered,
      gapMinutes: gap,
      ended,
      lifeArea: b.lifeArea,
      calendar: b.calendar ?? b.source,
      link: b.link ?? null,
      kimai: b.kimai,
      logLink: kimaiCreateLink({
        start: b.start,
        end: b.end,
        projectId: b.kimai.projectId,
        activityId: b.kimai.activityId,
        description: b.title,
      }),
    };
    // Only flag gaps for blocks that have already ended (or are past when opts.includeFuture)
    if (gap >= threshold && (ended || opts.includeFuture)) gaps.push(row);
    return row;
  });

  const scheduledMinutes = analyzedBlocks.reduce((s, b) => s + b.minutes, 0);
  const loggedMinutes = logged.reduce((s, t) => s + (t.durationMinutes ?? 0), 0);
  const gapMinutes = gaps.reduce((s, g) => s + g.gapMinutes, 0);

  const byCustomer = {};
  for (const t of logged) {
    const k = t.customer ?? "Unassigned";
    byCustomer[k] = (byCustomer[k] ?? 0) + (t.durationMinutes ?? 0);
  }

  return {
    date: day,
    timeZone: TZ,
    kimaiConfigured: isKimaiConfigured(),
    thresholdMinutes: threshold,
    blocks: analyzedBlocks,
    logged,
    gaps,
    totals: {
      scheduledMinutes,
      loggedMinutes,
      gapMinutes,
      scheduled: fmtHours(scheduledMinutes),
      logged: fmtHours(loggedMinutes),
      gap: fmtHours(gapMinutes),
      byCustomer,
    },
    kimaiUrl: kimaiWebBase(),
  };
}

/** Minutes logged Monday→day (inclusive) */
export async function weekLoggedMinutes(day) {
  if (!isKimaiConfigured()) return 0;
  const start = weekStart(day);
  const entries = await fetchTimesheets(start, day);
  return entries.reduce((s, t) => s + (t.durationMinutes ?? 0), 0);
}

/** Enrich events in place with a `kimai` suggestion for one-click timers */
export async function enrichEventsWithKimai(events) {
  if (!isKimaiConfigured()) return events;
  try {
    const catalog = await loadCatalog();
    const matcher = buildMatcher(catalog);
    for (const e of events) {
      if (e.allDay) continue;
      const s = matcher.suggest(e);
      if (s) e.kimai = s;
    }
  } catch (err) {
    console.warn("kimai enrich skipped:", err.message);
  }
  return events;
}

export { addDays };
