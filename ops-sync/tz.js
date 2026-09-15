// Small timezone helpers (no deps). All "local" means the configured ops timezone.

export const TZ = process.env.OPS_TIMEZONE || "America/New_York";

/** YYYY-MM-DD for an instant in the ops timezone */
export function localDay(dateOrIso, tz = TZ) {
  return new Date(dateOrIso).toLocaleDateString("en-CA", { timeZone: tz });
}

/** Offset in minutes (local - UTC) for the tz at the given instant */
function tzOffsetMinutes(utcDate, tz) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: tz,
    hourCycle: "h23",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  }).formatToParts(utcDate);
  const get = (t) => Number(parts.find((p) => p.type === t)?.value);
  const asUtc = Date.UTC(get("year"), get("month") - 1, get("day"), get("hour"), get("minute"), get("second"));
  return Math.round((asUtc - utcDate.getTime()) / 60000);
}

/** Convert a wall-clock time in tz to a UTC Date. time = "HH:MM" or "HH:MM:SS" */
export function localToUtc(day, time = "00:00:00", tz = TZ) {
  const [h, m, s = "0"] = time.split(":");
  const naive = Date.UTC(...day.split("-").map(Number).map((v, i) => (i === 1 ? v - 1 : v)), Number(h), Number(m), Number(s));
  // Two-pass correction handles DST edges well enough for scheduling purposes
  let guess = new Date(naive - tzOffsetMinutes(new Date(naive), tz) * 60000);
  guess = new Date(naive - tzOffsetMinutes(guess, tz) * 60000);
  return guess;
}

/** Add days to a YYYY-MM-DD string */
export function addDays(day, n) {
  const d = new Date(`${day}T12:00:00Z`);
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}

export function todayLocal(tz = TZ) {
  return localDay(new Date(), tz);
}

/** Resolve "today" | "yesterday" | "tomorrow" | YYYY-MM-DD */
export function resolveDay(input, tz = TZ) {
  const t = todayLocal(tz);
  if (!input || input === "today") return t;
  if (input === "yesterday") return addDays(t, -1);
  if (input === "tomorrow") return addDays(t, 1);
  if (/^\d{4}-\d{2}-\d{2}$/.test(input)) return input;
  throw new Error(`Bad date: ${input}`);
}

/** Monday of the week containing `day` */
export function weekStart(day) {
  const d = new Date(`${day}T12:00:00Z`);
  const dow = (d.getUTCDay() + 6) % 7; // Mon=0
  return addDays(day, -dow);
}

export function fmtTime(iso, tz = TZ) {
  try {
    return new Date(iso).toLocaleTimeString("en-US", { timeZone: tz, hour: "numeric", minute: "2-digit" });
  } catch {
    return String(iso);
  }
}

export function fmtDate(day, opts = { weekday: "short", month: "short", day: "numeric" }, tz = TZ) {
  return localToUtc(day, "12:00", tz).toLocaleDateString("en-US", { timeZone: tz, ...opts });
}

export function fmtHours(minutes) {
  const m = Math.max(0, Math.round(minutes));
  if (m < 60) return `${m}m`;
  const h = Math.floor(m / 60);
  const r = m % 60;
  return r ? `${h}h ${r}m` : `${h}h`;
}

/** Kimai wants naive local "YYYY-MM-DDTHH:MM:SS" in the user's timezone */
export function toKimaiLocal(dateOrIso, tz = TZ) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: tz,
    hourCycle: "h23",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  }).formatToParts(new Date(dateOrIso));
  const g = (t) => parts.find((p) => p.type === t)?.value;
  return `${g("year")}-${g("month")}-${g("day")}T${g("hour")}:${g("minute")}:${g("second")}`;
}

/** Kimai returns "2026-09-01T20:07:00-0400" — make it ISO-parsable */
export function fromKimaiIso(s) {
  if (!s) return null;
  const fixed = String(s).replace(/([+-]\d{2})(\d{2})$/, "$1:$2");
  const d = new Date(fixed);
  return Number.isNaN(d.getTime()) ? null : d.toISOString();
}
