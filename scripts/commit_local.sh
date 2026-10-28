#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
GITHUB_FILE_LIMIT=$((100 * 1024 * 1024))

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

is_public_test_key() {
  # Public localhost fixture only; a replaced key must fail the audit.
  [ "$1" = "instances/CA/CA41/build/context/base-overlay/etc/nginx/ssl/server.key" ] || return 1
  [ "$(shasum -a 256 "$2" | awk '{print $1}')" = "f8fc33770a04a618c2f58c7be2a040eb7cbe75011b7c7aa25ccedf0254671452" ]
}

validate_publishable_files() {
  local relative path name size
  while IFS= read -r relative; do
    [ -n "$relative" ] || continue
    path="$REPO_ROOT/$relative"
    [ -f "$path" ] || continue
    if is_public_test_key "$relative" "$path"; then continue; fi
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
      if grep -Eq -- '^[[:space:]]*-----BEGIN [A-Z ]*PRIVATE KEY-----' "$path"; then
        echo "Error: possible private key in $relative" >&2
        return 1
      fi
    fi
  done
}

validate_index() {
  local relative size temporary
  temporary="$(mktemp)"
  while IFS= read -r -d '' relative; do
    case "$relative" in
      runs/*|logs/*|dist/*|assets/*|*/image/*|*/workspace/*|*/.eval-*|*.tar|*.tar.gz|*.tgz)
        echo "Error: generated/dataset artifact is tracked: $relative" >&2
        rm -f "$temporary"; return 1 ;;
    esac
    if git_repo check-ignore --no-index -q -- "$relative"; then
      echo "Error: ignored file is still tracked: $relative" >&2
      rm -f "$temporary"; return 1
    fi
    size="$(git_repo cat-file -s ":$relative")"
    if [ "$size" -ge "$GITHUB_FILE_LIMIT" ]; then
      echo "Error: staged file at or above 100 MiB: $relative" >&2
      rm -f "$temporary"; return 1
    fi
    git_repo show ":$relative" > "$temporary"
    if is_public_test_key "$relative" "$temporary"; then continue; fi
    if LC_ALL=C grep -Eq -- '^[[:space:]]*-----BEGIN [A-Z ]*PRIVATE KEY-----|(^|[^A-Za-z0-9])(hf_[A-Za-z0-9]{25,}|gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|dckr_pat_[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9_-]{30,})' "$temporary"; then
      echo "Error: possible credential/private key in staged file: $relative" >&2
      rm -f "$temporary"; return 1
    fi
  done < <(git_repo ls-files -z)
  rm -f "$temporary"
}

message="feat: update benchmark"
skip_tests=false
dry_run=false
check_index=false

usage() {
  cat <<'EOF'
Usage: scripts/commit_local.sh [options]

Test, stage, and commit changes to the local Git repository.

Options:
  --message <message>  Commit message (default: feat: update benchmark)
  --skip-tests         Do not run the test suite
  --dry-run            Preview without staging or committing
  --check-index        Audit staged/tracked files only; do not commit
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
    --check-index) check_index=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Error: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

require_git_repository
if [ "$check_index" = "true" ]; then
  validate_index
  exit 0
fi
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
validate_index
git_repo commit -m "$message"
commit="$(git_repo rev-parse --short HEAD)"
echo "Created local commit $commit on $branch."
