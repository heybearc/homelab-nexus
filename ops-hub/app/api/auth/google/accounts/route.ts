import { NextResponse } from "next/server";
import {
  isGoogleConfigured,
  loadGoogleAccounts,
  removeGoogleAccount,
  triggerOpsSync,
} from "@/lib/google";

export async function GET() {
  const accounts = loadGoogleAccounts().map((a) => ({
    email: a.email,
    lifeArea: a.lifeArea,
    connectedAt: a.connectedAt,
  }));
  return NextResponse.json({ configured: isGoogleConfigured(), accounts });
}

export async function DELETE(req: Request) {
  const email = new URL(req.url).searchParams.get("email");
  if (!email) return NextResponse.json({ error: "email required" }, { status: 400 });
  removeGoogleAccount(email);
  await triggerOpsSync();
  return NextResponse.json({ ok: true });
}
