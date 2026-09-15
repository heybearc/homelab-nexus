import fs from "fs";
import path from "path";
import { getOpsHubBaseUrl, triggerOpsSync } from "./microsoft";

const SCOPES = [
  "openid",
  "email",
  "profile",
  "https://www.googleapis.com/auth/calendar.readonly",
  "https://www.googleapis.com/auth/calendar.events.owned",
].join(" ");

export function getGoogleConfig() {
  const clientId = process.env.GOOGLE_CLIENT_ID ?? "";
  const clientSecret = process.env.GOOGLE_CLIENT_SECRET ?? "";
  const redirectUri =
    process.env.GOOGLE_CALENDAR_REDIRECT_URI ??
    `${getOpsHubBaseUrl()}/api/auth/google/callback`;
  return { clientId, clientSecret, redirectUri };
}

export function isGoogleConfigured() {
  const { clientId, clientSecret } = getGoogleConfig();
  return Boolean(clientId && clientSecret);
}

export function getGoogleAuthorizeUrl(state: string) {
  const { clientId, redirectUri } = getGoogleConfig();
  const params = new URLSearchParams({
    client_id: clientId,
    redirect_uri: redirectUri,
    response_type: "code",
    scope: SCOPES,
    access_type: "offline",
    prompt: "consent select_account",
    include_granted_scopes: "true",
    state,
  });
  return `https://accounts.google.com/o/oauth2/v2/auth?${params}`;
}

export async function exchangeGoogleCode(code: string) {
  const { clientId, clientSecret, redirectUri } = getGoogleConfig();
  const body = new URLSearchParams({
    client_id: clientId,
    client_secret: clientSecret,
    code,
    redirect_uri: redirectUri,
    grant_type: "authorization_code",
  });
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  const data = await res.json();
  if (!res.ok) {
    throw new Error(data.error_description ?? data.error ?? `Token exchange failed (${res.status})`);
  }
  return data as {
    access_token: string;
    refresh_token?: string;
    expires_in: number;
    id_token?: string;
  };
}

export async function fetchGoogleProfile(accessToken: string) {
  const res = await fetch("https://www.googleapis.com/oauth2/v2/userinfo", {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error?.message ?? `Google userinfo failed (${res.status})`);
  return data as { email: string; id: string; name?: string };
}

export type GoogleAccount = {
  email: string;
  lifeArea: "personal";
  refreshToken: string;
  connectedAt: string;
};

export function getGoogleAccountsPath() {
  const dataDir = process.env.OPS_SYNC_DATA ?? path.join(process.cwd(), "../ops-sync/data");
  return path.join(dataDir, "google-accounts.json");
}

export function loadGoogleAccounts(): GoogleAccount[] {
  const accountsPath = getGoogleAccountsPath();
  if (!fs.existsSync(accountsPath)) return [];
  const raw = JSON.parse(fs.readFileSync(accountsPath, "utf8"));
  return raw.accounts ?? [];
}

export function saveGoogleAccount(account: GoogleAccount) {
  const accountsPath = getGoogleAccountsPath();
  fs.mkdirSync(path.dirname(accountsPath), { recursive: true });
  const existing = loadGoogleAccounts().find((a) => a.email === account.email);
  const accounts = loadGoogleAccounts().filter((a) => a.email !== account.email);
  // Google only returns refresh_token on first consent — keep previous if missing
  accounts.push({
    ...account,
    refreshToken: account.refreshToken || existing?.refreshToken || "",
  });
  if (!accounts[accounts.length - 1].refreshToken) {
    throw new Error("No refresh token — revoke Ops Hub access in Google Account → Security → Third-party access, then connect again");
  }
  fs.writeFileSync(accountsPath, JSON.stringify({ accounts }, null, 2));
}

export function removeGoogleAccount(email: string) {
  const accountsPath = getGoogleAccountsPath();
  if (!fs.existsSync(accountsPath)) return;
  const accounts = loadGoogleAccounts().filter((a) => a.email !== email);
  fs.writeFileSync(accountsPath, JSON.stringify({ accounts }, null, 2));
}

async function refreshGoogleAccessToken(refreshToken: string) {
  const { clientId, clientSecret } = getGoogleConfig();
  const body = new URLSearchParams({
    client_id: clientId,
    client_secret: clientSecret,
    refresh_token: refreshToken,
    grant_type: "refresh_token",
  });
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  const data = await res.json();
  if (!res.ok) {
    throw new Error(data.error_description ?? data.error ?? `Google token refresh failed (${res.status})`);
  }
  return data.access_token as string;
}

export type GoogleCalendarInfo = {
  id: string;
  summary: string;
  primary?: boolean;
  accessRole?: string;
  backgroundColor?: string;
  accountEmail: string;
};

export async function listGoogleCalendars(email?: string): Promise<GoogleCalendarInfo[]> {
  const accounts = loadGoogleAccounts();
  const selected = email ? accounts.filter((a) => a.email === email) : accounts;
  if (!selected.length) return [];

  const all: GoogleCalendarInfo[] = [];
  for (const account of selected) {
    const accessToken = await refreshGoogleAccessToken(account.refreshToken);
    const res = await fetch(
      "https://www.googleapis.com/calendar/v3/users/me/calendarList?minAccessRole=reader&maxResults=250",
      { headers: { Authorization: `Bearer ${accessToken}` } },
    );
    const data = await res.json();
    if (!res.ok) {
      throw new Error(data.error?.message ?? `calendarList failed for ${account.email}`);
    }
    for (const cal of data.items ?? []) {
      if (cal.deleted) continue;
      all.push({
        id: cal.id,
        summary: cal.summaryOverride || cal.summary || cal.id,
        primary: Boolean(cal.primary),
        accessRole: cal.accessRole,
        backgroundColor: cal.backgroundColor,
        accountEmail: account.email,
      });
    }
  }

  // Primary first, then writable, then name
  const roleRank = (r?: string) => (r === "owner" ? 0 : r === "writer" ? 1 : 2);
  return all.sort((a, b) => {
    if (a.accountEmail !== b.accountEmail) return a.accountEmail.localeCompare(b.accountEmail);
    if (a.primary !== b.primary) return a.primary ? -1 : 1;
    const rr = roleRank(a.accessRole) - roleRank(b.accessRole);
    if (rr !== 0) return rr;
    return a.summary.localeCompare(b.summary);
  });
}

export type CreateGoogleEventInput = {
  title: string;
  description?: string;
  start?: string; // ISO
  durationMinutes?: number;
  email?: string; // which connected account; defaults to first
  calendarId?: string; // default primary
  attendees?: string[]; // invitee emails
  sendInvites?: boolean; // email invites (default true when attendees present)
  timeZone?: string; // IANA tz for display; default America/New_York
};

function parseAttendeeEmails(raw?: string[] | string): string[] {
  const parts = Array.isArray(raw) ? raw : String(raw ?? "").split(/[,;\n]+/);
  const emails = parts
    .map((s) => s.trim().toLowerCase())
    .filter((s) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s));
  return [...new Set(emails)];
}

export async function createGoogleCalendarEvent(input: CreateGoogleEventInput) {
  const accounts = loadGoogleAccounts();
  if (!accounts.length) throw new Error("No Google account connected — use Connect Google first");
  const account = input.email
    ? accounts.find((a) => a.email === input.email)
    : accounts[0];
  if (!account) throw new Error(`Google account not connected: ${input.email}`);

  const accessToken = await refreshGoogleAccessToken(account.refreshToken);
  const start = input.start ? new Date(input.start) : new Date();
  if (Number.isNaN(start.getTime())) throw new Error("Invalid start time");
  const end = new Date(start.getTime() + (input.durationMinutes ?? 60) * 60_000);
  const calendarId = encodeURIComponent(input.calendarId ?? "primary");
  const attendees = parseAttendeeEmails(input.attendees);
  const timeZone = input.timeZone || "America/New_York";
  const sendUpdates =
    attendees.length > 0 && input.sendInvites !== false ? "all" : "none";

  const params = new URLSearchParams({ sendUpdates: String(sendUpdates) });
  const res = await fetch(
    `https://www.googleapis.com/calendar/v3/calendars/${calendarId}/events?${params}`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        summary: input.title,
        description: input.description || undefined,
        start: { dateTime: start.toISOString(), timeZone },
        end: { dateTime: end.toISOString(), timeZone },
        attendees: attendees.length ? attendees.map((email) => ({ email })) : undefined,
      }),
    },
  );
  const data = await res.json();
  if (!res.ok) {
    throw new Error(data.error?.message ?? `Google create event failed (${res.status})`);
  }

  await triggerOpsSync();
  return {
    id: data.id as string,
    htmlLink: data.htmlLink as string | undefined,
    account: account.email,
    calendarId: input.calendarId ?? "primary",
    attendees,
    start: start.toISOString(),
    end: end.toISOString(),
  };
}

export { triggerOpsSync };
