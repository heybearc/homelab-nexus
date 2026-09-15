// Optional LLM summarizer for the morning briefing.
// Configure with OPS_LLM_PROVIDER = anthropic | openai | ollama (+ key / URL). Unset = disabled.

export function llmProvider() {
  const p = (process.env.OPS_LLM_PROVIDER || "").toLowerCase();
  if (p === "anthropic" && process.env.ANTHROPIC_API_KEY) return "anthropic";
  if (p === "openai" && process.env.OPENAI_API_KEY) return "openai";
  if (p === "ollama" && (process.env.OLLAMA_URL || process.env.OLLAMA_HOST)) return "ollama";
  // auto-detect when provider not set
  if (!p) {
    if (process.env.ANTHROPIC_API_KEY) return "anthropic";
    if (process.env.OPENAI_API_KEY) return "openai";
    if (process.env.OLLAMA_URL || process.env.OLLAMA_HOST) return "ollama";
  }
  return null;
}

export function isLlmConfigured() {
  return Boolean(llmProvider());
}

const DEFAULT_MODELS = {
  anthropic: "claude-3-5-haiku-latest",
  openai: "gpt-4o-mini",
  ollama: "llama3.1",
};

const SYSTEM = `You write Cory's morning ops briefing headline. You get structured JSON about today: calendar events by life area (personal, cloudigan = his MSP business, thrive = his W-2 job, theocratic), cross-calendar conflicts, open tasks, yesterday's Kimai time-tracking (logged vs scheduled client hours), and bills due soon.
Write 2–4 short sentences, plain text, no markdown, no emojis, no bullet lists. Lead with what matters most today (conflicts, unlogged client time, hard deadlines), then the shape of the day. Be concrete: name events, clients, and hours. Do not restate every item — the full list follows your summary. Do not invent anything not in the data.`;

async function withTimeout(promise, ms) {
  let t;
  const timeout = new Promise((_, rej) => {
    t = setTimeout(() => rej(new Error(`LLM timeout after ${ms}ms`)), ms);
  });
  try {
    return await Promise.race([promise, timeout]);
  } finally {
    clearTimeout(t);
  }
}

export async function summarizeBriefing(structured) {
  const provider = llmProvider();
  if (!provider) return null;
  const model = process.env.OPS_LLM_MODEL || DEFAULT_MODELS[provider];
  const user = `Today's data:\n${JSON.stringify(structured, null, 0)}`;
  const timeoutMs = Number(process.env.OPS_LLM_TIMEOUT_MS || 25000);

  if (provider === "anthropic") {
    const res = await withTimeout(
      fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "x-api-key": process.env.ANTHROPIC_API_KEY,
          "anthropic-version": "2023-06-01",
          "content-type": "application/json",
        },
        body: JSON.stringify({
          model,
          max_tokens: 300,
          system: SYSTEM,
          messages: [{ role: "user", content: user }],
        }),
      }),
      timeoutMs,
    );
    const data = await res.json();
    if (!res.ok) throw new Error(`anthropic: ${data.error?.message ?? res.status}`);
    return { provider, model, text: (data.content ?? []).map((c) => c.text ?? "").join("").trim() };
  }

  if (provider === "openai") {
    const base = (process.env.OPENAI_BASE_URL || "https://api.openai.com/v1").replace(/\/+$/, "");
    const res = await withTimeout(
      fetch(`${base}/chat/completions`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${process.env.OPENAI_API_KEY}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          model,
          max_tokens: 300,
          temperature: 0.4,
          messages: [
            { role: "system", content: SYSTEM },
            { role: "user", content: user },
          ],
        }),
      }),
      timeoutMs,
    );
    const data = await res.json();
    if (!res.ok) throw new Error(`openai: ${data.error?.message ?? res.status}`);
    return { provider, model, text: (data.choices?.[0]?.message?.content ?? "").trim() };
  }

  if (provider === "ollama") {
    const base = (process.env.OLLAMA_URL || process.env.OLLAMA_HOST || "http://127.0.0.1:11434").replace(/\/+$/, "");
    const res = await withTimeout(
      fetch(`${base}/api/chat`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          model,
          stream: false,
          options: { temperature: 0.4, num_predict: 300 },
          messages: [
            { role: "system", content: SYSTEM },
            { role: "user", content: user },
          ],
        }),
      }),
      timeoutMs,
    );
    const data = await res.json();
    if (!res.ok) throw new Error(`ollama: ${data.error ?? res.status}`);
    return { provider, model, text: (data.message?.content ?? "").trim() };
  }

  return null;
}
