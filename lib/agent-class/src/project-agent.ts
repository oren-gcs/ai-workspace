import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { Agent, CursorAgentError } from "@cursor/sdk";
import type { AgentRole, GrokReviewerConfig, TeamYaml } from "./types.js";
import {
  buildRolePrompt,
  loadPmInstructions,
  loadTeamYaml,
  resolveLocalCwd,
} from "./team-loader.js";

const WORKSPACE_ROOT = "F:\\ai-workspace";

export interface ProjectAgentOptions {
  projectSlug: string;
  apiKey?: string;
  model?: string;
  dryRun?: boolean;
}

export class ProjectAgent {
  readonly projectSlug: string;
  readonly apiKey?: string;
  readonly model: string;
  readonly dryRun: boolean;

  private team: TeamYaml | null = null;
  private pmInstructions: string | null = null;

  constructor(opts: ProjectAgentOptions) {
    this.projectSlug = opts.projectSlug;
    this.apiKey = opts.apiKey ?? process.env.CURSOR_API_KEY;
    this.model = opts.model ?? "composer-2.5";
    this.dryRun = opts.dryRun ?? false;
  }

  async init(): Promise<void> {
    this.team = await loadTeamYaml(this.projectSlug);
    this.pmInstructions = await loadPmInstructions(this.projectSlug);
  }

  getTeam(): TeamYaml {
    if (!this.team) throw new Error("Call init() first");
    return this.team;
  }

  getLocalCwd(): string {
    return resolveLocalCwd(this.getTeam());
  }

  listRoles(): AgentRole[] {
    return Object.keys(this.getTeam().roles) as AgentRole[];
  }

  buildPmPrompt(task: string): string {
    const team = this.getTeam();
    return [
      this.pmInstructions ?? "",
      "",
      `## Project: ${team.project}`,
      `Local path: ${team.localPath}`,
      `Charter: ${team.charter}`,
      "",
      `## Your task as Project Manager`,
      task,
      "",
      `Coordinate by delegating to roles: ${this.listRoles().join(", ")}.`,
      `Read brain queue at C:\\Users\\oren\\.claude\\brain\\queue.json when relevant.`,
    ].join("\n");
  }

  async runAsPm(task: string): Promise<{ status: string; result?: string; dryRun?: boolean }> {
    await this.init();
    const prompt = this.buildPmPrompt(task);

    if (this.dryRun) {
      return {
        status: "dry-run",
        result: prompt,
        dryRun: true,
      };
    }

    if (!this.apiKey) {
      throw new Error(
        "CURSOR_API_KEY required for live runs. Use --dry-run to preview prompt."
      );
    }

    try {
      const result = await Agent.prompt(prompt, {
        apiKey: this.apiKey,
        model: { id: this.model },
        local: { cwd: this.getLocalCwd(), settingSources: [] },
      });

      if (result.status === "error") {
        return { status: "error", result: `Run failed: ${result.id}` };
      }
      return { status: result.status, result: result.result };
    } catch (err) {
      if (err instanceof CursorAgentError) {
        throw new Error(
          `Agent startup failed: ${err.message} (retryable=${err.isRetryable})`
        );
      }
      throw err;
    }
  }

  async runAsRole(
    role: AgentRole,
    task: string
  ): Promise<{ status: string; result?: string }> {
    await this.init();
    const team = this.getTeam();
    const prompt = buildRolePrompt(role, team, task);

    if (this.dryRun) {
      return { status: "dry-run", result: prompt };
    }

    if (!this.apiKey) {
      throw new Error("CURSOR_API_KEY required for live runs.");
    }

    const result = await Agent.prompt(prompt, {
      apiKey: this.apiKey,
      model: { id: this.model },
      local: { cwd: this.getLocalCwd(), settingSources: [] },
    });

    return { status: result.status, result: result.result };
  }

  /** Stub for optional Grok reviewer — enable via grok-reviewer.json */
  async invokeOptionalReviewer(
    task: string
  ): Promise<{ status: string; message: string }> {
    const configPath = join(WORKSPACE_ROOT, "config", "grok-reviewer.json");
    let config: GrokReviewerConfig;
    try {
      const raw = await readFile(configPath, "utf-8");
      config = JSON.parse(raw) as GrokReviewerConfig;
    } catch {
      return {
        status: "disabled",
        message:
          "Grok reviewer not configured. Copy config/grok-reviewer.json.template → grok-reviewer.json",
      };
    }

    if (!config.enabled) {
      return { status: "disabled", message: "Grok reviewer disabled in config" };
    }

    const apiKey = process.env[config.apiKeyEnv];
    if (!apiKey) {
      return {
        status: "missing-key",
        message: `Set ${config.apiKeyEnv} environment variable`,
      };
    }

    // HTTP call stub — implement when user enables Grok
    return {
      status: "stub",
      message: `Grok reviewer ready but HTTP client not wired. Task: ${task.slice(0, 80)}...`,
    };
  }
}
