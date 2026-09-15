"use client";

import { useCallback, useEffect, useState } from "react";
import { BrandMark } from "@/components/BrandMark";
import { TodayTimeline, type TimelineEvent, type RunningTimer } from "@/components/TodayTimeline";

type Task = { id: number; title: string; due_date?: string | null; priority: number; project_title?: string };
type TimelogGap = {
  uid: string;
  title: string;
  start: string;
  end: string;
  minutes: number;
  coveredMinutes: number;
  gapMinutes: number;
  ended: boolean;
  logLink: string;
  link?: string | null;
  kimai: { customer?: string | null; project: string; matched: boolean };
};
type Timelog = {
  date: string;
  kimaiConfigured: boolean;
  blocks: TimelogGap[];
  gaps: TimelogGap[];
  logged: { id: number; begin: string | null; end: string | null; durationMinutes: number; project?: string | null; customer?: string | null; description: string; running: boolean }[];
  totals: { scheduledMinutes: number; loggedMinutes: number; gapMinutes: number; scheduled: string; logged: string; gap: string; byCustomer: Record<string, number> };
  kimaiUrl: string;
  running: RunningTimer | null;
};

function fmtMins(m: number) {
  const v = Math.max(0, Math.round(m));
  if (v < 60) return `${v}m`;
  const h = Math.floor(v / 60);
  const r = v % 60;
  return r ? `${h}h ${r}m` : `${h}h`;
}
type CalEvent = TimelineEvent;
type Conflict = {
  id?: string;
  a: string;
  b: string;
  at: string;
  overlapMinutes?: number;
  sources?: string[];
  calendars?: (string | null)[];
  links?: (string | null)[];
  lifeAreas?: string[];
  crossLife?: boolean;
  crossAccount?: boolean;
  severity?: "high" | "low";
};
type GoogleCal = {
  id: string;
  summary: string;
  primary?: boolean;
  accessRole?: string;
  accountEmail: string;
};

const DESTINATIONS = [
  { id: "vikunja", label: "Vikunja task" },
  { id: "google_personal", label: "Personal Google calendar" },
  { id: "entra_cloudigan", label: "Cloudigan / Entra calendar" },
  { id: "kimai", label: "Kimai time block" },
  { id: "kimai_project", label: "New Kimai project" },
];

type QuotaRow = {
  id: number;
  name: string;
  purchased: string;
  used: string;
  remaining: string;
  usedPct: number | null;
  level: "none" | "ok" | "warn" | "critical" | "over";
  monthly?: boolean;
  kimaiUrl: string;
  projects: { id: number; name: string }[];
};
type KimaiCustomer = { id: number; name: string };
type AlertHeal = {
  firing: number;
  recoveredTasks: number;
  recoveredTickets: number;
  stillFiringTasks: { title: string }[];
  stillFiringTickets: { title: string; number?: string }[];
  closedTasks?: { title: string }[];
  closedTickets?: { title: string; number?: string }[];
};

const LIFE_COLORS: Record<string, string> = {
  personal: "#3b82f6",
  cloudigan: "#2d388a",
  theocratic: "#059669",
  thrive: "#f59e0b",
  jwpub: "#0d9488",
  other: "#6b7280",
};

export default function OpsHubPage() {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [todayEvents, setTodayEvents] = useState<CalEvent[]>([]);
  const [todayAllDay, setTodayAllDay] = useState<CalEvent[]>([]);
  const [calTimeZone, setCalTimeZone] = useState<string | undefined>(undefined);
  const [syncedAt, setSyncedAt] = useState<string | null>(null);
  const [conflicts, setConflicts] = useState<Conflict[]>([]);
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [due, setDue] = useState("");
  const [durationMinutes, setDurationMinutes] = useState(60);
  const [attendees, setAttendees] = useState("");
  const [destinations, setDestinations] = useState<string[]>(["vikunja"]);
  const [loading, setLoading] = useState(false);
  const [timelog, setTimelog] = useState<Timelog | null>(null);
  const [timerBusy, setTimerBusy] = useState(false);
  const [message, setMessage] = useState("");
  const [msAccounts, setMsAccounts] = useState<{ email: string; lifeArea: string; connectedAt: string }[]>([]);
  const [msConfigured, setMsConfigured] = useState(false);
  const [googleAccounts, setGoogleAccounts] = useState<{ email: string; lifeArea: string; connectedAt: string }[]>([]);
  const [googleConfigured, setGoogleConfigured] = useState(false);
  const [googleEmail, setGoogleEmail] = useState("");
  const [googleCalendarId, setGoogleCalendarId] = useState("primary");
  const [googleCalendars, setGoogleCalendars] = useState<GoogleCal[]>([]);
  const [microsoftEmail, setMicrosoftEmail] = useState("");
  const [quotas, setQuotas] = useState<QuotaRow[]>([]);
  const [kimaiCustomers, setKimaiCustomers] = useState<KimaiCustomer[]>([]);
  const [newCustomerMode, setNewCustomerMode] = useState(true);
  const [kimaiCustomerId, setKimaiCustomerId] = useState("");
  const [kimaiPrefix, setKimaiPrefix] = useState("");
  const [kimaiProjectName, setKimaiProjectName] = useState("");
  const [kimaiHours, setKimaiHours] = useState("");
  const [kimaiExtraM365, setKimaiExtraM365] = useState(false);
  const [alertHeal, setAlertHeal] = useState<AlertHeal | null>(null);
  const [healBusy, setHealBusy] = useState(false);

  const loadGoogleCalendars = useCallback(async (email: string) => {
    if (!email) {
      setGoogleCalendars([]);
      return;
    }
    const res = await fetch(`/api/auth/google/calendars?email=${encodeURIComponent(email)}`);
    const data = await res.json();
    const cals: GoogleCal[] = data.calendars ?? [];
    setGoogleCalendars(cals);
    setGoogleCalendarId((prev) => {
      if (prev && cals.some((c) => c.id === prev)) return prev;
      const writable = cals.filter((c) => c.accessRole === "owner" || c.accessRole === "writer");
      const preferred = writable.find((c) => c.primary) ?? writable[0] ?? cals.find((c) => c.primary) ?? cals[0];
      return preferred?.id ?? "primary";
    });
  }, []);

  const refreshTimelog = useCallback(async () => {
    try {
      const res = await fetch("/api/timelog?date=today", { cache: "no-store" });
      const data = await res.json();
      if (res.ok) setTimelog(data);
    } catch {
      /* ops-sync offline — leave previous state */
    }
  }, []);

  const refresh = useCallback(async () => {
    const [tasksRes, calRes, msRes, gRes] = await Promise.all([
      fetch("/api/tasks"),
      fetch("/api/calendar"),
      fetch("/api/auth/microsoft/accounts"),
      fetch("/api/auth/google/accounts"),
    ]);
    refreshTimelog();
    fetch("/api/quotas", { cache: "no-store" })
      .then((r) => r.json())
      .then((d) => setQuotas(d.customers ?? []))
      .catch(() => undefined);
    fetch("/api/alerts", { cache: "no-store" })
      .then((r) => r.json())
      .then((d) => {
        if (!d.error) setAlertHeal(d);
      })
      .catch(() => undefined);
    fetch("/api/clients", { cache: "no-store" })
      .then((r) => r.json())
      .then((d) => setKimaiCustomers(d.customers ?? []))
      .catch(() => undefined);
    const tasksData = await tasksRes.json();
    const calData = await calRes.json();
    const msData = await msRes.json();
    const gData = await gRes.json();
    setTasks(tasksData.tasks ?? []);
    // Prefer ops-sync's timezone-aware "today" bucket; fall back to a local-date filter
    if (calData.today?.events) {
      setTodayEvents(calData.today.events);
      setTodayAllDay(calData.today.allDay ?? []);
    } else {
      const localToday = new Date().toLocaleDateString("en-CA");
      const all: CalEvent[] = calData.events ?? [];
      setTodayEvents(all.filter((e) => new Date(e.start).toLocaleDateString("en-CA") === localToday && !e.allDay));
      setTodayAllDay(all.filter((e) => new Date(e.start).toLocaleDateString("en-CA") === localToday && e.allDay));
    }
    setCalTimeZone(calData.timeZone ?? undefined);
    setSyncedAt(calData.syncedAt ?? null);
    setConflicts(calData.conflicts ?? []);
    setMsAccounts(msData.accounts ?? []);
    setMsConfigured(msData.configured ?? false);
    setGoogleAccounts(gData.accounts ?? []);
    setGoogleConfigured(gData.configured ?? false);
    setGoogleEmail((prev) => prev || gData.accounts?.[0]?.email || "");
    setMicrosoftEmail((prev) => {
      if (prev) return prev;
      const cloudigan = (msData.accounts ?? []).find((a: { lifeArea: string }) => a.lifeArea === "cloudigan");
      return cloudigan?.email || msData.accounts?.[0]?.email || "";
    });
  }, [refreshTimelog]);

  useEffect(() => {
    if (googleEmail) loadGoogleCalendars(googleEmail);
  }, [googleEmail, loadGoogleCalendars]);

  useEffect(() => {
    refresh();
    const params = new URLSearchParams(window.location.search);
    const msError = params.get("ms_error");
    const msConnected = params.get("ms_connected");
    const googleError = params.get("google_error");
    const googleConnected = params.get("google_connected");
    if (msError) setMessage(msError);
    if (msConnected) setMessage(`Connected Microsoft calendar: ${msConnected}`);
    if (googleError) setMessage(googleError);
    if (googleConnected) setMessage(`Connected Google calendar: ${googleConnected}`);
    if (msError || msConnected || googleError || googleConnected) {
      window.history.replaceState({}, "", window.location.pathname);
    }
    // keep the running-timer / logged-time view fresh
    const t = setInterval(refreshTimelog, 60_000);
    return () => clearInterval(t);
  }, [refresh, refreshTimelog]);

  async function completeTask(id: number) {
    await fetch("/api/tasks", { method: "POST", body: JSON.stringify({ taskId: id }) });
    await refresh();
  }

  async function submitCapture(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setMessage("");
    try {
      const res = await fetch("/api/capture", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          title,
          description,
          due: due ? new Date(due).toISOString() : undefined,
          duration_minutes: durationMinutes,
          attendees: attendees
            .split(/[,;\n]+/)
            .map((s) => s.trim())
            .filter(Boolean),
          timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone,
          destinations,
          google_email: googleEmail || undefined,
          google_calendar_id: googleCalendarId || undefined,
          microsoft_email: microsoftEmail || undefined,
          kimai_customer_id: destinations.includes("kimai_project") && !newCustomerMode ? kimaiCustomerId : undefined,
          kimai_customer_name: destinations.includes("kimai_project") && newCustomerMode ? title : undefined,
          kimai_project_name: kimaiProjectName || undefined,
          kimai_prefix: kimaiPrefix || undefined,
          kimai_hours: kimaiHours ? Number(kimaiHours) : undefined,
          kimai_extra_m365: kimaiExtraM365,
        }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error);
      const onboard = data.results?.kimai_project;
      setMessage(onboard?.message ? String(onboard.message).replace(/\n/g, " · ") : "Captured successfully");
      setTitle("");
      setDescription("");
      setDue("");
      setAttendees("");
      setKimaiHours("");
      setKimaiProjectName("");
      setKimaiPrefix("");
      await refresh();
    } catch (err) {
      setMessage(String(err));
    } finally {
      setLoading(false);
    }
  }

  async function timerAction(action: "start" | "stop", opts?: { project?: string; activity?: string; description?: string }) {
    setTimerBusy(true);
    try {
      const res = await fetch("/api/timer", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          action,
          project: opts?.project ?? "Cloudy - General Work",
          activity: opts?.activity ?? "General Work",
          description: opts?.description ?? "",
        }),
      });
      const data = await res.json();
      const result = data.result ?? data;
      if (!res.ok || result.ok === false) {
        setMessage(String(result.error ?? data.error ?? "Timer action failed"));
      } else if (action === "start") {
        setMessage(`Timer started · ${result.project ?? opts?.project ?? ""}${opts?.description ? ` — ${opts.description}` : ""}`);
      } else {
        setMessage(result.message ?? "Timer stopped");
      }
    } catch (err) {
      setMessage(String(err));
    } finally {
      setTimerBusy(false);
      await refreshTimelog();
    }
  }

  async function runAlertHeal() {
    setHealBusy(true);
    try {
      const res = await fetch("/api/alerts", { method: "POST" });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error ?? "heal failed");
      setAlertHeal(data);
      setMessage(data.message || `Closed ${data.closedTasks?.length ?? 0} tasks, ${data.closedTickets?.length ?? 0} tickets`);
      await refresh();
    } catch (err) {
      setMessage(String(err));
    } finally {
      setHealBusy(false);
    }
  }

  function startTimerFor(e: TimelineEvent) {
    if (!e.kimai) return;
    return timerAction("start", { project: e.kimai.project, activity: e.kimai.activity ?? undefined, description: e.title });
  }

  const running = timelog?.running ?? null;

  async function disconnectMicrosoft(email: string) {
    await fetch(`/api/auth/microsoft/accounts?email=${encodeURIComponent(email)}`, { method: "DELETE" });
    await refresh();
  }

  async function disconnectGoogle(email: string) {
    await fetch(`/api/auth/google/accounts?email=${encodeURIComponent(email)}`, { method: "DELETE" });
    await refresh();
  }

  async function resolveConflict(conflict: Conflict, action: "dismiss" | "task") {
    const res = await fetch("/api/conflicts", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action, conflict, id: conflict.id }),
    });
    const data = await res.json();
    if (!res.ok) {
      setMessage(String(data.error ?? "Conflict action failed"));
      return;
    }
    setMessage(action === "task" ? "Vikunja task created to resolve conflict" : "Conflict dismissed for 7 days");
    await refresh();
  }

  const MS_CONNECT = [
    { lifeArea: "thrive", label: "Thrive work" },
    { lifeArea: "cloudigan", label: "Cloudigan" },
    { lifeArea: "theocratic", label: "Bethel" },
    { lifeArea: "jwpub", label: "JW Pub" },
  ];

  function toggleDest(id: string) {
    setDestinations((prev) => (prev.includes(id) ? prev.filter((d) => d !== id) : [...prev, id]));
  }

  const highConflicts = conflicts.filter((c) => c.severity !== "low");
  const lowConflicts = conflicts.filter((c) => c.severity === "low");

  function renderConflict(c: Conflict, i: number) {
    const [linkA, linkB] = c.links ?? [];
    const [calA, calB] = c.calendars ?? [];
    return (
      <div key={c.id ?? i} className="ops-conflict-row">
        <div>
          <div>
            {linkA ? <a href={linkA} target="_blank" rel="noreferrer">{c.a}</a> : c.a}
            {" ↔ "}
            {linkB ? <a href={linkB} target="_blank" rel="noreferrer">{c.b}</a> : c.b}
          </div>
          <div className="ops-small">
            {new Date(c.at).toLocaleString("en-US", { timeZone: calTimeZone, weekday: "short", month: "short", day: "numeric", hour: "numeric", minute: "2-digit" })}
            {" · "}{c.overlapMinutes ?? "?"} min
            {c.lifeAreas ? ` · ${c.lifeAreas.join(" / ")}` : ""}
            {calA || calB ? ` · ${[calA, calB].filter(Boolean).join(" vs ")}` : ""}
          </div>
        </div>
        <div className="ops-dest-row" style={{ margin: 0 }}>
          <button className="ops-btn-secondary" type="button" onClick={() => resolveConflict(c, "dismiss")}>
            Dismiss
          </button>
          <button className="ops-btn" type="button" onClick={() => resolveConflict(c, "task")}>
            Make task
          </button>
        </div>
      </div>
    );
  }

  return (
    <main className="ops-shell">
      <header className="ops-header">
        <div className="ops-brand">
          <BrandMark />
          <div className="ops-brand-text">
            <h1>Ops Hub</h1>
            <p>Calendar · tasks · time — Cloudigan operations</p>
          </div>
        </div>
        <div className="ops-timer-box">
          {running ? (
            <>
              <span className="ops-time-running" style={{ margin: 0 }}>
                <span className="ops-pulse" />
                <span>
                  {running.customer ?? running.project ?? "Kimai"}
                  {running.description ? ` — ${running.description}` : ""}
                  {running.begin ? ` · since ${new Date(running.begin).toLocaleTimeString("en-US", { timeZone: calTimeZone, hour: "numeric", minute: "2-digit" })}` : ""}
                  {typeof running.elapsedMinutes === "number" ? ` (${fmtMins(running.elapsedMinutes)})` : ""}
                </span>
              </span>
              <button className="ops-btn-secondary" type="button" disabled={timerBusy} onClick={() => timerAction("stop")}>Stop</button>
            </>
          ) : (
            <>
              <button className="ops-btn" type="button" disabled={timerBusy} onClick={() => timerAction("start")}>Start timer</button>
              <span className="ops-small">Cloudy · General Work — or use ⏱ on an event below</span>
            </>
          )}
        </div>
      </header>

      {highConflicts.length > 0 && (
        <section className="ops-alert">
          <strong>{highConflicts.length} cross-calendar conflict{highConflicts.length === 1 ? "" : "s"}</strong>
          <p className="ops-small ops-muted" style={{ margin: "0.25rem 0 0.5rem" }}>
            Different life areas or accounts overlap — click a title to open it, dismiss if intentional, or make a task to fix.
          </p>
          {highConflicts.slice(0, 8).map(renderConflict)}
          {highConflicts.length > 8 && (
            <p className="ops-small ops-muted">… +{highConflicts.length - 8} more</p>
          )}
        </section>
      )}

      {lowConflicts.length > 0 && (
        <details className="ops-alert ops-alert-quiet">
          <summary>
            {lowConflicts.length} same-calendar overlap{lowConflicts.length === 1 ? "" : "s"}
            <span className="ops-small ops-muted"> — usually intentional; not in the morning briefing</span>
          </summary>
          {lowConflicts.slice(0, 10).map(renderConflict)}
        </details>
      )}

      <div className="ops-grid">
        <section className="ops-card">
          <h2>Quick capture</h2>
          <form onSubmit={submitCapture}>
            <input
              className="ops-input"
              placeholder={destinations.includes("kimai_project") && newCustomerMode ? "Customer name" : "Title"}
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              required
            />
            <textarea className="ops-textarea" placeholder="Notes (optional)" value={description} onChange={(e) => setDescription(e.target.value)} />
            <input className="ops-input" type="datetime-local" value={due} onChange={(e) => setDue(e.target.value)} />
            {(destinations.includes("google_personal") || destinations.includes("entra_cloudigan")) && (
              <>
                <input
                  className="ops-input"
                  type="number"
                  min={15}
                  step={15}
                  value={durationMinutes}
                  onChange={(e) => setDurationMinutes(Number(e.target.value) || 60)}
                  placeholder="Duration (minutes)"
                  aria-label="Duration minutes"
                />
                <input
                  className="ops-input"
                  placeholder="Invitees (emails, comma-separated)"
                  value={attendees}
                  onChange={(e) => setAttendees(e.target.value)}
                />
              </>
            )}
            <div className="ops-dest-row">
              {DESTINATIONS.map((d) => (
                <label key={d.id} className="ops-chip">
                  <input type="checkbox" checked={destinations.includes(d.id)} onChange={() => toggleDest(d.id)} />
                  {d.label}
                </label>
              ))}
            </div>
            {destinations.includes("google_personal") && googleAccounts.length > 0 && (
              <>
                {googleAccounts.length > 1 && (
                  <select
                    className="ops-input"
                    value={googleEmail}
                    onChange={(e) => setGoogleEmail(e.target.value)}
                  >
                    {googleAccounts.map((a) => (
                      <option key={a.email} value={a.email}>{a.email}</option>
                    ))}
                  </select>
                )}
                <select
                  className="ops-input"
                  value={googleCalendarId}
                  onChange={(e) => setGoogleCalendarId(e.target.value)}
                >
                  {(googleCalendars.filter((c) => c.accessRole === "owner" || c.accessRole === "writer").length
                    ? googleCalendars.filter((c) => c.accessRole === "owner" || c.accessRole === "writer")
                    : googleCalendars
                  ).map((c) => (
                    <option key={`${c.accountEmail}:${c.id}`} value={c.id}>
                      {c.summary}{c.primary ? " (primary)" : ""}
                    </option>
                  ))}
                </select>
              </>
            )}
            {destinations.includes("kimai_project") && (
              <div className="ops-onboard">
                <div className="ops-dest-row" style={{ marginTop: 0 }}>
                  <label className="ops-chip">
                    <input type="radio" checked={newCustomerMode} onChange={() => setNewCustomerMode(true)} />
                    New customer
                  </label>
                  <label className="ops-chip">
                    <input type="radio" checked={!newCustomerMode} onChange={() => setNewCustomerMode(false)} />
                    Existing customer
                  </label>
                </div>
                {!newCustomerMode && (
                  <select
                    className="ops-input"
                    value={kimaiCustomerId}
                    onChange={(e) => {
                      setKimaiCustomerId(e.target.value);
                      const c = kimaiCustomers.find((x) => String(x.id) === e.target.value);
                      if (c && !title) setTitle(c.name);
                    }}
                    required
                  >
                    <option value="">Select Kimai customer…</option>
                    {kimaiCustomers.map((c) => (
                      <option key={c.id} value={c.id}>{c.name}</option>
                    ))}
                  </select>
                )}
                <input
                  className="ops-input"
                  placeholder={newCustomerMode ? "Project name (default: PREFIX - General Work)" : "New project name (default: PREFIX - General Work)"}
                  value={kimaiProjectName}
                  onChange={(e) => setKimaiProjectName(e.target.value)}
                />
                <div className="ops-dest-row" style={{ marginTop: 0 }}>
                  <input
                    className="ops-input"
                    style={{ flex: "0 0 7rem", marginBottom: 0 }}
                    placeholder="Prefix"
                    value={kimaiPrefix}
                    onChange={(e) => setKimaiPrefix(e.target.value.toUpperCase())}
                    maxLength={6}
                    aria-label="Project prefix"
                  />
                  <input
                    className="ops-input"
                    style={{ flex: 1, marginBottom: 0 }}
                    type="number"
                    min={0}
                    step={0.5}
                    placeholder="Hours purchased"
                    value={kimaiHours}
                    onChange={(e) => setKimaiHours(e.target.value)}
                    aria-label="Hours purchased"
                  />
                </div>
                <label className="ops-chip">
                  <input type="checkbox" checked={kimaiExtraM365} onChange={(e) => setKimaiExtraM365(e.target.checked)} />
                  Also create M365 Management project
                </label>
                <p className="ops-small ops-muted">
                  Creates the Kimai project{newCustomerMode ? " and customer" : ""}, a Vikunja project under Cloudigan Clients, and the onboarding task list.
                </p>
              </div>
            )}
            {destinations.includes("entra_cloudigan") && msAccounts.length > 1 && (
              <select className="ops-input" value={microsoftEmail} onChange={(e) => setMicrosoftEmail(e.target.value)}>
                {msAccounts.map((a) => (
                  <option key={a.email} value={a.email}>{a.email} ({a.lifeArea})</option>
                ))}
              </select>
            )}
            <button className="ops-btn" type="submit" disabled={loading}>{loading ? "Sending…" : "Capture"}</button>
            {message && <p className="ops-small">{message}</p>}
          </form>
        </section>

        <section className="ops-card">
          <h2>Microsoft calendars</h2>
          {!msConfigured ? (
            <p className="ops-muted">Set M365_CLIENT_ID and M365_CLIENT_SECRET on ops-hub, then redeploy.</p>
          ) : (
            <>
              <p className="ops-small ops-muted">Sign in with each account — no sharing to Cloudigan required.</p>
              <div className="ops-dest-row">
                {MS_CONNECT.map((m) => (
                  <a
                    key={m.lifeArea}
                    className="ops-btn-secondary ops-connect-link"
                    href={`/api/auth/microsoft?lifeArea=${m.lifeArea}`}
                  >
                    Connect {m.label}
                  </a>
                ))}
              </div>
              {msAccounts.length > 0 && (
                <ul className="ops-list">
                  {msAccounts.map((a) => (
                    <li key={a.email} className="ops-task-item">
                      <span className="ops-dot" style={{ background: LIFE_COLORS[a.lifeArea] ?? LIFE_COLORS.other }} />
                      <div style={{ flex: 1 }}>
                        <div>{a.email}</div>
                        <div className="ops-small">{a.lifeArea} · connected {new Date(a.connectedAt).toLocaleDateString()}</div>
                      </div>
                      <button className="ops-btn-secondary" type="button" onClick={() => disconnectMicrosoft(a.email)}>Remove</button>
                    </li>
                  ))}
                </ul>
              )}
            </>
          )}
        </section>

        <section className="ops-card">
          <h2>Google calendars</h2>
          {!googleConfigured ? (
            <p className="ops-muted">Set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET, then redeploy. See OPS-HUB-GOOGLE-CALENDAR-OAUTH.md.</p>
          ) : (
            <>
              <p className="ops-small ops-muted">Connect each personal Gmail — all calendars on that account are synced.</p>
              <div className="ops-dest-row">
                <a className="ops-btn-secondary ops-connect-link" href="/api/auth/google">
                  Connect Google
                </a>
              </div>
              {googleAccounts.length > 0 && (
                <ul className="ops-list">
                  {googleAccounts.map((a) => (
                    <li key={a.email} className="ops-task-item">
                      <span className="ops-dot" style={{ background: LIFE_COLORS.personal }} />
                      <div style={{ flex: 1 }}>
                        <div>{a.email}</div>
                        <div className="ops-small">personal · connected {new Date(a.connectedAt).toLocaleDateString()}</div>
                      </div>
                      <button className="ops-btn-secondary" type="button" onClick={() => disconnectGoogle(a.email)}>Remove</button>
                    </li>
                  ))}
                </ul>
              )}
              {googleCalendars.length > 0 && (
                <div style={{ marginTop: "0.75rem" }}>
                  <div className="ops-small ops-muted">Calendars on {googleEmail || "account"}:</div>
                  <ul className="ops-list">
                    {googleCalendars.slice(0, 20).map((c) => (
                      <li key={c.id} className="ops-event-item">
                        <span className="ops-dot" style={{ background: LIFE_COLORS.personal }} />
                        <div>
                          <div>{c.summary}{c.primary ? " · primary" : ""}</div>
                          <div className="ops-small">{c.accessRole}</div>
                        </div>
                      </li>
                    ))}
                  </ul>
                </div>
              )}
            </>
          )}
        </section>

        <section className="ops-card ops-full-width">
          <h2>Today</h2>
          {todayEvents.length === 0 && todayAllDay.length === 0 && !syncedAt ? (
            <p className="ops-muted">No events synced yet — connect a calendar above or add ICS feeds in ops-sync.</p>
          ) : (
            <TodayTimeline
              events={todayEvents}
              allDay={todayAllDay}
              colors={LIFE_COLORS}
              timeZone={calTimeZone}
              syncedAt={syncedAt}
              running={running}
              onStartTimer={startTimerFor}
              onStopTimer={() => timerAction("stop")}
              timerBusy={timerBusy}
            />
          )}
        </section>

        {alertHeal && (alertHeal.recoveredTasks > 0 || alertHeal.recoveredTickets > 0 || alertHeal.stillFiringTasks.length > 0) && (
          <section className="ops-card">
            <h2>Monitoring alerts</h2>
            <p className="ops-small ops-muted" style={{ marginTop: "-0.5rem" }}>
              Validated against Prometheus — recovered items close in Vikunja and Zammad automatically every 10 minutes.
            </p>
            {alertHeal.recoveredTasks + alertHeal.recoveredTickets > 0 && (
              <div className="ops-gap-row">
                <div>
                  <strong>{alertHeal.recoveredTasks}</strong> recovered task{alertHeal.recoveredTasks === 1 ? "" : "s"}
                  {" · "}
                  <strong>{alertHeal.recoveredTickets}</strong> recovered ticket{alertHeal.recoveredTickets === 1 ? "" : "s"}
                </div>
                <button className="ops-btn ops-btn-xs" type="button" disabled={healBusy} onClick={runAlertHeal}>
                  {healBusy ? "Closing…" : "Close recovered"}
                </button>
              </div>
            )}
            {alertHeal.stillFiringTasks.length > 0 && (
              <ul className="ops-list">
                {alertHeal.stillFiringTasks.slice(0, 8).map((t) => (
                  <li key={t.title} className="ops-event-item">
                    <span className="ops-dot" style={{ background: "#b91c1c" }} />
                    <div>
                      <div>{t.title}</div>
                      <div className="ops-small">still firing</div>
                    </div>
                  </li>
                ))}
              </ul>
            )}
            <p className="ops-small">{alertHeal.firing} alert{alertHeal.firing === 1 ? "" : "s"} firing in Prometheus now.</p>
          </section>
        )}

        <section className="ops-card">
          <h2>Hours remaining</h2>
          {quotas.length === 0 ? (
            <p className="ops-muted">No Kimai customers with a quota yet. Set hours when you capture a project, or in Kimai → customer → time budget.</p>
          ) : (
            <ul className="ops-list">
              {quotas.filter((q) => q.level !== "none" || q.used !== "0m").map((q) => {
                const pct = Math.min(100, q.usedPct ?? 0);
                const color = q.level === "over" ? "#b91c1c" : q.level === "critical" ? "#c2410c" : q.level === "warn" ? "#b45309" : "#15803d";
                return (
                  <li key={q.id} className="ops-quota-row">
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div className="ops-tl-title">
                        <a href={q.kimaiUrl} target="_blank" rel="noreferrer">{q.name}</a>
                        {q.level !== "ok" && q.level !== "none" && (
                          <span className={q.level === "over" || q.level === "critical" ? "ops-badge-warn" : "ops-badge-live"}>
                            {q.level}
                          </span>
                        )}
                      </div>
                      <div className="ops-quota-bar" aria-hidden>
                        <span style={{ width: `${pct}%`, background: color }} />
                      </div>
                      <div className="ops-small">
                        {q.used} of {q.purchased} used · {q.remaining} left
                        {q.monthly ? " · resets monthly" : ""}
                      </div>
                    </div>
                  </li>
                );
              })}
            </ul>
          )}
        </section>

        <section className="ops-card">
          <h2>Time today</h2>
          {!timelog ? (
            <p className="ops-muted">Loading Kimai…</p>
          ) : !timelog.kimaiConfigured ? (
            <p className="ops-muted">Set KIMAI_API_TOKEN on ops-sync to compare calendar blocks with logged time.</p>
          ) : (
            <>
              <div className="ops-time-summary">
                <div><strong>{timelog.totals.logged}</strong> <span className="ops-small">logged</span></div>
                <div><strong>{timelog.totals.scheduled}</strong> <span className="ops-small">client blocks</span></div>
                <div>
                  <strong style={{ color: timelog.totals.gapMinutes ? "#b45309" : "#15803d" }}>{timelog.totals.gap}</strong>{" "}
                  <span className="ops-small">unlogged</span>
                </div>
              </div>

              {timelog.gaps.length > 0 && (
                <div style={{ marginBottom: "0.6rem" }}>
                  <div className="ops-small ops-muted" style={{ marginBottom: "0.2rem" }}>Ended without a matching Kimai entry:</div>
                  {timelog.gaps.map((g) => (
                    <div key={g.uid} className="ops-gap-row">
                      <div>
                        <div>{g.title}</div>
                        <div className="ops-small">
                          {new Date(g.start).toLocaleTimeString("en-US", { timeZone: calTimeZone, hour: "numeric", minute: "2-digit" })} · {fmtMins(g.gapMinutes)} unlogged · {g.kimai.customer ?? g.kimai.project}
                          {!g.kimai.matched && " (default)"}
                        </div>
                      </div>
                      <a className="ops-btn-secondary ops-btn-xs ops-connect-link" href={g.logLink} target="_blank" rel="noreferrer">
                        Log in Kimai
                      </a>
                    </div>
                  ))}
                </div>
              )}

              {timelog.logged.length > 0 ? (
                <ul className="ops-list">
                  {timelog.logged.map((l) => (
                    <li key={l.id} className="ops-event-item">
                      <span className="ops-dot" style={{ background: l.running ? "#0284c7" : LIFE_COLORS.cloudigan }} />
                      <div style={{ flex: 1 }}>
                        <div>
                          {l.customer ?? l.project ?? "Kimai"}
                          {l.description ? ` — ${l.description}` : ""}
                          {l.running && <span className="ops-badge-track" style={{ marginLeft: "0.4rem" }}>running</span>}
                        </div>
                        <div className="ops-small">
                          {l.begin ? new Date(l.begin).toLocaleTimeString("en-US", { timeZone: calTimeZone, hour: "numeric", minute: "2-digit" }) : ""}
                          {l.end ? ` – ${new Date(l.end).toLocaleTimeString("en-US", { timeZone: calTimeZone, hour: "numeric", minute: "2-digit" })}` : ""}
                          {` · ${fmtMins(l.durationMinutes)} · ${l.project ?? ""}`}
                        </div>
                      </div>
                    </li>
                  ))}
                </ul>
              ) : (
                <p className="ops-muted">Nothing logged yet today.</p>
              )}
              <p className="ops-small" style={{ marginTop: "0.6rem" }}>
                <a href={timelog.kimaiUrl} target="_blank" rel="noreferrer">Open Kimai</a>
                {" · "}
                Gaps ≥ 30 min become Vikunja tasks at 5:30 PM.
              </p>
            </>
          )}
        </section>

        <section className="ops-card ops-full-width">
          <h2>Open tasks ({tasks.length})</h2>
          <ul className="ops-list">
            {tasks.slice(0, 40).map((t) => (
              <li key={t.id} className="ops-task-item">
                <button className="ops-check" onClick={() => completeTask(t.id)} aria-label="Complete" type="button" />
                <div style={{ flex: 1 }}>
                  <div>{t.title}</div>
                  <div className="ops-small">
                    {t.project_title ?? ""}
                    {t.due_date && !t.due_date.startsWith("0001") ? `${t.project_title ? " · " : ""}Due ${new Date(t.due_date).toLocaleDateString("en-US", { timeZone: calTimeZone, month: "short", day: "numeric" })}` : ""}
                  </div>
                </div>
              </li>
            ))}
          </ul>
        </section>
      </div>

      <footer className="ops-footer">
        Cloudigan IT Solutions · ops.cloudigan.net
      </footer>
    </main>
  );
}
