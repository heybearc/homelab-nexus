import { NextResponse } from "next/server";
import { kimaiTimer } from "@/lib/n8n";

export async function POST(req: Request) {
  try {
    const body = await req.json();
    const result = await kimaiTimer({
      action: body.action ?? "status",
      project: body.project,
      activity: body.activity,
      customer: body.customer,
      description: body.description,
    });
    return NextResponse.json({ ok: true, result });
  } catch (err) {
    return NextResponse.json({ error: String(err) }, { status: 500 });
  }
}

export async function GET() {
  try {
    const result = await kimaiTimer({ action: "status" });
    return NextResponse.json({ ok: true, result });
  } catch (err) {
    return NextResponse.json({ error: String(err) }, { status: 500 });
  }
}
