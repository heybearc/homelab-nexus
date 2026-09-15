import { NextResponse } from "next/server";
import { quickCapture } from "@/lib/n8n";
import { config } from "@/lib/config";
import { createGoogleCalendarEvent, loadGoogleAccounts } from "@/lib/google";
import { createMicrosoftCalendarEvent, loadMicrosoftAccounts } from "@/lib/microsoft";

const LOCAL_CALENDAR_DESTS = new Set(["google_personal", "entra_cloudigan", "kimai_project"]);

export async function POST(req: Request) {
  try {
    const body = await req.json();
    if (!body.title?.trim()) {
      return NextResponse.json({ error: "title required" }, { status: 400 });
    }

    const destinations: string[] = body.destinations ?? ["vikunja"];
    const results: Record<string, unknown> = {};
    const title = body.title.trim();
    const description = body.description ?? "";
    const durationMinutes = body.duration_minutes ?? 60;
    const attendees = body.attendees;
    const timeZone = body.timeZone ?? "America/New_York";

    if (destinations.includes("google_personal")) {
      if (!loadGoogleAccounts().length) {
        return NextResponse.json(
          { error: "Connect a Google account before capturing to Google calendar" },
          { status: 400 },
        );
      }
      results.google = await createGoogleCalendarEvent({
        title,
        description,
        start: body.due,
        durationMinutes,
        email: body.google_email,
        calendarId: body.google_calendar_id,
        attendees,
        timeZone,
      });
    }

    if (destinations.includes("kimai_project")) {
      const onboardRes = await fetch(`${config.opsSyncUrl}/clients/onboard`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          customer: body.kimai_customer_name || title,
          customerId: body.kimai_customer_id || undefined,
          project: body.kimai_project_name || undefined,
          prefix: body.kimai_prefix || undefined,
          hoursPurchased: body.kimai_hours,
          notes: description,
          extraM365: Boolean(body.kimai_extra_m365),
          seedTasks: body.kimai_seed_tasks !== false,
        }),
      });
      const onboard = await onboardRes.json();
      if (!onboardRes.ok) {
        return NextResponse.json({ error: onboard.error ?? "Kimai project capture failed" }, { status: 502 });
      }
      results.kimai_project = onboard;
    }

    if (destinations.includes("entra_cloudigan")) {
      if (!loadMicrosoftAccounts().length) {
        return NextResponse.json(
          { error: "Connect Cloudigan (Microsoft) before capturing to Entra calendar" },
          { status: 400 },
        );
      }
      results.microsoft = await createMicrosoftCalendarEvent({
        title,
        description,
        start: body.due,
        durationMinutes,
        email: body.microsoft_email,
        lifeArea: "cloudigan",
        attendees,
        timeZone,
      });
    }

    const n8nDestinations = destinations.filter((d) => !LOCAL_CALENDAR_DESTS.has(d));
    if (n8nDestinations.length > 0) {
      results.n8n = await quickCapture({
        title,
        description,
        due: body.due,
        destinations: n8nDestinations,
        project_id: body.project_id ?? 1,
        calendar: body.calendar ?? "google_personal",
        duration_minutes: durationMinutes,
        kimai: body.kimai,
      });
    }

    return NextResponse.json({ ok: true, results });
  } catch (err) {
    return NextResponse.json({ error: String(err) }, { status: 500 });
  }
}
