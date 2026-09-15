#!/usr/bin/env node
/**
 * ops-sync — pull ICS feeds (+ Google/Graph later), detect conflicts, export merged calendar.
 * Run on schedule via cron/PM2: node sync.js
 */
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import ical from "node-ical";
import { syncMicrosoftCalendars } from "./microsoft.js";
import { syncGoogleCalendars } from "./google.js";
import { enrichEventsWithKimai } from "./kimai.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DATA_DIR = process.env.OPS_SYNC_DATA ?? path.join(__dirname, "data");
const CONFIG_PATH = process.env.OPS_SYNC_CONFIG ?? path.join(__dirname, "feeds.json");

function loadConfig() {
  if (!fs.existsSync(CONFIG_PATH)) {
    return { feeds: [] };
  }
  return JSON.parse(fs.readFileSync(CONFIG_PATH, "utf8"));
}

function parseIcsEvents(icsData, meta) {
  const parsed = ical.sync.parseICS(icsData);
  const events = [];
  for (const item of Object.values(parsed)) {
    if (!item || item.type !== "VEVENT") continue;
    const start = item.start instanceof Date ? item.start.toISOString() : null;
    const end = item.end instanceof Date ? item.end.toISOString() : start;
    if (!start) continue;
    events.push({
      title: item.summary || "(no title)",
      start,
      end: end ?? start,
      source: meta.name,
      lifeArea: meta.lifeArea ?? "other",
      uid: item.uid || `${meta.name}-${start}-${item.summary}`,
    });
  }
  return events;
}

async function fetchFeed(feed) {
  if (!feed.url) return [];
  const res = await fetch(feed.url, { headers: { "User-Agent": "ops-sync/0.1" } });
  if (!res.ok) throw new Error(`${feed.name}: HTTP ${res.status}`);
  const text = await res.text();
  return parseIcsEvents(text, feed);
}

function eventDurationMs(e) {
  return new Date(e.end).getTime() - new Date(e.start).getTime();
}

function isAllDayish(e) {
  if (e.allDay) return true;
  const ms = eventDurationMs(e);
  // multi-day / overnight blocks flood conflict lists
  return ms >= 12 * 60 * 60 * 1000;
}

/** Collapse invite copies / mirrored calendars (same title + start). Prefer primary-looking sources. */
function dedupeEvents(events) {
  const rank = (e) => {
    const s = (e.source || "").toLowerCase();
    if (s.includes("allen family") || s.includes("(primary)")) return 0;
    if (e.lifeArea === "cloudigan") return 1;
    if (e.lifeArea === "thrive") return 2;
    return 5;
  };
  const byKey = new Map();
  for (const e of events) {
    const key = `${(e.title || "").trim().toLowerCase()}|${e.start.slice(0, 16)}`;
    const prev = byKey.get(key);
    if (!prev || rank(e) < rank(prev)) byKey.set(key, e);
  }
  return [...byKey.values()];
}

function conflictId(a, b) {
  const [x, y] = [a.uid, b.uid].sort();
  return `${x}::${y}`;
}

/**
 * Actionable conflicts: overlapping timed events across different life areas
 * (or different accounts), ignoring all-day blocks and mirror duplicates.
 */
function detectConflicts(events) {
  const timed = events.filter((e) => !isAllDayish(e));
  const sorted = [...timed].sort((a, b) => a.start.localeCompare(b.start));
  const conflicts = [];

  for (let i = 0; i < sorted.length; i++) {
    for (let j = i + 1; j < sorted.length; j++) {
      const a = sorted[i];
      const b = sorted[j];
      if (new Date(b.start) >= new Date(a.end)) break;
      if (!(a.start < b.end && b.start < a.end) || a.uid === b.uid) continue;

      const sameTitle =
        (a.title || "").trim().toLowerCase() === (b.title || "").trim().toLowerCase();
      if (sameTitle) continue; // mirror / invite copy

      const accountA = (a.source || "").split(" / ")[0];
      const accountB = (b.source || "").split(" / ")[0];
      const crossLife = (a.lifeArea || "other") !== (b.lifeArea || "other");
      const crossAccount = accountA !== accountB;
      // Same life area on same account: still flag if both are timed meetings (real double-book)
      const sameCalNoise =
        !crossLife &&
        !crossAccount &&
        (a.source || "") === (b.source || "");

      // Skip tiny overlaps under 5 minutes
      const overlapMs =
        Math.min(new Date(a.end).getTime(), new Date(b.end).getTime()) -
        Math.max(new Date(a.start).getTime(), new Date(b.start).getTime());
      if (overlapMs < 5 * 60 * 1000) continue;

      // high = different life areas or different accounts (real double-booking risk)
      // low  = same calendar/account overlap (often intentional: chores, reminders, family blocks)
      const severity = crossLife || crossAccount ? "high" : "low";

      conflicts.push({
        id: conflictId(a, b),
        a: a.title,
        b: b.title,
        at: a.start < b.start ? b.start : a.start,
        overlapMinutes: Math.round(overlapMs / 60000),
        sources: [a.source, b.source],
        calendars: [a.calendar ?? null, b.calendar ?? null],
        links: [a.link ?? null, b.link ?? null],
        lifeAreas: [a.lifeArea, b.lifeArea],
        uids: [a.uid, b.uid],
        starts: [a.start, b.start],
        ends: [a.end, b.end],
        crossLife,
        crossAccount,
        sameCalendar: sameCalNoise,
        severity,
      });
    }
  }

  // High severity first, then chronological
  conflicts.sort((x, y) => {
    const score = (c) => (c.severity === "high" ? 0 : 1);
    return score(x) - score(y) || x.at.localeCompare(y.at);
  });
  return conflicts;
}

function loadDismissed(dataDir) {
  const p = path.join(dataDir, "dismissed-conflicts.json");
  if (!fs.existsSync(p)) return { ids: {} };
  return JSON.parse(fs.readFileSync(p, "utf8"));
}

function filterDismissed(conflicts, dataDir) {
  const dismissed = loadDismissed(dataDir).ids || {};
  const now = Date.now();
  return conflicts.filter((c) => {
    const until = dismissed[c.id];
    if (!until) return true;
    return now > new Date(until).getTime();
  });
}

function toIcs(events) {
  const lines = [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//Cloudigan//Ops Sync//EN",
    "CALSCALE:GREGORIAN",
    "METHOD:PUBLISH",
    "X-WR-CALNAME:Ops Hub Merged",
  ];
  for (const e of events) {
    const fmt = (iso) => iso.replace(/[-:]/g, "").replace(/\.\d{3}/, "").replace("Z", "Z");
    lines.push("BEGIN:VEVENT");
    lines.push(`UID:${e.uid}@ops.cloudigan.net`);
    lines.push(`DTSTART:${fmt(e.start)}`);
    lines.push(`DTEND:${fmt(e.end)}`);
    lines.push(`SUMMARY:[${e.lifeArea}] ${e.title}`);
    lines.push(`DESCRIPTION:Source: ${e.source}`);
    lines.push("END:VEVENT");
  }
  lines.push("END:VCALENDAR");
  return lines.join("\r\n") + "\r\n";
}

async function runSync() {
  fs.mkdirSync(DATA_DIR, { recursive: true });
  const config = loadConfig();
  const allEvents = [];

  for (const feed of config.feeds ?? []) {
    if (!feed.enabled) continue;
    try {
      const events = await fetchFeed(feed);
      allEvents.push(...events);
      console.log(`✓ ${feed.name}: ${events.length} events`);
    } catch (err) {
      console.error(`✗ ${feed.name}:`, err.message);
    }
  }

  if (config.microsoft?.enabled) {
    try {
      const msEvents = await syncMicrosoftCalendars(DATA_DIR, config.microsoft);
      allEvents.push(...msEvents);
    } catch (err) {
      console.error("✗ Microsoft Graph:", err.message);
    }
  }

  if (config.google?.enabled !== false) {
    try {
      const gEvents = await syncGoogleCalendars(DATA_DIR, config.google ?? {});
      allEvents.push(...gEvents);
    } catch (err) {
      console.error("✗ Google Calendar:", err.message);
    }
  }

  const deduped = dedupeEvents(allEvents);
  const allConflicts = detectConflicts(deduped);
  const conflicts = filterDismissed(allConflicts, DATA_DIR);
  const TZ = "America/New_York";
  const today = new Date().toLocaleDateString("en-CA", { timeZone: TZ }); // YYYY-MM-DD
  const localDay = (iso) => new Date(iso).toLocaleDateString("en-CA", { timeZone: TZ });

  // All-day events span [start, end) — include if today falls inside the range
  const coversToday = (e) => {
    const s = localDay(e.start);
    const endMs = new Date(e.end).getTime() - 1; // end is exclusive
    const en = localDay(new Date(Math.max(endMs, new Date(e.start).getTime())).toISOString());
    return s <= today && today <= en;
  };

  const todayTimed = deduped
    .filter((e) => !isAllDayish(e) && localDay(e.start) === today)
    .sort((a, b) => a.start.localeCompare(b.start));
  const todayAllDay = deduped
    .filter((e) => isAllDayish(e) && coversToday(e))
    .sort((a, b) => a.title.localeCompare(b.title));
  const todayConflicts = conflicts.filter((c) => localDay(c.at) === today);

  // Mark events that participate in an active conflict (for UI badges)
  const conflictedUids = new Set(conflicts.flatMap((c) => c.uids));
  for (const e of deduped) e.conflicted = conflictedUids.has(e.uid);

  // Attach Kimai project suggestions to work events (one-click timers, gap detection)
  await enrichEventsWithKimai(deduped);

  const payload = {
    syncedAt: new Date().toISOString(),
    timeZone: TZ,
    events: deduped.sort((a, b) => a.start.localeCompare(b.start)),
    conflicts,
    today: {
      date: today,
      events: todayTimed,
      allDay: todayAllDay,
      conflicts: todayConflicts,
      conflictsHigh: todayConflicts.filter((c) => c.severity === "high"),
      conflictsLow: todayConflicts.filter((c) => c.severity !== "high"),
    },
    stats: {
      rawEvents: allEvents.length,
      dedupedEvents: deduped.length,
      conflictsTotal: allConflicts.length,
      conflictsActive: conflicts.length,
      conflictsHigh: conflicts.filter((c) => c.severity === "high").length,
      conflictsLow: conflicts.filter((c) => c.severity !== "high").length,
    },
  };

  fs.writeFileSync(path.join(DATA_DIR, "calendar.json"), JSON.stringify(payload, null, 2));
  fs.writeFileSync(path.join(DATA_DIR, "merged.ics"), toIcs(allEvents));
  console.log(`Synced ${allEvents.length} events, ${conflicts.length} conflicts`);
  return payload;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  runSync().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}

export { runSync, loadConfig, detectConflicts, dedupeEvents, filterDismissed, loadDismissed };
