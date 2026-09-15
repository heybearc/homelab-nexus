import { NextResponse } from "next/server";
import { config } from "@/lib/config";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    const res = await fetch(`${config.opsSyncUrl}/alerts`, { cache: "no-store" });
    const data = await res.json();
    if (!res.ok) return NextResponse.json({ error: data.error ?? "alerts failed" }, { status: 502 });
    return NextResponse.json(data);
  } catch (err) {
    return NextResponse.json({ error: String(err) }, { status: 502 });
  }
}

export async function POST() {
  try {
    const res = await fetch(`${config.opsSyncUrl}/alerts/heal`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: "{}",
    });
    const data = await res.json();
    if (!res.ok) return NextResponse.json({ error: data.error ?? "heal failed" }, { status: 502 });
    return NextResponse.json(data);
  } catch (err) {
    return NextResponse.json({ error: String(err) }, { status: 500 });
  }
}
