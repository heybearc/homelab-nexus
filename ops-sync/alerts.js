// Self-heal Prometheus alert tasks/tickets: if Prometheus is no longer firing, close Vikunja + Zammad.
import { listOpenTasks } from "./vikunja.js";
import { searchAllTickets, closeTicket, isZammadConfigured, ticketUrl } from "./zammad.js";

const PROM_URL = (process.env.PROMETHEUS_URL || "http://10.92.3.2:9090").replace(/\/+$/, "");

// [CRITICAL] ContainerDown: qs-standby   or  [WARNING] LowDiskSpace: calibre-web
const TITLE_RE = /^\[(CRITICAL|WARNING|ALERT)\]\s+([A-Za-z0-9_]+):\s+(.+)$/i;

export function parseAlertTitle(title) {
  const m = TITLE_RE.exec(String(title || "").trim());
  if (!m) return null;
  return { severity: m[1].toLowerCase(), alertname: m[2], instance: m[3].trim() };
}

export function alertKey(alertname, instance) {
  return `${alertname}|${instance}`;
}

export async function fetchFiringAlerts() {
  const res = await fetch(`${PROM_URL}/api/v1/alerts`, { headers: { Accept: "application/json" } });
  const data = await res.json();
  if (!res.ok || data.status !== "success") throw new Error(`Prometheus alerts: ${res.status} ${data.error || ""}`);
  const firing = [];
  for (const a of data.data?.alerts ?? []) {
    if (a.state !== "firing") continue;
    const name = a.labels?.alertname;
    const instance = a.labels?.instance || a.labels?.name || "unknown";
    if (!name) continue;
    firing.push({
      alertname: name,
      instance,
      severity: a.labels?.severity || "",
      key: alertKey(name, instance),
      summary: a.annotations?.summary || "",
    });
  }
  return firing;
}

async function completeVikunja(taskId) {
  const base = (process.env.VIKUNJA_API_URL || "https://tasks.cloudigan.net/api/v1").replace(/\/+$/, "");
  const res = await fetch(`${base}/tasks/${taskId}`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${process.env.VIKUNJA_API_TOKEN}`,
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: JSON.stringify({ done: true }),
  });
  if (!res.ok) throw new Error(`Vikunja complete ${taskId}: ${res.status} ${await res.text()}`);
  return res.json();
}

/**
 * Close recovered alert tasks + matching Zammad tickets.
 * dryRun: true → report only.
 */
export async function healAlerts({ dryRun = false } = {}) {
  const firing = await fetchFiringAlerts();
  const firingKeys = new Set(firing.map((a) => a.key));

  const tasks = (await listOpenTasks()).filter((t) => parseAlertTitle(t.title));
  const tickets = isZammadConfigured()
    ? (await searchAllTickets('(title:"[CRITICAL]" OR title:"[WARNING]") AND state.name:open')).filter((t) => parseAlertTitle(t.title))
    : [];

  const recoveredTasks = [];
  const stillFiringTasks = [];
  for (const t of tasks) {
    const p = parseAlertTitle(t.title);
    const row = { id: t.id, title: t.title, alertname: p.alertname, instance: p.instance, key: alertKey(p.alertname, p.instance) };
    if (firingKeys.has(row.key)) stillFiringTasks.push(row);
    else recoveredTasks.push(row);
  }

  const recoveredTickets = [];
  const stillFiringTickets = [];
  for (const t of tickets) {
    const p = parseAlertTitle(t.title);
    const row = { id: t.id, number: t.number, title: t.title, alertname: p.alertname, instance: p.instance, key: alertKey(p.alertname, p.instance), url: ticketUrl(t) };
    if (firingKeys.has(row.key)) stillFiringTickets.push(row);
    else recoveredTickets.push(row);
  }

  const closedTasks = [];
  const closedTickets = [];
  const errors = [];

  if (!dryRun) {
    for (const t of recoveredTasks) {
      try {
        await completeVikunja(t.id);
        closedTasks.push(t);
      } catch (err) {
        errors.push(`task ${t.id}: ${err.message}`);
      }
    }
    for (const t of recoveredTickets) {
      try {
        await closeTicket(
          t.id,
          `Alert is no longer firing in Prometheus.\n\n${t.title}\n\nClosed by Ops Hub alert healer (validated against ${PROM_URL}/api/v1/alerts).\n\n— Ops Hub`,
        );
        closedTickets.push(t);
      } catch (err) {
        errors.push(`ticket ${t.number}: ${err.message}`);
      }
    }
  }

  const healed = closedTasks.length + closedTickets.length;
  const lines = [];
  if (healed) {
    lines.push(`🩹 Closed ${closedTasks.length} recovered task${closedTasks.length === 1 ? "" : "s"} and ${closedTickets.length} support ticket${closedTickets.length === 1 ? "" : "s"}`);
    for (const t of closedTasks.slice(0, 8)) lines.push(`• task: ${t.title}`);
    for (const t of closedTickets.slice(0, 8)) lines.push(`• ticket #${t.number}: ${t.title}`);
  }

  return {
    ok: true,
    dryRun,
    prometheus: PROM_URL,
    firing: firing.length,
    firingAlerts: firing,
    openAlertTasks: tasks.length,
    openAlertTickets: tickets.length,
    recoveredTasks: recoveredTasks.length,
    recoveredTickets: recoveredTickets.length,
    stillFiringTasks,
    stillFiringTickets,
    closedTasks,
    closedTickets,
    errors,
    title: healed ? "Alert healer" : "Alert healer — nothing to close",
    message: lines.join("\n"),
    priority: "3",
    createdCount: healed, // n8n if-gt-zero
  };
}
