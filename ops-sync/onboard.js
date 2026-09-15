// Capture a Kimai customer/project and seed the matching Vikunja onboarding tasks.
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import {
  loadCatalog,
  createCustomer,
  createProject,
  patchCustomer,
  getCustomer,
  saveKimaiMapExtra,
  kimaiWebBase,
} from "./kimai.js";
import { createProject as createVikunjaProject, createTask, listProjects, isVikunjaConfigured, projectUrl } from "./vikunja.js";
import { addDays, todayLocal, localToUtc } from "./tz.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TEMPLATE_PATH = process.env.OPS_CLIENT_TEMPLATE ?? path.join(__dirname, "client-template.json");

export function loadTemplate() {
  if (!fs.existsSync(TEMPLATE_PATH)) return { tasks: [], vikunjaParentProjectId: 3, label: "onboard" };
  return JSON.parse(fs.readFileSync(TEMPLATE_PATH, "utf8"));
}

export function suggestPrefix(name) {
  const stop = new Set(["the", "and", "of", "for", "llc", "inc", "co", "corp", "ltd"]);
  const words = String(name || "")
    .replace(/[^A-Za-z0-9\s-]/g, " ")
    .split(/[\s-]+/)
    .filter((w) => w && !stop.has(w.toLowerCase()));
  if (!words.length) return "NEW";
  if (words.length === 1) return words[0].slice(0, 4).toUpperCase();
  return words.map((w) => w[0]).join("").slice(0, 5).toUpperCase();
}

function interpolate(str, vars) {
  return String(str ?? "").replace(/\{\{(\w+)\}\}/g, (_, k) => vars[k] ?? "");
}

function findCustomer(catalog, nameOrId) {
  if (nameOrId == null || nameOrId === "") return null;
  if (Number.isFinite(Number(nameOrId)) && String(nameOrId).match(/^\d+$/)) {
    return catalog.customers.find((c) => c.id === Number(nameOrId)) ?? null;
  }
  const want = String(nameOrId).trim().toLowerCase();
  return catalog.customers.find((c) => c.name.toLowerCase() === want) ?? null;
}

function findProject(catalog, customerId, name) {
  const want = String(name).trim().toLowerCase();
  return catalog.projects.find((p) => p.customer === customerId && p.name.toLowerCase() === want) ?? null;
}

/**
 * @param input {{
 *   customer?: string,
 *   customerId?: number,
 *   project?: string,
 *   prefix?: string,
 *   hoursPurchased?: number,
 *   addHours?: number,
 *   notes?: string,
 *   seedTasks?: boolean,
 *   extraM365?: boolean
 * }}
 */
export async function onboardClient(input) {
  const customerName = String(input.customer || input.title || "").trim();
  if (!customerName && !input.customerId) throw new Error("customer name required");

  const catalog = await loadCatalog(true);
  let customer = findCustomer(catalog, input.customerId ?? customerName);
  const created = { customer: false, project: false, vikunja: false };
  const notes = String(input.notes || input.description || "").trim();
  const prefix = (input.prefix || suggestPrefix(customer?.name || customerName)).toUpperCase();
  const projectName = String(input.project || input.projectName || `${prefix} - General Work`).trim();

  if (!customer) {
    customer = await createCustomer({
      name: customerName,
      comment: notes,
      timeBudgetHours: Number(input.hoursPurchased || 0),
    });
    created.customer = true;
  } else if (input.hoursPurchased != null && input.hoursPurchased !== "") {
    const hours = Number(input.hoursPurchased);
    if (!Number.isNaN(hours) && hours >= 0) {
      customer = await patchCustomer(customer.id, { timeBudgetHours: hours });
    }
  } else if (input.addHours) {
    const detail = customer.timeBudget != null ? customer : await getCustomer(customer.id);
    const currentH = (Number(detail.timeBudget || 0) / 3600) + Number(input.addHours);
    customer = await patchCustomer(customer.id, { timeBudgetHours: currentH });
  }

  let project = findProject(catalog, customer.id, projectName);
  if (!project) {
    project = await createProject({
      name: projectName,
      customerId: customer.id,
      comment: notes,
    });
    created.project = true;
  }

  if (input.extraM365) {
    const m365Name = `${prefix} - M365 Management`;
    if (!findProject(catalog, customer.id, m365Name)) {
      await createProject({ name: m365Name, customerId: customer.id });
    }
  }

  const aliases = [
    customer.name.toLowerCase(),
    prefix.toLowerCase(),
    ...String(customer.name)
      .split(/\s+/)
      .filter((w) => w.length > 3)
      .map((w) => w.toLowerCase()),
  ];
  saveKimaiMapExtra({ customers: { [customer.name]: aliases } });

  const template = loadTemplate();
  const hoursLabel = input.hoursPurchased ? `${input.hoursPurchased}h` : "not set";
  const vars = {
    customer: customer.name,
    project: project.name,
    hours: hoursLabel,
    prefix,
    kimaiUrl: `${kimaiWebBase()}/en/admin/customer/${customer.id}/details`,
    opsHubUrl: process.env.OPS_HUB_URL || "https://ops.cloudigan.net",
  };

  let vikunja = null;
  const tasks = [];
  if (input.seedTasks !== false && isVikunjaConfigured()) {
    const projects = await listProjects();
    const parentId = Number(input.vikunjaParentId ?? template.vikunjaParentProjectId ?? 3);
    vikunja = projects.find((p) => p.title.toLowerCase() === customer.name.toLowerCase() && (p.parent_project_id === parentId || !parentId));
    if (!vikunja) {
      vikunja = await createVikunjaProject({
        title: customer.name,
        description: `Cloudigan client · Kimai ${project.name}`,
        parentProjectId: parentId,
      });
      created.vikunja = true;
    }
    const today = todayLocal();
    for (const t of template.tasks ?? []) {
      const due = t.dueDays != null ? localToUtc(addDays(today, Number(t.dueDays)), "17:00").toISOString() : null;
      const task = await createTask({
        title: interpolate(t.title, vars),
        description: interpolate(t.description, vars),
        dueDate: due,
        projectId: vikunja.id,
        priority: t.priority ?? 2,
        labels: [template.label || "onboard"],
      });
      tasks.push({ id: task.id, title: task.title });
    }
  }

  return {
    ok: true,
    created,
    customer: { id: customer.id, name: customer.name },
    project: { id: project.id, name: project.name },
    prefix,
    vikunja: vikunja ? { id: vikunja.id, title: vikunja.title, url: projectUrl(vikunja) } : null,
    tasks,
    taskCount: tasks.length,
    title: `New client: ${customer.name}`,
    message: [
      `Kimai ${created.customer ? "customer + " : ""}project ready: ${customer.name} / ${project.name}`,
      vikunja ? `Vikunja: ${vikunja.title} (${tasks.length} onboarding task${tasks.length === 1 ? "" : "s"})` : "",
      hoursLabel !== "not set" ? `Hours purchased: ${hoursLabel}` : "",
    ]
      .filter(Boolean)
      .join("\n"),
    priority: "3",
  };
}
