import fs from "fs";
import path from "path";

const SCOPES = "openid profile offline_access User.Read Calendars.ReadWrite";

export const LIFE_AREAS = [
  { id: "thrive", label: "Thrive (work)" },
  { id: "cloudigan", label: "Cloudigan" },
  { id: "theocratic", label: "Bethel / theocratic" },
  { id: "jwpub", label: "JW Pub" },
  { id: "personal", label: "Personal Microsoft" },
] as const;

export type LifeAreaId = (typeof LIFE_AREAS)[number]["id"];

export function getOpsHubBaseUrl() {
  return (process.env.OPS_HUB_URL ?? "https://ops.cloudigan.net").replace(/\/$/, "");
}

export function getMicrosoftConfig() {
  const clientId = process.env.M365_CLIENT_ID ?? "";
  const clientSecret = process.env.M365_CLIENT_SECRET ?? "";
  const redirectUri =
    process.env.M365_CALENDAR_REDIRECT_URI ??
    `${process.env.OPS_HUB_URL ?? "https://ops.cloudigan.net"}/api/auth/microsoft/callback`;
  return { clientId, clientSecret, redirectUri };
}

export function isMicrosoftConfigured() {
  const { clientId, clientSecret } = getMicrosoftConfig();
  return Boolean(clientId && clientSecret);
}

export function getAuthorizeUrl(state: string) {
  const { clientId, redirectUri } = getMicrosoftConfig();
  const params = new URLSearchParams({
    client_id: clientId,
    response_type: "code",
    redirect_uri: redirectUri,
    response_mode: "query",
    scope: SCOPES,
    state,
    prompt: "select_account",
  });
  return `https://login.microsoftonline.com/organizations/oauth2/v2.0/authorize?${params}`;
}

export async function exchangeCodeForTokens(code: string) {
  const { clientId, clientSecret, redirectUri } = getMicrosoftConfig();
  const body = new URLSearchParams({
    client_id: clientId,
    client_secret: clientSecret,
    code,
    redirect_uri: redirectUri,
    grant_type: "authorization_code",
    scope: SCOPES,
  });
  const res = await fetch("https://login.microsoftonline.com/organizations/oauth2/v2.0/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error_description ?? data.error ?? `Token exchange failed (${res.status})`);
  return data as {
    access_token: string;
    refresh_token?: string;
    expires_in: number;
    id_token?: string;
  };
}

export async function fetchMicrosoftProfile(accessToken: string) {
  const res = await fetch("https://graph.microsoft.com/v1.0/me", {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error?.message ?? `Graph /me failed (${res.status})`);
  return data as { mail?: string; userPrincipalName: string; id: string };
}

export function decodeIdTokenTenant(idToken: string): string | null {
  try {
    const payload = JSON.parse(Buffer.from(idToken.split(".")[1], "base64url").toString());
    return payload.tid ?? null;
  } catch {
    return null;
  }
}

export function getAccountsPath() {
  const dataDir = process.env.OPS_SYNC_DATA ?? path.join(process.cwd(), "../ops-sync/data");
  return path.join(dataDir, "microsoft-accounts.json");
}

export type MicrosoftAccount = {
  email: string;
  tenantId: string;
  lifeArea: LifeAreaId;
  refreshToken: string;
  connectedAt: string;
};

export function loadMicrosoftAccounts(): MicrosoftAccount[] {
  const accountsPath = getAccountsPath();
  if (!fs.existsSync(accountsPath)) return [];
  const raw = JSON.parse(fs.readFileSync(accountsPath, "utf8"));
  return raw.accounts ?? [];
}

export function saveMicrosoftAccount(account: MicrosoftAccount) {
  const accountsPath = getAccountsPath();
  fs.mkdirSync(path.dirname(accountsPath), { recursive: true });
  const accounts = loadMicrosoftAccounts().filter((a) => a.email !== account.email);
  accounts.push(account);
  fs.writeFileSync(accountsPath, JSON.stringify({ accounts }, null, 2));
}

export function removeMicrosoftAccount(email: string) {
  const accountsPath = getAccountsPath();
  if (!fs.existsSync(accountsPath)) return;
  const accounts = loadMicrosoftAccounts().filter((a) => a.email !== email);
  fs.writeFileSync(accountsPath, JSON.stringify({ accounts }, null, 2));
}

async function refreshMicrosoftAccessToken(account: MicrosoftAccount) {
  const { clientId, clientSecret } = getMicrosoftConfig();
  const body = new URLSearchParams({
    client_id: clientId,
    client_secret: clientSecret,
    refresh_token: account.refreshToken,
    grant_type: "refresh_token",
    scope: SCOPES,
  });
  const res = await fetch(
    `https://login.microsoftonline.com/${account.tenantId}/oauth2/v2.0/token`,
    {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body,
    },
  );
  const data = await res.json();
  if (!res.ok) {
    throw new Error(data.error_description ?? data.error ?? `Microsoft token refresh failed (${res.status})`);
  }
  // Persist rotated refresh token when Microsoft issues a new one
  if (data.refresh_token && data.refresh_token !== account.refreshToken) {
    saveMicrosoftAccount({ ...account, refreshToken: data.refresh_token });
  }
  return data.access_token as string;
}

export type CreateMicrosoftEventInput = {
  title: string;
  description?: string;
  start?: string;
  durationMinutes?: number;
  email?: string;
  lifeArea?: LifeAreaId;
  attendees?: string[];
  timeZone?: string;
};

function parseAttendeeEmails(raw?: string[] | string): string[] {
  const parts = Array.isArray(raw) ? raw : String(raw ?? "").split(/[,;\n]+/);
  const emails = parts
    .map((s) => s.trim().toLowerCase())
    .filter((s) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s));
  return [...new Set(emails)];
}

export async function createMicrosoftCalendarEvent(input: CreateMicrosoftEventInput) {
  const accounts = loadMicrosoftAccounts();
  if (!accounts.length) {
    throw new Error("No Microsoft account connected — use Connect Cloudigan first");
  }

  let account = input.email ? accounts.find((a) => a.email === input.email) : undefined;
  if (!account && input.lifeArea) {
    account = accounts.find((a) => a.lifeArea === input.lifeArea);
  }
  if (!account) account = accounts.find((a) => a.lifeArea === "cloudigan") ?? accounts[0];
  if (!account) throw new Error("No matching Microsoft account");

  const accessToken = await refreshMicrosoftAccessToken(account);
  const start = input.start ? new Date(input.start) : new Date();
  if (Number.isNaN(start.getTime())) throw new Error("Invalid start time");
  const end = new Date(start.getTime() + (input.durationMinutes ?? 60) * 60_000);
  const timeZone = input.timeZone || "America/New_York";
  const attendees = parseAttendeeEmails(input.attendees);

  // Format in the event timezone so Graph displays the intended wall clock
  const fmt = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
  });
  const toGraphLocal = (d: Date) => {
    const parts = Object.fromEntries(fmt.formatToParts(d).map((p) => [p.type, p.value]));
    return `${parts.year}-${parts.month}-${parts.day}T${parts.hour}:${parts.minute}:${parts.second}`;
  };

  const res = await fetch("https://graph.microsoft.com/v1.0/me/events", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      subject: input.title,
      body: input.description
        ? { contentType: "text", content: input.description }
        : undefined,
      start: { dateTime: toGraphLocal(start), timeZone },
      end: { dateTime: toGraphLocal(end), timeZone },
      attendees: attendees.length
        ? attendees.map((address) => ({
            emailAddress: { address },
            type: "required",
          }))
        : undefined,
    }),
  });
  const data = await res.json();
  if (!res.ok) {
    const msg = data.error?.message ?? `Microsoft create event failed (${res.status})`;
    if (String(msg).toLowerCase().includes("access") || res.status === 403) {
      throw new Error(
        `${msg} — reconnect ${account.email} in Ops Hub to grant Calendars.ReadWrite`,
      );
    }
    throw new Error(msg);
  }

  await triggerOpsSync();
  return {
    id: data.id as string,
    webLink: data.webLink as string | undefined,
    account: account.email,
    lifeArea: account.lifeArea,
    attendees,
    start: start.toISOString(),
    end: end.toISOString(),
  };
}

export async function triggerOpsSync() {
  const syncUrl = process.env.OPS_SYNC_URL ?? "http://127.0.0.1:3002";
  try {
    await fetch(`${syncUrl}/sync`, { method: "POST" });
  } catch {
    // sync runs on interval; non-fatal
  }
}
