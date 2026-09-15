#!/usr/bin/env node
import http from "http";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const envPath = path.join(__dirname, ".env");
if (fs.existsSync(envPath)) {
  for (const line of fs.readFileSync(envPath, "utf8").split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eq = trimmed.indexOf("=");
    if (eq === -1) continue;
    const key = trimmed.slice(0, eq).trim();
    let val = trimmed.slice(eq + 1).trim();
    if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
      val = val.slice(1, -1);
    }
    if (!process.env[key]) process.env[key] = val;
  }
}

// Import after .env is loaded so modules can read config at call time
const { runSync } = await import("./sync.js");
const { buildBriefing } = await import("./briefing.js");
const { analyzeDay, fetchActiveTimesheet, isKimaiConfigured, loadCatalog, analyzeQuotas } = await import("./kimai.js");
const { onboardClient, loadTemplate, suggestPrefix } = await import("./onboard.js");
const { processQuotaAlerts } = await import("./quotas.js");
const { healAlerts, fetchFiringAlerts } = await import("./alerts.js");
const { processTimelog } = await import("./timelog.js");
const { generateBillTasks, upcomingBills, loadBills } = await import("./bills.js");
const { isLlmConfigured, llmProvider } = await import("./llm.js");
const { isVikunjaConfigured } = await import("./vikunja.js");
const { resolveDay } = await import("./tz.js");

const PORT = Number(process.env.OPS_SYNC_PORT ?? 3002);
const DATA_DIR = process.env.OPS_SYNC_DATA ?? path.join(__dirname, "data");
const SYNC_INTERVAL_MS = Number(process.env.OPS_SYNC_INTERVAL_MS ?? 15 * 60 * 1000);

function readJson() {
  const p = path.join(DATA_DIR, "calendar.json");
  if (!fs.existsSync(p)) return { events: [], conflicts: [], syncedAt: null };
  return JSON.parse(fs.readFileSync(p, "utf8"));
}

function json(res, status, body) {
  res.writeHead(status, { "Content-Type": "application/json" });
  res.end(JSON.stringify(body));
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let body = "";
    req.on("data", (c) => (body += c));
    req.on("end", () => {
      try {
        resolve(body ? JSON.parse(body) : {});
      } catch (err) {
        reject(err);
      }
    });
    req.on("error", reject);
  });
}

const routes = [];
function route(method, pathname, handler) {
  routes.push({ method, pathname, handler });
}

route("GET", "/health", async () => ({
  ok: true,
  kimai: isKimaiConfigured(),
  vikunja: isVikunjaConfigured(),
  llm: isLlmConfigured() ? llmProvider() : null,
}));

route("GET", "/calendar", async () => readJson());

route("GET", "/briefing", async (url) => {
  const data = readJson();
  const today = data.today ?? { date: null, events: [], allDay: [], conflicts: [] };
  const mode = (url.searchParams.get("conflicts") || process.env.OPS_BRIEFING_CONFLICTS || "high").toLowerCase();
  const high = today.conflictsHigh ?? (today.conflicts ?? []).filter((c) => c.severity === "high");
  const low = today.conflictsLow ?? (today.conflicts ?? []).filter((c) => c.severity !== "high");
  return {
    syncedAt: data.syncedAt,
    date: today.date,
    timeZone: data.timeZone || "America/New_York",
    events: today.events ?? [],
    allDay: today.allDay ?? [],
    conflicts: mode === "all" ? [...high, ...low] : high,
    minorConflicts: mode === "all" ? 0 : low.length,
    stats: data.stats,
    opsHubUrl: process.env.OPS_HUB_URL || "https://ops.cloudigan.net",
  };
});

// Full composed briefing: { title, topic, priority, click, message, llm, structured }
route("GET", "/briefing/text", async (url) => {
  const data = readJson();
  return buildBriefing(data, {
    conflicts: url.searchParams.get("conflicts") || undefined,
    llm: url.searchParams.get("llm") !== "0",
    test: url.searchParams.get("test") === "1",
  });
});

// Calendar blocks vs Kimai entries for a day (today|yesterday|YYYY-MM-DD)
route("GET", "/timelog", async (url) => {
  const day = resolveDay(url.searchParams.get("date"));
  const data = readJson();
  return analyzeDay(day, data.events ?? [], { includeFuture: url.searchParams.get("includeFuture") === "1" });
});

// Analyze + create Vikunja tasks for gaps (idempotent) + nudge text. Body/query: date
route("POST", "/timelog/tasks", async (url, body) => {
  const day = resolveDay(body.date || url.searchParams.get("date"));
  const data = readJson();
  return processTimelog(day, data.events ?? [], DATA_DIR, {
    createTasks: body.createTasks !== false,
    includeFuture: Boolean(body.includeFuture),
  });
});

route("GET", "/timelog/active", async () => ({ running: await fetchActiveTimesheet() }));
route("GET", "/timelog/catalog", async () => loadCatalog(true));

route("GET", "/bills", async (url) => ({
  config: loadBills(),
  upcoming: upcomingBills(Number(url.searchParams.get("days") || 14)),
}));
route("GET", "/alerts", async () => healAlerts({ dryRun: true }));
route("POST", "/alerts/heal", async (url, body) => healAlerts({ dryRun: Boolean(body.dryRun) }));
route("GET", "/alerts/firing", async () => ({ firing: await fetchFiringAlerts() }));

route("GET", "/quotas", async () => analyzeQuotas());
route("POST", "/quotas/alerts", async (url, body) => processQuotaAlerts(DATA_DIR, body));

route("GET", "/clients/template", async () => ({
  ...loadTemplate(),
  customers: (await loadCatalog()).customers.map((c) => ({ id: c.id, name: c.name })),
  projects: (await loadCatalog()).projects.map((p) => ({ id: p.id, name: p.name, customer: p.customer })),
}));
route("POST", "/clients/onboard", async (url, body) => onboardClient(body));
route("GET", "/clients/prefix", async (url) => ({
  name: url.searchParams.get("name") || "",
  prefix: suggestPrefix(url.searchParams.get("name") || ""),
}));

route("POST", "/bills/generate", async (url, body) => {
  const months = body.months || (url.searchParams.get("month") ? [url.searchParams.get("month")] : undefined);
  return generateBillTasks(DATA_DIR, months);
});

route("GET", "/merged.ics", async (url, body, req, res) => {
  const p = path.join(DATA_DIR, "merged.ics");
  if (!fs.existsSync(p)) {
    res.writeHead(404);
    res.end("Not synced yet");
    return undefined;
  }
  res.writeHead(200, { "Content-Type": "text/calendar; charset=utf-8" });
  res.end(fs.readFileSync(p));
  return undefined;
});

route("POST", "/sync", async () => ({ ok: true, ...(await runSync()) }));

route("POST", "/conflicts/dismiss", async (url, body, req, res) => {
  const id = body.id;
  if (!id) {
    json(res, 400, { error: "id required" });
    return undefined;
  }
  const days = Number(body.days ?? 7);
  const p = path.join(DATA_DIR, "dismissed-conflicts.json");
  const store = fs.existsSync(p) ? JSON.parse(fs.readFileSync(p, "utf8")) : { ids: {} };
  store.ids = store.ids || {};
  const until = new Date(Date.now() + days * 86400000).toISOString();
  store.ids[id] = until;
  fs.writeFileSync(p, JSON.stringify(store, null, 2));
  return { ok: true, id, until };
});

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url || "/", `http://${req.headers.host || "localhost"}`);
  const match = routes.find((r) => r.pathname === url.pathname && r.method === req.method);
  if (!match) {
    res.writeHead(404);
    res.end("Not found");
    return;
  }
  try {
    const body = req.method === "POST" ? await readBody(req) : {};
    const result = await match.handler(url, body, req, res);
    if (result !== undefined && !res.headersSent) json(res, 200, result);
  } catch (err) {
    console.error(`${req.method} ${url.pathname}:`, err);
    if (!res.headersSent) json(res, 500, { ok: false, error: String(err.message ?? err) });
  }
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(`ops-sync listening on :${PORT} · kimai=${isKimaiConfigured()} vikunja=${isVikunjaConfigured()} llm=${llmProvider() ?? "off"}`);
  runSync().catch(console.error);
  setInterval(() => runSync().catch(console.error), SYNC_INTERVAL_MS);
});
