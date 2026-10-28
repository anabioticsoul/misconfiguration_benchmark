#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

git_repo() {
  git -C "$REPO_ROOT" "$@"
}

require_git_repository() {
  local root
  root="$(git_repo rev-parse --show-toplevel)"
  if [ "$(cd "$root" && pwd -P)" != "$REPO_ROOT" ]; then
    echo "Error: expected Git repository at $REPO_ROOT" >&2
    return 1
  fi
}

current_branch() {
  local branch
  branch="$(git_repo branch --show-current)"
  if [ -z "$branch" ]; then
    echo "Error: cannot publish from a detached HEAD" >&2
    return 1
  fi
  printf '%s\n' "$branch"
}

changed_paths() {
  {
    git_repo ls-files --modified --deleted --others --exclude-standard
    git_repo diff --cached --name-only
  } | LC_ALL=C sort -u
}

is_github_remote() {
  case "$1" in
    https://github.com/*/*|git@github.com:*/*|ssh://git@github.com/*/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

remote="origin"
requested_branch=""
dry_run=false

usage() {
  cat <<'EOF'
Usage: scripts/publish_github.sh [options]

Push the clean current branch to an existing GitHub remote.

Options:
  --remote <name>  Git remote (default: origin)
  --branch <name>  Branch to push (default: current branch)
  --dry-run        Validate without pushing
  -h, --help       Show this help
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --remote)
      [ "$#" -ge 2 ] || { echo "Error: --remote requires a value" >&2; exit 2; }
      remote="$2"
      shift 2
      ;;
    --branch)
      [ "$#" -ge 2 ] || { echo "Error: --branch requires a value" >&2; exit 2; }
      requested_branch="$2"
      shift 2
      ;;
    --dry-run) dry_run=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Error: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

require_git_repository
current="$(current_branch)"
branch="${requested_branch:-$current}"
if [ "$branch" != "$current" ]; then
  echo "Error: requested branch '$branch' is not checked out; current branch is '$current'" >&2
  exit 1
fi
if [ -n "$(changed_paths)" ]; then
  echo "Error: working tree has uncommitted changes. Run scripts/commit_local.sh first." >&2
  exit 1
fi
remote_url="$(git_repo remote get-url --push "$remote" 2>/dev/null)" || {
  echo "Error: Git remote does not exist: $remote" >&2
  exit 1
}
if ! is_github_remote "$remote_url"; then
  echo "Error: remote '$remote' is not a GitHub URL: $remote_url" >&2
  exit 1
fi

echo "Repository: $REPO_ROOT"
echo "Destination: $remote ($remote_url)"
echo "Branch: $branch"
bash "$REPO_ROOT/scripts/commit_local.sh" --check-index
if [ "$dry_run" = "true" ]; then
  echo "Dry run complete; no commits were pushed."
  exit 0
fi
echo "Pushing $branch to $remote..."
git_repo push --set-upstream "$remote" "$branch"
echo "Published successfully: $remote_url ($branch)"
