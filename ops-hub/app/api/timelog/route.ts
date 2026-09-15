import { NextResponse } from "next/server";
import { config } from "@/lib/config";

export const dynamic = "force-dynamic";

/** Proxy to ops-sync: today's calendar blocks vs Kimai entries + the active timer. */
export async function GET(req: Request) {
  const url = new URL(req.url);
  const date = url.searchParams.get("date") ?? "today";
  try {
    const [logRes, activeRes] = await Promise.all([
      fetch(`${config.opsSyncUrl}/timelog?date=${encodeURIComponent(date)}`, { cache: "no-store" }),
      fetch(`${config.opsSyncUrl}/timelog/active`, { cache: "no-store" }),
    ]);
    const timelog = await logRes.json();
    const active = activeRes.ok ? await activeRes.json() : { running: null };
    if (!logRes.ok) return NextResponse.json({ error: timelog.error ?? "timelog failed" }, { status: 502 });
    return NextResponse.json({ ...timelog, running: active.running ?? null });
  } catch (err) {
    return NextResponse.json({ error: String(err) }, { status: 502 });
  }
}
