/**
 * Microsoft Graph calendar sync (delegated OAuth — per-account refresh tokens).
 */
import fs from "fs";
import path from "path";

const SCOPES = "openid offline_access User.Read Calendars.ReadWrite";

function accountsPath(dataDir) {
  return path.join(dataDir, "microsoft-accounts.json");
}

export function loadMicrosoftAccounts(dataDir) {
  const p = accountsPath(dataDir);
  if (!fs.existsSync(p)) return [];
  const raw = JSON.parse(fs.readFileSync(p, "utf8"));
  return raw.accounts ?? [];
}

async function refreshAccessToken(account, clientId, clientSecret) {
  const url = `https://login.microsoftonline.com/${account.tenantId}/oauth2/v2.0/token`;
  const body = new URLSearchParams({
    client_id: clientId,
    client_secret: clientSecret,
    refresh_token: account.refreshToken,
    grant_type: "refresh_token",
    scope: SCOPES,
  });
  const res = await fetch(url, {
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

function graphIso(dt) {
  if (!dt?.dateTime) return null;
  const s = dt.dateTime;
  if (s.endsWith("Z") || /[+-]\d{2}:\d{2}$/.test(s)) return new Date(s).toISOString();
  return new Date(`${s}Z`).toISOString();
}

async function fetchCalendarEvents(accessToken, account, rangeStart, rangeEnd) {
  const headers = {
    Authorization: `Bearer ${accessToken}`,
    Prefer: "outlook.timezone=\"UTC\"",
  };

  const calRes = await fetch("https://graph.microsoft.com/v1.0/me/calendars", { headers });
  const calData = await calRes.json();
  if (!calRes.ok) {
    throw new Error(`${account.email}: calendars — ${calData.error?.message ?? calRes.status}`);
  }

  const events = [];
  const calendars = calData.value ?? [];

  for (const cal of calendars) {
    const params = new URLSearchParams({
      startDateTime: rangeStart,
      endDateTime: rangeEnd,
      $top: "250",
      $select: "id,subject,start,end,isCancelled,isAllDay,webLink",
    });
    const viewRes = await fetch(
      `https://graph.microsoft.com/v1.0/me/calendars/${cal.id}/calendarView?${params}`,
      { headers },
    );
    const viewData = await viewRes.json();
    if (!viewRes.ok) {
      console.warn(`${account.email}/${cal.name}: calendarView — ${viewData.error?.message ?? viewRes.status}`);
      continue;
    }

    for (const item of viewData.value ?? []) {
      if (item.isCancelled) continue;
      const start = graphIso(item.start);
      if (!start) continue;
      const end = graphIso(item.end) ?? start;
      events.push({
        title: item.subject || "(no title)",
        start,
        end,
        allDay: Boolean(item.isAllDay),
        source: `${account.email} / ${cal.name}`,
        calendar: cal.name,
        account: account.email,
        provider: "microsoft",
        link: item.webLink || null,
        lifeArea: account.lifeArea ?? "other",
        uid: `m365-${account.email}-${item.id}`,
      });
    }
  }

  return events;
}

export async function syncMicrosoftCalendars(dataDir, config) {
  const clientId = config.clientId ?? process.env.M365_CLIENT_ID;
  const clientSecret = config.clientSecret ?? process.env.M365_CLIENT_SECRET;
  if (!clientId || !clientSecret) return [];

  const accounts = loadMicrosoftAccounts(dataDir);
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
      console.log(`✓ Microsoft ${account.email}: ${events.length} events`);
    } catch (err) {
      console.error(`✗ Microsoft ${account.email}:`, err.message);
    }
  }
  return allEvents;
}
