import { NextResponse } from "next/server";
import { cookies } from "next/headers";
import {
  exchangeGoogleCode,
  fetchGoogleProfile,
  saveGoogleAccount,
  triggerOpsSync,
} from "@/lib/google";
import { getOpsHubBaseUrl } from "@/lib/microsoft";

function redirectTo(path: string) {
  return NextResponse.redirect(new URL(path, getOpsHubBaseUrl()));
}

export async function GET(req: Request) {
  const url = new URL(req.url);
  const error = url.searchParams.get("error");
  if (error) {
    return redirectTo(`/?google_error=${encodeURIComponent(error)}`);
  }

  const code = url.searchParams.get("code");
  const stateRaw = url.searchParams.get("state");
  if (!code || !stateRaw) {
    return redirectTo("/?google_error=Missing+OAuth+code");
  }

  const cookieStore = await cookies();
  const expectedNonce = cookieStore.get("google_oauth_nonce")?.value;
  cookieStore.delete("google_oauth_nonce");

  try {
    const state = JSON.parse(Buffer.from(stateRaw, "base64url").toString());
    if (!expectedNonce || state.nonce !== expectedNonce) {
      return redirectTo("/?google_error=Invalid+OAuth+state");
    }
  } catch {
    return redirectTo("/?google_error=Invalid+OAuth+state");
  }

  try {
    const tokens = await exchangeGoogleCode(code);
    const profile = await fetchGoogleProfile(tokens.access_token);

    saveGoogleAccount({
      email: profile.email,
      lifeArea: "personal",
      refreshToken: tokens.refresh_token ?? "",
      connectedAt: new Date().toISOString(),
    });

    await triggerOpsSync();
    return redirectTo(`/?google_connected=${encodeURIComponent(profile.email)}`);
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    return redirectTo(`/?google_error=${encodeURIComponent(msg)}`);
  }
}
