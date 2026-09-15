"use client";

import { useEffect, useMemo, useState } from "react";

export type TimelineEvent = {
  title: string;
  start: string;
  end: string;
  source: string;
  lifeArea: string;
  calendar?: string | null;
  link?: string | null;
  allDay?: boolean;
  conflicted?: boolean;
  uid?: string;
  kimai?: KimaiSuggestion | null;
};

export type KimaiSuggestion = {
  matched: boolean;
  noProject?: boolean;
  customerId?: number | null;
  customer?: string | null;
  projectId: number;
  project: string;
  activityId?: number | null;
  activity?: string | null;
};

export type RunningTimer = {
  id: number;
  begin: string | null;
  elapsedMinutes?: number | null;
  project?: string | null;
  customer?: string | null;
  activity?: string | null;
  description?: string;
};

type Props = {
  events: TimelineEvent[];
  allDay: TimelineEvent[];
  colors: Record<string, string>;
  timeZone?: string;
  syncedAt?: string | null;
  running?: RunningTimer | null;
  onStartTimer?: (e: TimelineEvent) => void;
  onStopTimer?: () => void;
  timerBusy?: boolean;
};

const LIFE_LABELS: Record<string, string> = {
  personal: "Personal",
  cloudigan: "Cloudigan",
  theocratic: "Theocratic",
  thrive: "Thrive",
  jwpub: "JW Pub",
  other: "Other",
};

function fmtTime(iso: string, timeZone?: string) {
  try {
    return new Date(iso).toLocaleTimeString("en-US", { timeZone, hour: "numeric", minute: "2-digit" });
  } catch {
    return iso;
  }
}

function minutesBetween(a: string, b: string) {
  return Math.max(0, Math.round((new Date(b).getTime() - new Date(a).getTime()) / 60000));
}

function fmtDuration(min: number) {
  if (min < 60) return `${min}m`;
  const h = Math.floor(min / 60);
  const m = min % 60;
  return m ? `${h}h ${m}m` : `${h}h`;
}

function periodOf(iso: string, timeZone?: string) {
  const hour = Number(
    new Date(iso).toLocaleTimeString("en-US", { timeZone, hour: "numeric", hour12: false }).split(":")[0],
  );
  if (hour < 12) return "Morning";
  if (hour < 17) return "Afternoon";
  return "Evening";
}

export function TodayTimeline({ events, allDay, colors, timeZone, syncedAt, running, onStartTimer, onStopTimer, timerBusy }: Props) {
  const [hidden, setHidden] = useState<Set<string>>(new Set());
  const [now, setNow] = useState<number>(() => Date.now());

  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), 60_000);
    return () => clearInterval(t);
  }, []);

  const areaCounts = useMemo(() => {
    const counts: Record<string, number> = {};
    for (const e of [...events, ...allDay]) counts[e.lifeArea] = (counts[e.lifeArea] ?? 0) + 1;
    return counts;
  }, [events, allDay]);

  const areas = Object.keys(areaCounts).sort();

  function toggleArea(area: string) {
    setHidden((prev) => {
      const next = new Set(prev);
      if (next.has(area)) next.delete(area);
      else next.add(area);
      return next;
    });
  }

  const visible = events
    .filter((e) => !hidden.has(e.lifeArea))
    .slice()
    .sort((a, b) => a.start.localeCompare(b.start));
  const visibleAllDay = allDay.filter((e) => !hidden.has(e.lifeArea));

  const nowIso = new Date(now).toISOString();
  const currentIdx = visible.findIndex((e) => e.start <= nowIso && nowIso < e.end);
  const nextIdx = visible.findIndex((e) => e.start > nowIso);
  const nowMarkerBefore = currentIdx === -1 ? nextIdx : -1; // insert "now" line before next upcoming if nothing is live

  if (events.length === 0 && allDay.length === 0) {
    return <p className="ops-muted">Nothing on the calendar today.</p>;
  }

  let lastPeriod = "";

  return (
    <div className="ops-timeline">
      <div className="ops-legend">
        {areas.map((area) => {
          const off = hidden.has(area);
          return (
            <button
              key={area}
              type="button"
              className={`ops-chip ops-chip-toggle${off ? " is-off" : ""}`}
              onClick={() => toggleArea(area)}
              aria-pressed={!off}
              title={off ? `Show ${LIFE_LABELS[area] ?? area}` : `Hide ${LIFE_LABELS[area] ?? area}`}
            >
              <span className="ops-dot" style={{ background: colors[area] ?? colors.other, marginTop: 0 }} />
              {LIFE_LABELS[area] ?? area}
              <span className="ops-small">{areaCounts[area]}</span>
            </button>
          );
        })}
        {syncedAt && (
          <span className="ops-small ops-muted ops-legend-synced">
            synced {fmtTime(syncedAt, timeZone)}
          </span>
        )}
      </div>

      {visibleAllDay.length > 0 && (
        <div className="ops-allday">
          <span className="ops-small ops-muted">All day</span>
          {visibleAllDay.map((e, i) => (
            <span
              key={e.uid ?? i}
              className="ops-allday-pill"
              style={{ borderColor: colors[e.lifeArea] ?? colors.other }}
              title={e.source}
            >
              {e.link ? (
                <a href={e.link} target="_blank" rel="noreferrer">{e.title}</a>
              ) : (
                e.title
              )}
            </span>
          ))}
        </div>
      )}

      {visible.length === 0 ? (
        <p className="ops-muted">No timed events for the selected areas.</p>
      ) : (
        <ol className="ops-tl-list">
          {visible.map((e, i) => {
            const period = periodOf(e.start, timeZone);
            const showPeriod = period !== lastPeriod;
            lastPeriod = period;
            const isPast = e.end <= nowIso;
            const isLive = i === currentIdx;
            const color = colors[e.lifeArea] ?? colors.other;
            const isTracking = Boolean(running && running.description && running.description === e.title);
            const canTrack = Boolean(e.kimai && onStartTimer);
            return (
              <li key={e.uid ?? `${e.start}-${i}`} style={{ listStyle: "none" }}>
                {showPeriod && <div className="ops-tl-period">{period}</div>}
                {nowMarkerBefore === i && (
                  <div className="ops-tl-now">
                    <span>Now · {fmtTime(nowIso, timeZone)}</span>
                  </div>
                )}
                <div className={`ops-tl-row${isPast ? " is-past" : ""}${isLive ? " is-live" : ""}`}>
                  <div className="ops-tl-time">
                    <div>{fmtTime(e.start, timeZone)}</div>
                    <div className="ops-small">{fmtDuration(minutesBetween(e.start, e.end))}</div>
                  </div>
                  <div className="ops-tl-bar" style={{ background: color }} />
                  <div className="ops-tl-body">
                    <div className="ops-tl-title">
                      {e.title}
                      {e.conflicted && (
                        <span className="ops-badge-warn" title="Overlaps another event">overlap</span>
                      )}
                      {isLive && <span className="ops-badge-live">live</span>}
                      {isTracking && <span className="ops-badge-track">⏱ tracking</span>}
                    </div>
                    <div className="ops-small">
                      {fmtTime(e.start, timeZone)} – {fmtTime(e.end, timeZone)} · {e.calendar ?? e.source}
                      {e.kimai && (
                        <>
                          {" · "}
                          <span title={e.kimai.matched ? "Matched from title" : "Default project — edit kimai-map.json to map this client"}>
                            {e.kimai.customer ?? e.kimai.project}
                            {!e.kimai.matched && "?"}
                          </span>
                        </>
                      )}
                      {e.link && (
                        <>
                          {" · "}
                          <a href={e.link} target="_blank" rel="noreferrer">Open</a>
                        </>
                      )}
                    </div>
                  </div>
                  {canTrack && (
                    <div className="ops-tl-actions">
                      {isTracking ? (
                        <button className="ops-btn-secondary ops-btn-xs" type="button" disabled={timerBusy} onClick={() => onStopTimer?.()}>
                          Stop
                        </button>
                      ) : (
                        <button
                          className="ops-btn-secondary ops-btn-xs"
                          type="button"
                          disabled={timerBusy || isPast}
                          title={isPast ? "Event already ended — log it from the Time card" : `Start Kimai timer on ${e.kimai?.project}`}
                          onClick={() => onStartTimer?.(e)}
                        >
                          ⏱ Start
                        </button>
                      )}
                    </div>
                  )}
                </div>
              </li>
            );
          })}
          {nowMarkerBefore === -1 && currentIdx === -1 && visible.length > 0 && visible[visible.length - 1].end <= nowIso && (
            <li style={{ listStyle: "none" }}>
              <div className="ops-tl-now">
                <span>Now · {fmtTime(nowIso, timeZone)} — day&apos;s events done</span>
              </div>
            </li>
          )}
        </ol>
      )}
    </div>
  );
}
