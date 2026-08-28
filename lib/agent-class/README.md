# ProjectAgent — Agent Company Runtime

TypeScript implementation using `@cursor/sdk` for local agent execution per project.

## Install

```powershell
cd F:\ai-workspace\lib\agent-class
npm install
```

## Usage

```powershell
# List all project teams
npm run list

# Preview PM prompt (no API key)
npm run pm -- doc-power --dry-run "List P0 blockers"

# Live PM run (requires CURSOR_API_KEY)
$env:CURSOR_API_KEY = "cursor_..."
npm run pm -- doc-power "Summarize git status and recommend next commit"

# Dump team.yaml as JSON
npm run team -- fun4kids
```

## API

```typescript
import { ProjectAgent } from "./src/project-agent.js";

const agent = new ProjectAgent({ projectSlug: "doc-power" });
await agent.init();

// PM entry point
const result = await agent.runAsPm("Review docker-compose security bindings");

// Delegate to role
const dev = await agent.runAsRole("Developer", "Fix postgres port binding");

// Optional Grok reviewer (stub)
const review = await agent.invokeOptionalReviewer("Architecture review for SaaS tier");
```

## Roles

Defined in each project's `agents/team.yaml`:

- ProjectManager, Developer, DevOps, QA, SecurityAuditor, LearningCoach
