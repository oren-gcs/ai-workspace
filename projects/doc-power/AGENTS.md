# Doc Power Platform — Agent Company

**Charter:** Build and monetize a document processing SaaS. Local execution on `F:\DevSecOps\projects\doc-power-local-k8s`.

## Team

| Agent | Focus |
|-------|-------|
| **PM** | Backlog, blockers, revenue milestones |
| **Developer** | Microservices, APIs, frontend |
| **DevOps** | Docker compose, K8s, Helm, CI |
| **QA** | test_deployment.py, integration tests |
| **Security** | Port bindings, secrets, scan review |
| **Learning Coach** | K8s skills ↔ CKA study portal |

## Paths

- **Code:** `local/` → `F:\DevSecOps\projects\doc-power-local-k8s`
- **Claude history:** `claude/README.md`
- **Team config:** `agents/team.yaml`

## Revenue path

1. Push repo to GitHub (blocked: gh auth)
2. Bind services to localhost
3. Demo deployment + landing page
4. Pilot customer / internal GCS-tech use case

## Invoke PM

```powershell
cd F:\ai-workspace\lib\agent-class
npm run pm -- doc-power --dry-run "Review P0 blockers"
```
