// Minimal Vikunja client for ops-sync (task creation for gaps/bills, open-task fetch for briefing).

function base() {
  return (process.env.VIKUNJA_API_URL || "https://tasks.cloudigan.net/api/v1").replace(/\/+$/, "");
}

export function isVikunjaConfigured() {
  return Boolean(process.env.VIKUNJA_API_TOKEN);
}

export function defaultProjectId() {
  return Number(process.env.VIKUNJA_PROJECT_ID || 1);
}

async function vk(pathname, init = {}) {
  const method = (init.method || "GET").toUpperCase();
  const res = await fetch(`${base()}${pathname}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${process.env.VIKUNJA_API_TOKEN}`,
      Accept: "application/json",
      // Vikunja returns "Invalid model provided" if a GET carries a JSON content-type with no body
      ...(method === "GET" ? {} : { "Content-Type": "application/json" }),
      ...(init.headers ?? {}),
    },
  });
  const text = await res.text();
  const data = text ? JSON.parse(text) : null;
  if (!res.ok) throw new Error(`Vikunja ${pathname}: ${res.status} ${data?.message ?? text}`);
  return { data, headers: res.headers };
}

export async function createTask({ title, description = "", dueDate = null, projectId = defaultProjectId(), priority = 0, labels = [] }) {
  const { data } = await vk(`/projects/${projectId}/tasks`, {
    method: "PUT",
    body: JSON.stringify({
      title,
      description,
      due_date: dueDate,
      priority,
    }),
  });
  for (const label of labels) {
    try {
      await addLabel(data.id, label);
    } catch (err) {
      console.warn(`label "${label}" skipped:`, err.message);
    }
  }
  return data;
}

let labelCache = null;
async function ensureLabel(title) {
  if (!labelCache) {
    const { data } = await vk("/labels?per_page=200");
    labelCache = new Map((Array.isArray(data) ? data : []).map((l) => [l.title.toLowerCase(), l]));
  }
  const hit = labelCache.get(title.toLowerCase());
  if (hit) return hit;
  const { data } = await vk("/labels", { method: "PUT", body: JSON.stringify({ title }) });
  labelCache.set(title.toLowerCase(), data);
  return data;
}

async function addLabel(taskId, title) {
  const label = await ensureLabel(title);
  await vk(`/tasks/${taskId}/labels`, { method: "PUT", body: JSON.stringify({ label_id: label.id }) });
}

export async function listProjects() {
  if (!isVikunjaConfigured()) return [];
  const { data } = await vk("/projects?per_page=100");
  return (Array.isArray(data) ? data : []).filter((p) => !p.is_archived);
}

/** All open tasks across projects. (/tasks/all returns 400 on Vikunja v2.2, so walk projects.) */
export async function listOpenTasks(maxPagesPerProject = 4) {
  if (!isVikunjaConfigured()) return [];
  const projects = await listProjects();
  const all = [];
  for (const p of projects) {
    for (let page = 1; page <= maxPagesPerProject; page++) {
      const { data, headers } = await vk(`/projects/${p.id}/tasks?page=${page}&per_page=50&filter=${encodeURIComponent("done = false")}`);
      const rows = Array.isArray(data) ? data : [];
      for (const t of rows) all.push({ ...t, project_title: p.title });
      const totalPages = Number(headers.get("x-pagination-total-pages") || 1);
      if (page >= totalPages || rows.length < 50) break;
    }
  }
  const seen = new Set();
  return all.filter((t) => !t.done && !seen.has(t.id) && seen.add(t.id));
}

export async function createProject({ title, description = "", parentProjectId = null }) {
  const { data } = await vk("/projects", {
    method: "PUT",
    body: JSON.stringify({
      title,
      description,
      parent_project_id: parentProjectId || 0,
    }),
  });
  return data;
}

export function projectUrl(project) {
  const web = (process.env.VIKUNJA_WEB_URL || base().replace(/\/api\/v1$/, "")).replace(/\/+$/, "");
  return `${web}/projects/${project.id}`;
}

export function taskUrl(task) {
  const web = (process.env.VIKUNJA_WEB_URL || base().replace(/\/api\/v1$/, "")).replace(/\/+$/, "");
  return `${web}/tasks/${task.id}`;
}
