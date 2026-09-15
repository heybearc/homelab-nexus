/**
 * Google Calendar sync (OAuth — per-account refresh tokens).
 */
import fs from "fs";
import path from "path";

function accountsPath(dataDir) {
  return path.join(dataDir, "google-accounts.json");
}

export function loadGoogleAccounts(dataDir) {
  const p = accountsPath(dataDir);
  if (!fs.existsSync(p)) return [];
  const raw = JSON.parse(fs.readFileSync(p, "utf8"));
  return raw.accounts ?? [];
}

async function refreshAccessToken(account, clientId, clientSecret) {
  const body = new URLSearchParams({
    client_id: clientId,
    client_secret: clientSecret,
    refresh_token: account.refreshToken,
    grant_type: "refresh_token",
  });
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  const data = await res.json();
  if (!res.ok) {
    throw new Error(
      `${account.email}: token refresh failed — ${data.error_description ?? data.error ?? res.status}`,
    );
  }
  return data.access_token;
}

function eventIso(dt) {
  if (!dt) return null;
  if (dt.dateTime) return new Date(dt.dateTime).toISOString();
  if (dt.date) return new Date(`${dt.date}T00:00:00Z`).toISOString();
  return null;
}

async function fetchCalendarEvents(accessToken, account, rangeStart, rangeEnd) {
  const headers = { Authorization: `Bearer ${accessToken}` };
  const listRes = await fetch(
    "https://www.googleapis.com/calendar/v3/users/me/calendarList?minAccessRole=reader&maxResults=250",
    { headers },
  );
  const listData = await listRes.json();
  if (!listRes.ok) {
    throw new Error(`${account.email}: calendarList — ${listData.error?.message ?? listRes.status}`);
  }

  const events = [];
  for (const cal of listData.items ?? []) {
    if (cal.deleted || cal.hidden) continue;
    const params = new URLSearchParams({
      timeMin: rangeStart,
      timeMax: rangeEnd,
      singleEvents: "true",
      orderBy: "startTime",
      maxResults: "250",
    });
    const calId = encodeURIComponent(cal.id);
    const evRes = await fetch(
      `https://www.googleapis.com/calendar/v3/calendars/${calId}/events?${params}`,
      { headers },
    );
    const evData = await evRes.json();
    if (!evRes.ok) {
      console.warn(`${account.email}/${cal.summary}: events — ${evData.error?.message ?? evRes.status}`);
      continue;
    }

    for (const item of evData.items ?? []) {
      if (item.status === "cancelled") continue;
      const start = eventIso(item.start);
      if (!start) continue;
      const end = eventIso(item.end) ?? start;
      events.push({
        title: item.summary || "(no title)",
        start,
        end,
        allDay: Boolean(item.start?.date && !item.start?.dateTime),
        source: `${account.email} / ${cal.summary}`,
        calendar: cal.summaryOverride || cal.summary || cal.id,
        account: account.email,
        provider: "google",
        link: item.htmlLink || null,
        lifeArea: account.lifeArea ?? "personal",
        uid: `gcal-${account.email}-${item.id}`,
      });
    }
  }

  return events;
}

export async function syncGoogleCalendars(dataDir, config) {
  const clientId = config.clientId || process.env.GOOGLE_CLIENT_ID;
  const clientSecret = config.clientSecret || process.env.GOOGLE_CLIENT_SECRET;
  if (!clientId || !clientSecret) return [];

  const accounts = loadGoogleAccounts(dataDir);
  if (!accounts.length) return [];

  const now = new Date();
  const rangeStart = new Date(now.getTime() - 7 * 86400000).toISOString();
  const rangeEnd = new Date(now.getTime() + 90 * 86400000).toISOString();

  const allEvents = [];
  for (const account of accounts) {
    try {
      const accessToken = await refreshAccessToken(account, clientId, clientSecret);
      const events = await fetchCalendarEvents(accessToken, account, rangeStart, rangeEnd);
      allEvents.push(...events);
      console.log(`✓ Google ${account.email}: ${events.length} events`);
    } catch (err) {
      console.error(`✗ Google ${account.email}:`, err.message);
    }
  }
  return allEvents;
}
