import { NextResponse } from "next/server";
import { config } from "@/lib/config";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    const res = await fetch(`${config.opsSyncUrl}/clients/template`, { cache: "no-store" });
    const data = await res.json();
    if (!res.ok) return NextResponse.json({ error: data.error ?? "clients failed" }, { status: 502 });
    return NextResponse.json(data);
  } catch (err) {
    return NextResponse.json({ error: String(err) }, { status: 502 });
  }
}

export async function POST(req: Request) {
  try {
    const body = await req.json();
    const res = await fetch(`${config.opsSyncUrl}/clients/onboard`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    const data = await res.json();
    if (!res.ok) return NextResponse.json({ error: data.error ?? "onboard failed" }, { status: 502 });
    return NextResponse.json(data);
  } catch (err) {
    return NextResponse.json({ error: String(err) }, { status: 500 });
  }
}
