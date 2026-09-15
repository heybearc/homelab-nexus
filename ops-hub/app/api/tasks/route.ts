import { NextResponse } from "next/server";
import { listTasks, completeTask } from "@/lib/vikunja";

export async function GET() {
  try {
    const tasks = await listTasks();
    const open = tasks.filter((t) => !t.done);
    return NextResponse.json({ tasks: open.slice(0, 100), total: open.length });
  } catch (err) {
    return NextResponse.json({ error: String(err) }, { status: 500 });
  }
}

export async function POST(req: Request) {
  try {
    const { taskId } = await req.json();
    if (!taskId) return NextResponse.json({ error: "taskId required" }, { status: 400 });
    const task = await completeTask(Number(taskId));
    return NextResponse.json({ task });
  } catch (err) {
    return NextResponse.json({ error: String(err) }, { status: 500 });
  }
}
