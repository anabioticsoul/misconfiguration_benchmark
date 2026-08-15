#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GITHUB_FILE_LIMIT=$((100 * 1024 * 1024))

git_repo() {
  git -C "$REPO_ROOT" "$@"
}

require_git_repository() {
  local root
  root="$(git_repo rev-parse --show-toplevel)"
  if [ "$(cd "$root" && pwd)" != "$REPO_ROOT" ]; then
    echo "Error: expected Git repository at $REPO_ROOT" >&2
    return 1
  fi
}

current_branch() {
  local branch
  branch="$(git_repo branch --show-current)"
  if [ -z "$branch" ]; then
    echo "Error: cannot commit from a detached HEAD" >&2
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

staged_paths() {
  git_repo diff --cached --name-only | LC_ALL=C sort -u
}

file_size() {
  if stat -f '%z' "$1" >/dev/null 2>&1; then
    stat -f '%z' "$1"
  else
    stat -c '%s' "$1"
  fi
}

validate_publishable_files() {
  local relative path name size
  while IFS= read -r relative; do
    [ -n "$relative" ] || continue
    path="$REPO_ROOT/$relative"
    [ -f "$path" ] || continue
    name="$(basename "$path")"
    case "$name" in
      .env|id_dsa|id_ecdsa|id_ed25519|id_rsa|*.pem|*.key)
        echo "Error: refusing sensitive filename: $relative" >&2
        return 1
        ;;
    esac
    size="$(file_size "$path")"
    if [ "$size" -ge "$GITHUB_FILE_LIMIT" ]; then
      echo "Error: refusing file at or above 100 MiB: $relative" >&2
      return 1
    fi
    if [ "$size" -le $((2 * 1024 * 1024)) ] && LC_ALL=C grep -Iq . "$path"; then
      if grep -Eq '^(HF_TOKEN|DOCKERHUB_TOKEN|GITHUB_TOKEN|GH_TOKEN|LLM_API_KEY)[[:space:]]*=[[:space:]]*[^[:space:]#]' "$path"; then
        echo "Error: possible credential in $relative" >&2
        return 1
      fi
      if grep -Eq -- '-----BEGIN [A-Z ]*PRIVATE KEY-----' "$path"; then
        echo "Error: possible private key in $relative" >&2
        return 1
      fi
    fi
  done
}

message="feat: update benchmark"
skip_tests=false
dry_run=false

usage() {
  cat <<'EOF'
Usage: scripts/commit_local.sh [options]

Test, stage, and commit changes to the local Git repository.

Options:
  --message <message>  Commit message (default: feat: update benchmark)
  --skip-tests         Do not run the test suite
  --dry-run            Preview without staging or committing
  -h, --help           Show this help
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --message)
      [ "$#" -ge 2 ] || { echo "Error: --message requires a value" >&2; exit 2; }
      message="$2"
      shift 2
      ;;
    --skip-tests) skip_tests=true; shift ;;
    --dry-run) dry_run=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Error: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

require_git_repository
branch="$(current_branch)"
paths="$(changed_paths)"
if [ -z "$paths" ]; then
  echo "Local repository is already clean; there is nothing to commit."
  exit 0
fi
validate_publishable_files <<<"$paths"

echo "Repository: $REPO_ROOT"
echo "Local branch: $branch"
echo "Changes to commit:"
while IFS= read -r path; do
  [ -n "$path" ] && printf '  %s\n' "$path"
done <<<"$paths"
if [ "$dry_run" = "true" ]; then
  echo "Dry run complete; no files were staged or committed."
  exit 0
fi
if [ "$skip_tests" = "false" ]; then
  echo "Running tests..."
  (
    cd "$REPO_ROOT"
    "${PYTHON:-python}" -m unittest discover -s tests
  )
fi
git_repo add --all
validate_publishable_files <<<"$(staged_paths)"
git_repo commit -m "$message"
commit="$(git_repo rev-parse --short HEAD)"
echo "Created local commit $commit on $branch."
