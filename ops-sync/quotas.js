// Hours-quota alerts: ntfy when a customer is near or over purchased hours.
import fs from "fs";
import path from "path";
import { analyzeQuotas } from "./kimai.js";
import { addDays, todayLocal } from "./tz.js";

function storePath(dataDir) {
  return path.join(dataDir, "quota-alerts.json");
}

function loadStore(dataDir) {
  const p = storePath(dataDir);
  if (!fs.existsSync(p)) return { sent: {} };
  try {
    return JSON.parse(fs.readFileSync(p, "utf8"));
  } catch {
    return { sent: {} };
  }
}

function saveStore(dataDir, store) {
  fs.mkdirSync(dataDir, { recursive: true });
  fs.writeFileSync(storePath(dataDir), JSON.stringify(store, null, 2));
}

/**
 * Build a nudge for customers at warn/critical/over that haven't been alerted
 * at this level in the last `snoozeDays` (default 3).
 */
export async function processQuotaAlerts(dataDir, opts = {}) {
  const analysis = await analyzeQuotas();
  const snoozeDays = Number(opts.snoozeDays ?? process.env.OPS_QUOTA_SNOOZE_DAYS ?? 3);
  const store = loadStore(dataDir);
  const today = todayLocal();
  const cutoff = addDays(today, -snoozeDays);
  const fresh = [];

  for (const c of analysis.alerts ?? []) {
    const key = `${c.id}|${c.level}`;
    const last = store.sent[key];
    if (last && last >= cutoff && !opts.force) continue;
    store.sent[key] = today;
    fresh.push(c);
  }
  if (fresh.length) saveStore(dataDir, store);

  const lines = [];
  if (fresh.length) {
    lines.push(`⏳ ${fresh.length} client${fresh.length === 1 ? "" : "s"} near hours quota`);
    for (const c of fresh) {
      const tag = c.level === "over" ? "OVER" : c.level === "critical" ? "critical" : "warn";
      lines.push(`• ${c.name}: ${c.used} of ${c.purchased} used · ${c.remaining} [${tag}]`);
    }
    lines.push("", "Buy more hours or pause work — Ops Hub → Hours remaining");
  }

  return {
    ...analysis,
    fresh,
    freshCount: fresh.length,
    title: fresh.some((c) => c.level === "over" || c.level === "critical")
      ? "Client hours almost gone"
      : "Client hours running low",
    message: lines.join("\n"),
    priority: fresh.some((c) => c.level === "over") ? "5" : fresh.some((c) => c.level === "critical") ? "4" : "3",
  };
}
