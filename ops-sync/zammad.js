// Zammad ticket search + close (Token token= auth).

function base() {
  let u = (process.env.ZAMMAD_API_URL || "https://support.cloudigan.net").replace(/\/+$/, "");
  if (!u.endsWith("/api/v1")) u += "/api/v1";
  return u;
}

export function isZammadConfigured() {
  return Boolean(process.env.ZAMMAD_API_TOKEN);
}

function authHeader() {
  return `Token token=${process.env.ZAMMAD_API_TOKEN}`;
}

async function zm(pathname, init = {}) {
  const method = (init.method || "GET").toUpperCase();
  const res = await fetch(`${base()}${pathname}`, {
    ...init,
    headers: {
      Authorization: authHeader(),
      Accept: "application/json",
      ...(method === "GET" ? {} : { "Content-Type": "application/json" }),
      ...(init.headers ?? {}),
    },
  });
  const text = await res.text();
  const data = text ? JSON.parse(text) : null;
  if (!res.ok) throw new Error(`Zammad ${pathname}: ${res.status} ${data?.error ?? text}`);
  return data;
}

/** Normalize search: Zammad sometimes returns an array, sometimes {tickets, tickets_count}. */
export function asTicketList(data) {
  if (Array.isArray(data)) return data;
  if (Array.isArray(data?.tickets)) return data.tickets;
  return [];
}

export async function searchTickets(query, { limit = 50, page = 1 } = {}) {
  if (!isZammadConfigured()) return [];
  const q = new URLSearchParams({ query, limit: String(limit), page: String(page) });
  return asTicketList(await zm(`/tickets/search?${q}`));
}

export async function searchAllTickets(query, maxPages = 8) {
  const all = [];
  for (let page = 1; page <= maxPages; page++) {
    const rows = await searchTickets(query, { limit: 50, page });
    all.push(...rows);
    if (rows.length < 50) break;
  }
  const seen = new Set();
  return all.filter((t) => !seen.has(t.id) && seen.add(t.id));
}

export async function closeTicket(id, body) {
  return zm(`/tickets/${id}`, {
    method: "PUT",
    body: JSON.stringify({
      state_id: 4,
      article: {
        body,
        type: "note",
        internal: true,
      },
    }),
  });
}

export function ticketUrl(ticket) {
  const web = (process.env.ZAMMAD_WEB_URL || "https://support.cloudigan.net").replace(/\/+$/, "");
  return `${web}/#ticket/zoom/${ticket.id}`;
}
