#!/usr/bin/env bash
# auto-push.sh — WSL/Linux; mirrors auto-push.ps1
set -uo pipefail

CONFIG_PATH="${AUTO_PUSH_CONFIG:-/mnt/f/ai-workspace/config/auto-push-repos.json}"
LOG_PATH="${AUTO_PUSH_LOG:-/mnt/f/ai-workspace/ACTION-LOG.md}"
ONLY_PATH="${1:-}"
export CONFIG_PATH ONLY_PATH

log_action() {
  local title="$1" result="$2" detail="$3"
  local date entry
  date="$(date +%Y-%m-%d)"
  [[ -f "$LOG_PATH" ]] || return 0
  entry="
### ${date} — ${title}

| Field | Value |
|---|---|
| **Actor** | auto-push.sh |
| **Action** | Auto-push run |
| **Target** | ${detail} |
| **Result** | ${result} |
| **Next step** | none |

"
  if grep -q "## Log entries" "$LOG_PATH"; then
    tmp="$(mktemp)"
    awk -v ins="$entry" '/^## Log entries/ { print; print ins; next } { print }' "$LOG_PATH" > "$tmp"
    mv "$tmp" "$LOG_PATH"
  else
    printf '%s\n' "$entry" >> "$LOG_PATH"
  fi
}

auth_ok() {
  if [ -n "${GH_TOKEN:-}" ] && gh api user -q .login >/dev/null 2>&1; then return 0; fi
  gh auth status >/dev/null 2>&1
}

ensure_remote() {
  local remote_slug="$1"
  local url="https://github.com/${remote_slug}.git"
  if ! git remote get-url origin >/dev/null 2>&1; then git remote add origin "$url"; fi
}

ahead_count() {
  local branch="$1"
  if ! git rev-parse --abbrev-ref "${branch}@{upstream}" >/dev/null 2>&1; then
    c=$(git rev-list --count "$branch" 2>/dev/null || echo 0)
    if [ "$c" -gt 0 ]; then echo "$c"; else echo 0; fi
    return
  fi
  git rev-list --count "${branch}@{upstream}..${branch}" 2>/dev/null || echo 0
}

repo_exists() { gh repo view "$1" --json name -q .name >/dev/null 2>&1; }

create_repo_if_missing() {
  local remote_slug="$1"
  repo_exists "$remote_slug" && return 0
  echo "  Creating GitHub repo ${remote_slug} ..."
  gh repo create "$remote_slug" --private --source=. --remote=origin --push=false >/dev/null 2>&1 && return 0
  gh repo create "$remote_slug" --private >/dev/null 2>&1 && ensure_remote "$remote_slug" && return 0
  return 1
}

push_one() {
  local repo_path="$1" remote_slug="$2" branch="$3"
  [ -d "$repo_path" ] || { echo "skip:path missing"; return; }
  [ -d "$repo_path/.git" ] || { echo "skip:not a git repo"; return; }
  cd "$repo_path" || { echo "fail:cd"; return; }
  cur=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)
  [ "$cur" = "$branch" ] || { echo "skip:on branch $cur"; return; }
  ensure_remote "$remote_slug"
  ahead=$(ahead_count "$branch")
  [ "$ahead" -gt 0 ] || { echo "ok:nothing to push"; return; }
  create_repo_if_missing "$remote_slug" || { echo "fail:create remote"; return; }
  echo "  Pushing $ahead commit(s) ..."
  git push -u origin "$branch" && echo "ok:pushed $ahead" || echo "fail:push"
}

if [ ! -f "$CONFIG_PATH" ]; then echo "Config not found: $CONFIG_PATH" >&2; exit 1; fi

if ! auth_ok; then
  echo "GitHub auth unavailable. Skipping all pushes."
  detail=$(python3 -c "import json; c=json.load(open('$CONFIG_PATH')); print('; '.join(r['path'] for r in c['repos']))")
  log_action "Auto-push skipped (no auth)" "blocked" "$detail"
  exit 0
fi

[ -n "${GH_TOKEN:-}" ] && gh auth setup-git >/dev/null 2>&1 || true

failures=0
summary=""
while IFS= read -r line; do
  IFS='|' read -r path remote branch <<< "$line"
  echo ""
  echo "[$remote] $path"
  out=$(push_one "$path" "$remote" "$branch")
  echo "  -> $out"
  summary="${summary}${remote}: ${out#*:} | "
  case "$out" in fail:*) failures=$((failures+1));; esac
done < <(python3 -c "
import json, os
cfg=json.load(open(os.environ['CONFIG_PATH']))
only=os.environ.get('ONLY_PATH','').replace(chr(92),'/').rstrip('/')
for r in cfg['repos']:
    p=r['path'].replace(chr(92),'/').rstrip('/')
    if only and p!=only: continue
    print(f\"{p}|{r['remote']}|{r['branch']}\")
")

summary="${summary% | }"
if [ "$failures" -gt 0 ]; then log_action "Auto-push partial/failed" "partial" "$summary"; exit 2; fi
log_action "Auto-push completed" "success" "$summary"
exit 0
