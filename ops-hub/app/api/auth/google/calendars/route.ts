import { NextResponse } from "next/server";
import { isGoogleConfigured, listGoogleCalendars } from "@/lib/google";

export async function GET(req: Request) {
  if (!isGoogleConfigured()) {
    return NextResponse.json({ configured: false, calendars: [] });
  }
  try {
    const email = new URL(req.url).searchParams.get("email") ?? undefined;
    const calendars = await listGoogleCalendars(email);
    return NextResponse.json({ configured: true, calendars });
  } catch (err) {
    return NextResponse.json({ error: String(err), calendars: [] }, { status: 500 });
  }
}
