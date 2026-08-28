import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { parse as parseYaml } from "yaml";
import type { TeamYaml } from "./types.js";

const WORKSPACE_ROOT = "F:\\ai-workspace";

export async function loadTeamYaml(projectSlug: string): Promise<TeamYaml> {
  const teamPath = join(
    WORKSPACE_ROOT,
    "projects",
    projectSlug,
    "agents",
    "team.yaml"
  );
  const raw = await readFile(teamPath, "utf-8");
  return parseYaml(raw) as TeamYaml;
}

export async function loadPmInstructions(projectSlug: string): Promise<string> {
  const pmPath = join(
    WORKSPACE_ROOT,
    "projects",
    projectSlug,
    "agents",
    "pm-agent.md"
  );
  return readFile(pmPath, "utf-8");
}

export function resolveLocalCwd(team: TeamYaml): string {
  return team.localPath;
}

export function buildRolePrompt(
  role: string,
  team: TeamYaml,
  task: string
): string {
  const roleConfig = team.roles[role as keyof typeof team.roles];
  if (!roleConfig) {
    throw new Error(`Role ${role} not defined in team.yaml for ${team.slug}`);
  }
  const skillRef = roleConfig.skillPath ?? roleConfig.skill;
  return [
    `You are the ${role} for project "${team.project}".`,
    `Skill reference: ${skillRef}`,
    roleConfig.instructions ?? "",
    `Working directory: ${team.localPath}`,
    "",
    `Task: ${task}`,
  ]
    .filter(Boolean)
    .join("\n");
}
