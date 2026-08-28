import { readdir } from "node:fs/promises";
import { join } from "node:path";
import { ProjectAgent } from "./project-agent.js";

const WORKSPACE_ROOT = "F:\\ai-workspace";

async function listProjects(): Promise<string[]> {
  const projectsDir = join(WORKSPACE_ROOT, "projects");
  const entries = await readdir(projectsDir, { withFileTypes: true });
  return entries.filter((e) => e.isDirectory()).map((e) => e.name);
}

async function cmdList(): Promise<void> {
  const projects = await listProjects();
  console.log("Projects with agent teams:\n");
  for (const slug of projects) {
    const agent = new ProjectAgent({ projectSlug: slug, dryRun: true });
    try {
      await agent.init();
      const team = agent.getTeam();
      console.log(`  ${slug}`);
      console.log(`    name: ${team.project}`);
      console.log(`    local: ${team.localPath}`);
      console.log(`    roles: ${agent.listRoles().join(", ")}`);
      console.log();
    } catch (err) {
      console.log(`  ${slug} (no team.yaml yet)`);
    }
  }
}

async function cmdPm(args: string[]): Promise<void> {
  const dryRun = args.includes("--dry-run");
  const filtered = args.filter((a) => a !== "--dry-run");
  const slug = filtered[0];
  const task = filtered.slice(1).join(" ");

  if (!slug || !task) {
    console.error("Usage: npm run pm -- <slug> [--dry-run] <task>");
    process.exit(1);
  }

  const agent = new ProjectAgent({
    projectSlug: slug,
    dryRun,
  });

  const result = await agent.runAsPm(task);
  console.log(`Status: ${result.status}\n`);
  if (result.result) {
    console.log(result.result);
  }
}

async function cmdTeam(args: string[]): Promise<void> {
  const slug = args[0];
  if (!slug) {
    console.error("Usage: npm run team -- <slug>");
    process.exit(1);
  }
  const agent = new ProjectAgent({ projectSlug: slug, dryRun: true });
  await agent.init();
  console.log(JSON.stringify(agent.getTeam(), null, 2));
}

const [command, ...rest] = process.argv.slice(2);

switch (command) {
  case "list":
    await cmdList();
    break;
  case "pm":
    await cmdPm(rest);
    break;
  case "team":
    await cmdTeam(rest);
    break;
  default:
    console.log("Commands: list | pm | team");
    process.exit(1);
}
