import { NextResponse } from "next/server";
import { config } from "@/lib/config";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    const res = await fetch(`${config.opsSyncUrl}/quotas`, { cache: "no-store" });
    const data = await res.json();
    if (!res.ok) return NextResponse.json({ error: data.error ?? "quotas failed" }, { status: 502 });
    return NextResponse.json(data);
  } catch (err) {
    return NextResponse.json({ error: String(err) }, { status: 502 });
  }
}
