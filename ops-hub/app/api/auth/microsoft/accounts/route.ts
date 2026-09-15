import { NextResponse } from "next/server";
import {
  isMicrosoftConfigured,
  loadMicrosoftAccounts,
  removeMicrosoftAccount,
  triggerOpsSync,
} from "@/lib/microsoft";

export async function GET() {
  const accounts = loadMicrosoftAccounts().map((a) => ({
    email: a.email,
    lifeArea: a.lifeArea,
    connectedAt: a.connectedAt,
  }));
  return NextResponse.json({ configured: isMicrosoftConfigured(), accounts });
}

export async function DELETE(req: Request) {
  const email = new URL(req.url).searchParams.get("email");
  if (!email) return NextResponse.json({ error: "email required" }, { status: 400 });
  removeMicrosoftAccount(email);
  await triggerOpsSync();
  return NextResponse.json({ ok: true });
}
