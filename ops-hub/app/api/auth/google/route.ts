import { NextResponse } from "next/server";
import { cookies } from "next/headers";
import { getGoogleAuthorizeUrl, isGoogleConfigured } from "@/lib/google";

export async function GET() {
  if (!isGoogleConfigured()) {
    return NextResponse.json(
      { error: "GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET are not configured on ops-hub" },
      { status: 503 },
    );
  }

  const nonce = crypto.randomUUID();
  const state = Buffer.from(JSON.stringify({ lifeArea: "personal", nonce })).toString("base64url");
  const cookieStore = await cookies();
  cookieStore.set("google_oauth_nonce", nonce, {
    httpOnly: true,
    secure: true,
    sameSite: "lax",
    maxAge: 600,
    path: "/",
  });

  return NextResponse.redirect(getGoogleAuthorizeUrl(state));
}
