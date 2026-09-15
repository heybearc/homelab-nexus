import { NextResponse } from "next/server";
import fs from "fs";
import path from "path";

/** Proxy merged ICS for Apple Calendar subscription */
export async function GET() {
  const syncUrl = process.env.OPS_SYNC_URL ?? "http://127.0.0.1:3002";
  try {
    const res = await fetch(`${syncUrl}/merged.ics`, { cache: "no-store" });
    if (!res.ok) throw new Error(String(res.status));
    const ics = await res.text();
    return new NextResponse(ics, {
      headers: { "Content-Type": "text/calendar; charset=utf-8" },
    });
  } catch {
    const fallback = path.join(process.cwd(), "../ops-sync/data/merged.ics");
    if (fs.existsSync(fallback)) {
      return new NextResponse(fs.readFileSync(fallback, "utf8"), {
        headers: { "Content-Type": "text/calendar; charset=utf-8" },
      });
    }
    return new NextResponse("Calendar not synced yet", { status: 503 });
  }
}
