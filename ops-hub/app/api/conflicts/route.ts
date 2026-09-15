import { NextResponse } from "next/server";
import { config } from "@/lib/config";
import { createTask } from "@/lib/vikunja";

export async function POST(req: Request) {
  try {
    const body = await req.json();
    const action = body.action ?? "dismiss";
    const conflict = body.conflict;

    if (action === "dismiss") {
      if (!body.id && !conflict?.id) {
        return NextResponse.json({ error: "id required" }, { status: 400 });
      }
      const res = await fetch(`${config.opsSyncUrl}/conflicts/dismiss`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ id: body.id ?? conflict.id, days: body.days ?? 7 }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error ?? res.statusText);
      return NextResponse.json(data);
    }

    if (action === "task") {
      if (!conflict?.a || !conflict?.b) {
        return NextResponse.json({ error: "conflict required" }, { status: 400 });
      }
      const when = conflict.at
        ? new Date(conflict.at).toLocaleString("en-US", { timeZone: "America/New_York" })
        : "unknown time";
      const title = `Resolve conflict: ${conflict.a} ↔ ${conflict.b}`;
      const description = [
        `Overlap around ${when} (${conflict.overlapMinutes ?? "?"} min)`,
        `Sources: ${(conflict.sources ?? []).join(" | ")}`,
        `Life areas: ${(conflict.lifeAreas ?? []).join(" | ")}`,
        "",
        "Pick one to keep, move, or decline — then dismiss in Ops Hub.",
        "https://ops.cloudigan.net",
      ].join("\n");
      const task = await createTask({
        title,
        description,
        due_date: conflict.at ?? undefined,
      });

      // Also dismiss so it leaves the alert strip
      if (conflict.id) {
        await fetch(`${config.opsSyncUrl}/conflicts/dismiss`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ id: conflict.id, days: 14 }),
        }).catch(() => null);
      }

      return NextResponse.json({ ok: true, task });
    }

    return NextResponse.json({ error: "Unknown action" }, { status: 400 });
  } catch (err) {
    return NextResponse.json({ error: String(err) }, { status: 500 });
  }
}
