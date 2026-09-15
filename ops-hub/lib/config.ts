export const config = {
  vikunjaApiUrl: process.env.VIKUNJA_API_URL ?? "https://tasks.cloudigan.net/api/v1",
  vikunjaToken: process.env.VIKUNJA_API_TOKEN ?? "",
  n8nCaptureUrl: process.env.N8N_OPS_CAPTURE_URL ?? "https://flows.cloudigan.net/webhook/ops-capture",
  n8nTimerUrl: process.env.N8N_OPS_TIMER_URL ?? "https://flows.cloudigan.net/webhook/ops-kimai-timer",
  opsSyncUrl: process.env.OPS_SYNC_URL ?? "http://127.0.0.1:3002",
  ntfyTopic: process.env.NTFY_TOPIC ?? "cory-daily-briefing",
};
