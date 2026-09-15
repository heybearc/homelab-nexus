// Compose the morning briefing (structured + text). n8n only schedules and pushes to ntfy.
import { listOpenTasks, isVikunjaConfigured } from "./vikunja.js";
import { analyzeDay, weekLoggedMinutes, isKimaiConfigured, analyzeQuotas } from "./kimai.js";
import { upcomingBills } from "./bills.js";
import { summarizeBriefing, isLlmConfigured, llmProvider } from "./llm.js";
import { TZ, todayLocal, addDays, fmtTime, fmtHours, fmtDate, localDay } from "./tz.js";

function greeting(now = new Date()) {
  const h = Number(now.toLocaleTimeString("en-US", { timeZone: TZ, hour: "numeric", hour12: false }).split(":")[0]);
  if (h < 12) return "Good morning";
  if (h < 17) return "Good afternoon";
  return "Good evening";
}

function plural(n, word) {
  return `${n} ${word}${n === 1 ? "" : "s"}`;
}

/**
 * @param calendar  parsed calendar.json
 * @param opts      { conflicts: "high"|"all", llm: boolean, test: boolean }
 */
export async function buildBriefing(calendar, opts = {}) {
  const today = calendar.today?.date ?? todayLocal();
  const yesterday = addDays(today, -1);
  const mode = (opts.conflicts || process.env.OPS_BRIEFING_CONFLICTS || "high").toLowerCase();
  const high = calendar.today?.conflictsHigh ?? (calendar.today?.conflicts ?? []).filter((c) => c.severity === "high");
  const low = calendar.today?.conflictsLow ?? (calendar.today?.conflicts ?? []).filter((c) => c.severity !== "high");
  const conflicts = mode === "all" ? [...high, ...low] : high;
  const minorConflicts = mode === "all" ? 0 : low.length;
  const events = calendar.today?.events ?? [];
  const allDay = calendar.today?.allDay ?? [];
  const opsHubUrl = process.env.OPS_HUB_URL || "https://ops.cloudigan.net";

  // ---- tasks ----
  let tasks = { configured: isVikunjaConfigured(), open: 0, dueToday: [], overdue: [], error: null };
  if (tasks.configured) {
    try {
      const open = await listOpenTasks();
      const dueToday = open.filter((t) => t.due_date && !t.due_date.startsWith("0001") && localDay(t.due_date) === today);
      const overdue = open.filter((t) => t.due_date && !t.due_date.startsWith("0001") && localDay(t.due_date) < today);
      tasks = {
        configured: true,
        open: open.length,
        dueToday: dueToday.map((t) => ({ id: t.id, title: t.title, priority: t.priority })),
        overdue: overdue.map((t) => ({ id: t.id, title: t.title, due: localDay(t.due_date) })),
        error: null,
      };
    } catch (err) {
      tasks.error = err.message;
    }
  }

  // ---- time (Kimai) ----
  let time = { configured: isKimaiConfigured(), yesterday: null, weekMinutes: 0, error: null };
  if (time.configured) {
    try {
      const y = await analyzeDay(yesterday, calendar.events ?? [], { includeFuture: true });
      const week = await weekLoggedMinutes(yesterday);
      time = {
        configured: true,
        yesterday: {
          date: yesterday,
          scheduledMinutes: y.totals.scheduledMinutes,
          loggedMinutes: y.totals.loggedMinutes,
          gapMinutes: y.totals.gapMinutes,
          byCustomer: y.totals.byCustomer,
          gaps: y.gaps.map((g) => ({ title: g.title, minutes: g.gapMinutes, customer: g.kimai.customer, logLink: g.logLink })),
        },
        weekMinutes: week,
        error: null,
      };
    } catch (err) {
      time.error = err.message;
    }
  }

  // ---- hours quotas ----
  let quotas = { alerts: [], error: null };
  if (time.configured) {
    try {
      const q = await analyzeQuotas();
      quotas = { alerts: q.alerts ?? [], error: null };
    } catch (err) {
      quotas = { alerts: [], error: err.message };
    }
  }

  // ---- bills ----
  const bills = upcomingBills(7);

  // ---- today's client blocks (for the LLM + a planning line) ----
  const clientBlocks = events.filter((e) => e.kimai).map((e) => ({ title: e.title, start: e.start, customer: e.kimai.customer }));

  const structured = {
    date: today,
    dateLabel: fmtDate(today, { weekday: "long", month: "long", day: "numeric" }),
    timeZone: TZ,
    events: events.map((e) => ({ title: e.title, start: e.start, end: e.end, lifeArea: e.lifeArea, calendar: e.calendar ?? e.source, conflicted: Boolean(e.conflicted), customer: e.kimai?.customer ?? null })),
    allDay: allDay.map((e) => ({ title: e.title, lifeArea: e.lifeArea })),
    conflicts: conflicts.map((c) => ({ a: c.a, b: c.b, at: c.at, overlapMinutes: c.overlapMinutes, lifeAreas: c.lifeAreas })),
    minorConflicts,
    tasks,
    time,
    quotas,
    bills,
    clientBlocks,
  };

  // ---- text ----
  const lines = [];
  lines.push(`${greeting()} Cory — ${fmtDate(today, { weekday: "long", month: "short", day: "numeric" })}${opts.test ? " (test)" : ""}`);

  let headline = null;
  if (opts.llm !== false && isLlmConfigured()) {
    try {
      headline = await summarizeBriefing(structured);
      if (headline?.text) lines.push("", headline.text);
    } catch (err) {
      console.warn("LLM summary skipped:", err.message);
      structured.llmError = err.message;
    }
  }

  // Tasks
  if (tasks.configured && !tasks.error) {
    lines.push("", `📋 ${plural(tasks.open, "open task")} · ${tasks.dueToday.length} due today${tasks.overdue.length ? ` · ${tasks.overdue.length} overdue` : ""}`);
    for (const t of tasks.dueToday.slice(0, 6)) lines.push(`• ${t.title}`);
    if (tasks.overdue.length) {
      for (const t of tasks.overdue.slice(0, 3)) lines.push(`• ⏰ ${t.title} (was ${fmtDate(t.due, { month: "short", day: "numeric" })})`);
      if (tasks.overdue.length > 3) lines.push(`… +${tasks.overdue.length - 3} overdue`);
    }
  } else if (tasks.error) {
    lines.push("", `📋 Tasks unavailable (${tasks.error.slice(0, 60)})`);
  }

  // Bills
  if (bills.length) {
    lines.push("", `💳 Bills this week: ${bills.map((b) => `${b.name} ${fmtDate(b.due, { month: "short", day: "numeric" })}${b.autopay ? " (auto)" : ""}`).join(" · ")}`);
  }

  // All day
  if (allDay.length) {
    lines.push("", `📌 All day: ${allDay.slice(0, 4).map((e) => e.title.trim()).join(" · ")}${allDay.length > 4 ? ` (+${allDay.length - 4})` : ""}`);
  }

  // Timed events
  lines.push("", `📅 ${plural(events.length, "timed event")} today`);
  for (const e of events.slice(0, 10)) {
    lines.push(`• ${fmtTime(e.start)} [${e.lifeArea}] ${e.title.trim()}${e.conflicted ? " ⚠" : ""}`);
  }
  if (events.length > 10) lines.push(`… +${events.length - 10} more`);

  // Conflicts
  if (conflicts.length) {
    lines.push("", `⚠️ ${plural(conflicts.length, "cross-calendar conflict")}`);
    for (const c of conflicts.slice(0, 5)) {
      const areas = (c.lifeAreas || []).join("/");
      lines.push(`• ${fmtTime(c.at)} ${c.a} ↔ ${c.b}${areas ? ` (${areas})` : ""}`);
    }
    if (minorConflicts) lines.push(`(+${plural(minorConflicts, "same-calendar overlap")} — see Ops Hub)`);
    lines.push(`Resolve: ${opsHubUrl}`);
  } else if (minorConflicts) {
    lines.push("", `✅ No cross-calendar conflicts (${plural(minorConflicts, "same-calendar overlap")} — not urgent)`);
  } else {
    lines.push("", "✅ No conflicts today");
  }

  // Time
  if (time.configured && !time.error && time.yesterday) {
    const y = time.yesterday;
    lines.push("");
    if (y.scheduledMinutes || y.loggedMinutes) {
      let l = `⏱ Yesterday: ${fmtHours(y.loggedMinutes)} logged / ${fmtHours(y.scheduledMinutes)} scheduled`;
      if (y.gapMinutes) l += ` — ${fmtHours(y.gapMinutes)} unlogged (${y.gaps.slice(0, 3).map((g) => g.customer ?? g.title).join(", ")})`;
      lines.push(l);
    }
    lines.push(`⏱ Week so far: ${fmtHours(time.weekMinutes)} logged${clientBlocks.length ? ` · ${plural(clientBlocks.length, "client block")} today` : ""}`);
  } else if (time.error) {
    lines.push("", `⏱ Kimai unavailable (${time.error.slice(0, 60)})`);
  }

  if (quotas.alerts.length) {
    lines.push("", `⏳ Hours: ${quotas.alerts.map((c) => `${c.name} ${c.used}/${c.purchased} (${c.remaining})`).join(" · ")}`);
  }

  lines.push("", "— Ops Hub daily briefing");

  const hasUrgent = conflicts.length > 0 || (time.yesterday?.gapMinutes ?? 0) >= 60 || tasks.overdue.length > 0 || quotas.alerts.some((c) => c.level === "over" || c.level === "critical");
  return {
    title: "Cory's Daily Briefing",
    topic: process.env.NTFY_TOPIC || "cory-daily-briefing",
    priority: hasUrgent ? "5" : "4",
    click: opsHubUrl,
    message: lines.join("\n").replace(/\n{3,}/g, "\n\n"),
    llm: headline ? { provider: headline.provider, model: headline.model } : { provider: llmProvider(), used: false },
    structured,
  };
}
