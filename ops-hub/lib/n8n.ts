type CapturePayload = {
  title: string;
  description?: string;
  due?: string;
  destinations: string[];
  project_id?: number;
  calendar?: string;
  duration_minutes?: number;
  kimai?: Record<string, unknown>;
};

type TimerPayload = {
  action: "start" | "stop" | "status";
  project?: string;
  activity?: string;
  customer?: string;
  description?: string;
};

async function postWebhook(url: string, body: unknown) {
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(`n8n webhook failed: ${res.status} ${JSON.stringify(data)}`);
  }
  return data;
}

export async function quickCapture(payload: CapturePayload) {
  return postWebhook(process.env.N8N_OPS_CAPTURE_URL ?? "https://flows.cloudigan.net/webhook/ops-capture", payload);
}

export async function kimaiTimer(payload: TimerPayload) {
  return postWebhook(process.env.N8N_OPS_TIMER_URL ?? "https://flows.cloudigan.net/webhook/ops-kimai-timer", payload);
}

export type { CapturePayload, TimerPayload };
