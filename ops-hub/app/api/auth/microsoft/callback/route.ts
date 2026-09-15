import { NextResponse } from "next/server";
import { cookies } from "next/headers";
import {
  decodeIdTokenTenant,
  exchangeCodeForTokens,
  fetchMicrosoftProfile,
  getOpsHubBaseUrl,
  saveMicrosoftAccount,
  triggerOpsSync,
  type LifeAreaId,
} from "@/lib/microsoft";

function redirectTo(path: string) {
  return NextResponse.redirect(new URL(path, getOpsHubBaseUrl()));
}

export async function GET(req: Request) {
  const url = new URL(req.url);
  const error = url.searchParams.get("error");
  const errorDesc = url.searchParams.get("error_description");
  if (error) {
    return redirectTo(`/?ms_error=${encodeURIComponent(errorDesc ?? error)}`);
  }

  const code = url.searchParams.get("code");
  const stateRaw = url.searchParams.get("state");
  if (!code || !stateRaw) {
    return redirectTo("/?ms_error=Missing+OAuth+code");
  }

  const cookieStore = await cookies();
  const expectedNonce = cookieStore.get("ms_oauth_nonce")?.value;
  cookieStore.delete("ms_oauth_nonce");

  let lifeArea: LifeAreaId = "cloudigan";
  try {
    const state = JSON.parse(Buffer.from(stateRaw, "base64url").toString());
    if (!expectedNonce || state.nonce !== expectedNonce) {
      return redirectTo("/?ms_error=Invalid+OAuth+state");
    }
    lifeArea = state.lifeArea ?? "cloudigan";
  } catch {
    return redirectTo("/?ms_error=Invalid+OAuth+state");
  }

  try {
    const tokens = await exchangeCodeForTokens(code);
    if (!tokens.refresh_token) {
      throw new Error("No refresh token returned — ensure offline_access scope is granted");
    }

    const profile = await fetchMicrosoftProfile(tokens.access_token);
    const email = profile.mail ?? profile.userPrincipalName;
    const tenantId = tokens.id_token ? decodeIdTokenTenant(tokens.id_token) : null;
    if (!tenantId) throw new Error("Could not determine tenant ID from token");

    saveMicrosoftAccount({
      email,
      tenantId,
      lifeArea,
      refreshToken: tokens.refresh_token,
      connectedAt: new Date().toISOString(),
    });

    await triggerOpsSync();
    return redirectTo(`/?ms_connected=${encodeURIComponent(email)}`);
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    return redirectTo(`/?ms_error=${encodeURIComponent(msg)}`);
  }
}
