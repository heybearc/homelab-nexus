import { NextResponse } from "next/server";
import { cookies } from "next/headers";
import { getAuthorizeUrl, isMicrosoftConfigured, type LifeAreaId } from "@/lib/microsoft";

const VALID_AREAS = new Set(["thrive", "cloudigan", "theocratic", "jwpub", "personal"]);

export async function GET(req: Request) {
  if (!isMicrosoftConfigured()) {
    return NextResponse.json(
      { error: "M365_CLIENT_ID and M365_CLIENT_SECRET are not configured on ops-hub" },
      { status: 503 },
    );
  }

  const lifeArea = new URL(req.url).searchParams.get("lifeArea") ?? "cloudigan";
  if (!VALID_AREAS.has(lifeArea)) {
    return NextResponse.json({ error: "Invalid lifeArea" }, { status: 400 });
  }

  const nonce = crypto.randomUUID();
  const state = Buffer.from(JSON.stringify({ lifeArea, nonce })).toString("base64url");
  const cookieStore = await cookies();
  cookieStore.set("ms_oauth_nonce", nonce, {
    httpOnly: true,
    secure: true,
    sameSite: "lax",
    maxAge: 600,
    path: "/",
  });

  return NextResponse.redirect(getAuthorizeUrl(state));
}
