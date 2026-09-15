import { NextResponse } from "next/server";
import { config } from "@/lib/config";

export async function GET() {
  try {
    const res = await fetch(`${config.opsSyncUrl}/calendar`, { cache: "no-store" });
    if (!res.ok) throw new Error(`ops-sync: ${res.status}`);
    const data = await res.json();
    return NextResponse.json(data);
  } catch (err) {
    return NextResponse.json({ events: [], conflicts: [], error: String(err) });
  }
}
