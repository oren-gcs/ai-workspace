# Agent company integration

Brain is the **meta-orchestration project** of the ai-workspace agent company.

## Manifest

`F:\_archive\_inventory\project-agents-manifest.json`

## Project teams

| Slug | Workspace | Monetization |
|------|-----------|--------------|
| doc-power | `projects/doc-power` | SaaS document processing |
| fun4kids | `projects/fun4kids` | Kids app subscriptions |
| my-study-portal | `projects/my-study-portal` | CKA/MLOps courseware |
| gcs-tech | `projects/gcs-tech` | DevSecOps consulting |
| grok-social-bot | `projects/grok-social-bot` | Social listening alerts |
| brain | `projects/brain` | Enables all (meta) |

## Invoke project PM

```powershell
cd F:\ai-workspace\lib\agent-class
npm run pm -- doc-power --dry-run "Check docker health"
npm run pm -- brain --dry-run "Drain queue"
```

## Architecture doc

`F:\_archive\_inventory\agent-company-architecture-2026-08-28.md`

## IntegrationArchivist role

Maintains knowledge graph hygiene, merges session artifacts, updates manifest when projects scaffold.
