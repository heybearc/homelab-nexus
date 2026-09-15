// Monthly bill reminders → Vikunja tasks (idempotent), plus "due soon" list for the briefing.
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { createTask, isVikunjaConfigured, defaultProjectId, taskUrl } from "./vikunja.js";
import { localToUtc, addDays, todayLocal, fmtDate } from "./tz.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const BILLS_PATH = process.env.OPS_BILLS ?? path.join(__dirname, "bills.json");

export function loadBills() {
  if (!fs.existsSync(BILLS_PATH)) return { bills: [], leadDays: 3 };
  return JSON.parse(fs.readFileSync(BILLS_PATH, "utf8"));
}

function storePath(dataDir) {
  return path.join(dataDir, "bills-created.json");
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
  fs.mkdirSync(dataDir, { recursive: true });
  fs.writeFileSync(storePath(dataDir), JSON.stringify(store, null, 2));
}

function daysInMonth(year, month1) {
  return new Date(Date.UTC(year, month1, 0)).getUTCDate();
}

/** Due date (YYYY-MM-DD) for a bill in a given YYYY-MM, or null if bill doesn't recur that month */
export function dueDateFor(bill, ym) {
  const [y, m] = ym.split("-").map(Number);
  if (Array.isArray(bill.months) && bill.months.length && !bill.months.includes(m)) return null;
  const day = Math.min(Math.max(1, Number(bill.day) || 1), daysInMonth(y, m));
  return `${y}-${String(m).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
}

function esc(s) {
  return String(s ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

/** Create tasks for all enabled bills for the given months (default: this month + next). */
export async function generateBillTasks(dataDir, months) {
  const cfg = loadBills();
  const today = todayLocal();
  const ym = today.slice(0, 7);
  const nextYm = addDays(`${ym}-28`, 7).slice(0, 7);
  const targets = months?.length ? months : [ym, nextYm];
  const store = loadStore(dataDir);
  const created = [];
  const existing = [];
  const enabled = (cfg.bills ?? []).filter((b) => b.enabled);

  if (!isVikunjaConfigured()) {
    return { ok: false, error: "VIKUNJA_API_TOKEN not set", enabledBills: enabled.length, created, existing };
  }

  const projectId = cfg.projectId ?? defaultProjectId();
  const dueHour = cfg.dueHour ?? "09:00";

  for (const target of targets) {
    for (const bill of enabled) {
      const due = dueDateFor(bill, target);
      if (!due) continue;
      if (due < today) continue; // don't backfill past bills
      const key = `${target}|${bill.name}`;
      if (store.created[key]) {
        existing.push({ bill: bill.name, due, taskId: store.created[key] });
        continue;
      }
      const title = bill.autopay
        ? `Confirm autopay: ${bill.name}${bill.amount ? ` (${bill.amount})` : ""}`
        : `Pay ${bill.name}${bill.amount ? ` — ${bill.amount}` : ""}`;
      const description = [
        `<p>Due ${fmtDate(due, { weekday: "long", month: "long", day: "numeric" })}${bill.autopay ? " · autopay — verify it went through" : ""}</p>`,
        bill.url ? `<p><a href="${esc(bill.url)}">Pay / view account</a></p>` : "",
        bill.notes ? `<p>${esc(bill.notes)}</p>` : "",
        `<p><small>Created by Ops Hub bills scheduler</small></p>`,
      ].join("");
      try {
        const task = await createTask({
          title,
          description,
          dueDate: localToUtc(due, dueHour).toISOString(),
          projectId,
          priority: bill.autopay ? 1 : 3,
          labels: ["bills"],
        });
        store.created[key] = task.id;
        created.push({ bill: bill.name, due, taskId: task.id, taskUrl: taskUrl(task), title });
      } catch (err) {
        console.error(`bill task failed (${bill.name}):`, err.message);
      }
    }
  }
  saveStore(dataDir, store);
  const message = created.length
    ? [`💳 ${created.length} bill reminder${created.length === 1 ? "" : "s"} added to Vikunja:`, ...created.map((c) => `• ${c.title} — ${fmtDate(c.due, { month: "short", day: "numeric" })}`)].join("\n")
    : "";
  return {
    ok: true,
    months: targets,
    enabledBills: enabled.length,
    created,
    existing,
    createdCount: created.length,
    title: "Bill reminders",
    message,
    priority: "3",
  };
}

/** Bills due within the next `days` days (for briefings) */
export function upcomingBills(days = 7) {
  const cfg = loadBills();
  const today = todayLocal();
  const horizon = addDays(today, days);
  const ym = today.slice(0, 7);
  const nextYm = addDays(`${ym}-28`, 7).slice(0, 7);
  const out = [];
  for (const bill of (cfg.bills ?? []).filter((b) => b.enabled)) {
    for (const target of [ym, nextYm]) {
      const due = dueDateFor(bill, target);
      if (due && due >= today && due <= horizon) out.push({ name: bill.name, due, autopay: Boolean(bill.autopay), amount: bill.amount || "" });
    }
  }
  return out.sort((a, b) => a.due.localeCompare(b.due));
}
