import { config } from "./config";

type VikunjaTask = {
  id: number;
  title: string;
  description?: string;
  done: boolean;
  due_date?: string | null;
  priority: number;
  project_id: number;
  project_title?: string;
};

async function vikunjaFetch(path: string, init?: RequestInit) {
  const res = await fetch(`${config.vikunjaApiUrl}${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${config.vikunjaToken}`,
      "Content-Type": "application/json",
      Accept: "application/json",
      ...(init?.headers ?? {}),
    },
    cache: "no-store",
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Vikunja ${path}: ${res.status} ${text}`);
  }
  return res.json();
}

type VikunjaProject = { id: number; title: string; is_archived?: boolean };

export async function listProjects(): Promise<VikunjaProject[]> {
  const projects: VikunjaProject[] = await vikunjaFetch("/projects?per_page=100");
  return projects.filter((p) => !p.is_archived);
}

/** Open tasks. `/tasks/all` returns 400 on Vikunja v2.2+, so walk projects instead. */
export async function listTasks(projectId?: number): Promise<VikunjaTask[]> {
  const filter = encodeURIComponent("done = false");
  if (projectId) return vikunjaFetch(`/projects/${projectId}/tasks?per_page=50&filter=${filter}`);
  const projects = await listProjects();
  const results = await Promise.all(
    projects.map((p) =>
      vikunjaFetch(`/projects/${p.id}/tasks?per_page=50&filter=${filter}`)
        .then((tasks: VikunjaTask[]) => tasks.map((t) => ({ ...t, project_title: p.title })))
        .catch(() => [] as VikunjaTask[]),
    ),
  );
  const seen = new Set<number>();
  return results
    .flat()
    .filter((t) => !t.done && !seen.has(t.id) && (seen.add(t.id), true))
    .sort((a, b) => {
      const ad = a.due_date && !a.due_date.startsWith("0001") ? a.due_date : "9999";
      const bd = b.due_date && !b.due_date.startsWith("0001") ? b.due_date : "9999";
      return ad.localeCompare(bd);
    });
}

export async function completeTask(taskId: number): Promise<VikunjaTask> {
  return vikunjaFetch(`/tasks/${taskId}`, {
    method: "POST",
    body: JSON.stringify({ done: true }),
  });
}

export async function createTask(input: {
  title: string;
  description?: string;
  due_date?: string;
  project_id?: number;
}): Promise<VikunjaTask> {
  const projectId = input.project_id ?? 1;
  return vikunjaFetch(`/projects/${projectId}/tasks`, {
    method: "PUT",
    body: JSON.stringify({
      title: input.title,
      description: input.description ?? "",
      due_date: input.due_date ?? null,
    }),
  });
}

export type { VikunjaTask };
