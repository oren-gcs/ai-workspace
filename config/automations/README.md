# Cursor Automation drafts

Draft configs for Oren to import via **Cursor → Automations** (Agents Window + `automate` skill).
These are **not** active automations — copy or open in editor when ready.

## brain-dispatcher-hourly.yaml

```yaml
name: "Brain queue drain (hourly)"
description: "Read brain queue, update RESUME, log blockers to ACTION-LOG"
workflow:
  triggers:
    - cron:
        cron: "0 * * * *"
  actions: []
  prompts:
    - |
      You are the brain-dispatcher agent. Read-only first:
      1. C:\Users\oren\.claude\brain\queue.json
      2. C:\Users\oren\.claude\brain\RESUME.md
      3. F:\ai-workspace\ACTION-LOG.md (append only if action taken)

      Drain pending items you can complete without user interaction.
      For blocked items (gh auth, GUI, elevation), append ACTION-LOG entry.
      Never commit secrets. Never force push.
  model: ""
  agentOptions:
    skipInstall: false
  memoryEnabled: true
```

**To finish in editor:** Cloud compute settings, confirm cron timezone.

---

## security-scan-daily.yaml

```yaml
name: "Daily security review"
description: "Run security-scan-review skill against F: winner repos"
workflow:
  triggers:
    - cron:
        cron: "0 9 * * 1-5"
  actions: []
  prompts:
    - |
      Load skill: C:\Users\oren\.cursor\skills\security-scan-review\SKILL.md

      Scan (read-only):
      - F:\DevSecOps\projects\doc-power-local-k8s\docker-compose.yml port bindings
      - F:\DevSecOps\projects\cka-ai-bootcamp\bridge_agent.py bind/debug/auth
      - F:\fun4kids — no .env or credentials in git status

      Append findings to F:\ai-workspace\ACTION-LOG.md.
      Do not deploy, prune docker, or delete resources.
  model: ""
  agentOptions:
    skipInstall: false
  memoryEnabled: true
```

**To finish in editor:** Schedule time (9am local), Cloud compute.

---

## How to activate

1. Open Cursor Agents Window.
2. Run `/automate` or use `automate` skill.
3. Paste YAML above as draft, or ask agent to open Automations editor with prefill.
4. Requires `cursor-app-control.open_automation` (Agents Window only).

Replaces legacy Cowork hourly dispatcher + deleted daily IT health task.
