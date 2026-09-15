// Turn Kimai gaps into Vikunja tasks (idempotent per event+day) and build an evening nudge.
import fs from "fs";
import path from "path";
import { analyzeDay } from "./kimai.js";
import { createTask, isVikunjaConfigured, taskUrl } from "./vikunja.js";
import { addDays, fmtTime, fmtHours, fmtDate, localToUtc } from "./tz.js";

function storePath(dataDir) {
  return path.join(dataDir, "timelog-tasks.json");
}

function loadStore(dataDir) {
  const p = storePath(dataDir);
  if (!fs.existsSync(p)) return { created: {} };
  try {
    return JSON.parse(fs.readFileSync(p, "utf8"));
  } catch {
    return { created: {} };
  }
}

function saveStore(dataDir, store) {
  // prune entries older than 60 days
  const cutoff = addDays(new Date().toISOString().slice(0, 10), -60);
  for (const k of Object.keys(store.created)) {
    if (k.slice(0, 10) < cutoff) delete store.created[k];
  }
  fs.mkdirSync(dataDir, { recursive: true });
  fs.writeFileSync(storePath(dataDir), JSON.stringify(store, null, 2));
}

function esc(s) {
  return String(s ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

/**
 * Analyze `day`, create one Vikunja task per unlogged block (once), return summary + nudge text.
 */
export async function processTimelog(day, events, dataDir, opts = {}) {
  const analysis = await analyzeDay(day, events, opts);
  const store = loadStore(dataDir);
  const created = [];
  const skipped = [];

  if (isVikunjaConfigured() && opts.createTasks !== false) {
    for (const g of analysis.gaps) {
      const key = `${day}|${g.uid}`;
      if (store.created[key]) {
        skipped.push({ ...g, taskId: store.created[key] });
        continue;
      }
      const title = `Log ${fmtHours(g.gapMinutes)} — ${g.title}${g.kimai.customer ? ` (${g.kimai.customer})` : ""}`;
      const description = [
        `<p><strong>${esc(g.title)}</strong> · ${fmtDate(day)} ${fmtTime(g.start)}–${fmtTime(g.end)} (${fmtHours(g.minutes)} scheduled, ${fmtHours(g.coveredMinutes)} logged)</p>`,
        `<p>Kimai: ${esc(g.kimai.project)}${g.kimai.activity ? ` / ${esc(g.kimai.activity)}` : ""}${g.kimai.matched ? "" : " <em>(default — check project)</em>"}</p>`,
        `<p><a href="${g.logLink}">Log in Kimai (prefilled)</a>${g.link ? ` · <a href="${g.link}">Open calendar event</a>` : ""}</p>`,
        `<p><small>Created by Ops Hub time-gap check</small></p>`,
      ].join("");
      // due next day 17:00 local
      const due = localToUtc(addDays(day, 1), "17:00").toISOString();
      try {
        const task = await createTask({ title, description, dueDate: due, priority: 3, labels: ["timelog"] });
        store.created[key] = task.id;
        created.push({ ...g, taskId: task.id, taskUrl: taskUrl(task) });
      } catch (err) {
        console.error("timelog task failed:", err.message);
        skipped.push({ ...g, error: err.message });
      }
    }
    saveStore(dataDir, store);
  }

  const nudge = buildNudge(analysis, created, skipped);
  return { ...analysis, created, skipped, ...nudge };
}

function buildNudge(a, created, skipped) {
  const gapCount = a.gaps.length;
  const lines = [];
  if (gapCount) {
    lines.push(`⏱ ${a.totals.gap} unlogged today (${a.totals.logged} logged / ${a.totals.scheduled} scheduled)`);
    for (const g of a.gaps.slice(0, 6)) {
      lines.push(`• ${fmtTime(g.start)} ${g.title} — ${fmtHours(g.gapMinutes)}${g.kimai.customer ? ` → ${g.kimai.customer}` : ""}`);
    }
    if (a.gaps.length > 6) lines.push(`… +${a.gaps.length - 6} more`);
    const n = created.length + skipped.filter((s) => s.taskId).length;
    if (n) lines.push("", `${n} Vikunja task${n === 1 ? "" : "s"} waiting — or log straight from Ops Hub.`);
  } else if (a.blocks.length) {
    lines.push(`✅ Time logged: ${a.totals.logged} across ${a.blocks.length} block${a.blocks.length === 1 ? "" : "s"}`);
  } else {
    lines.push(`No client blocks on the calendar today · ${a.totals.logged} logged`);
  }
  return {
    gapCount,
    title: gapCount ? `Unlogged time: ${a.totals.gap}` : "Time check",
    message: lines.join("\n"),
    priority: gapCount ? "4" : "2",
  };
}
