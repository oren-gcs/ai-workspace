export type AgentRole =
  | "ProjectManager"
  | "Developer"
  | "DevOps"
  | "QA"
  | "SecurityAuditor"
  | "LearningCoach";

export const ALL_ROLES: AgentRole[] = [
  "ProjectManager",
  "Developer",
  "DevOps",
  "QA",
  "SecurityAuditor",
  "LearningCoach",
];

export interface RoleConfig {
  skill: string;
  skillPath?: string;
  mcpServers: string[];
  model?: string;
  instructions?: string;
}

export interface TeamYaml {
  project: string;
  slug: string;
  localPath: string;
  charter: string;
  roles: Partial<Record<AgentRole, RoleConfig>>;
  optionalAgents?: Record<string, { enabled: boolean; config?: string }>;
  mcp?: {
    allowedPaths?: string[];
    registry?: string;
  };
}

export interface ProjectManifestEntry {
  slug: string;
  name: string;
  workspacePath: string;
  localWinnerPath: string;
  cursorSkill: string;
  teamFile: string;
}

export interface GrokReviewerConfig {
  enabled: boolean;
  apiBase: string;
  model: string;
  apiKeyEnv: string;
}
