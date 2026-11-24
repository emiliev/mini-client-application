#!/bin/bash
# tool/rules_fork.sh: patch-queue tooling for the rules forks (plan 03 KD2, T-0024).
#
#   tool/rules_fork.sh checkout <repo>   clone the pinned commit into a fork dir, re-apply the
#                                        queued patches as commits, write .bazelrc.user
#   tool/rules_fork.sh export <repo>     turn the fork's commits (pin..HEAD) into numbered patches
#   tool/rules_fork.sh status            pin, queue, fork dir and override per repo
#
# <repo> is ai_rules_dart or ai_rules_flutter. The pin (commit + remote) is read from the
# git_override in MODULE.bazel. Fork dirs live outside the repo (a Bazel package inside it
# would be picked up by //...): $MC_FORK_DIR, default ~/.cache/mc-bazel/forks/<worktree>/<repo>.
# Patches are `git format-patch` files in third_party/rules_patches/<repo>/ (patch_strip = 1).
# Export refuses binary hunks. The final MODULE.bazel must list the exported files in `patches`.
set -euo pipefail

REPO_ROOT="${MC_REPO_ROOT:-$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)}"
MODULE="$REPO_ROOT/MODULE.bazel"
RC_USER="$REPO_ROOT/.bazelrc.user"
QUEUE_ROOT="$REPO_ROOT/third_party/rules_patches"
BEGIN="# >>> rules_fork.sh"
END="# <<< rules_fork.sh"

die() { echo "rules_fork: $*" >&2; exit 1; }

check_repo() {
  case "${1:-}" in
    ai_rules_dart|ai_rules_flutter) ;;
    *) die "unknown repo '${1:-}' (want ai_rules_dart or ai_rules_flutter)" ;;
  esac
}

# pin_field <repo> <commit|remote>: value inside the git_override block of that module.
pin_field() {
  awk -v mod="$1" -v key="$2" '
    /git_override\(/ { inb = 1; found = 0; val = "" }
    inb && $0 ~ "module_name *= *\"" mod "\"" { found = 1 }
    inb && $0 ~ "^[ \t]*" key " *= *\"" { v = $0; sub(/^[^"]*"/, "", v); sub(/".*/, "", v); val = v }
    inb && /^\)/ { if (found && val != "") { print val; exit } inb = 0 }
  ' "$MODULE"
}

fork_dir() {
  if [[ -n "${MC_FORK_DIR:-}" ]]; then echo "$MC_FORK_DIR/$1"
  else echo "$HOME/.cache/mc-bazel/forks/$(basename "$REPO_ROOT")/$1"; fi
}

queue_files() { ls "$QUEUE_ROOT/$1"/[0-9][0-9][0-9][0-9]-*.patch 2>/dev/null || true; }

# Rewrite .bazelrc.user: keep other repos' override lines, set this repo's.
write_override() {  # repo, abs path
  local repo="$1" path="$2" lines=""
  if [[ -f "$RC_USER" ]]; then
    lines="$(grep -E "^common --override_module=" "$RC_USER" | grep -v "override_module=${repo}=" || true)"
  fi
  lines="${lines:+$lines$'\n'}common --override_module=${repo}=${path}"
  {
    echo "$BEGIN (generated; git-ignored)"
    echo "$lines"
    echo "$END"
  } > "$RC_USER"
}

cmd_checkout() {
  local repo="${1:-}"; check_repo "$repo"
  local commit remote dir
  commit="$(pin_field "$repo" commit)"; remote="$(pin_field "$repo" remote)"
  [[ -n "$commit" && -n "$remote" ]] || die "no git_override pin for $repo in MODULE.bazel"
  remote="${MC_FORK_REMOTE:-$remote}"
  dir="$(fork_dir "$repo")"
  [[ ! -e "$dir" ]] || die "$dir already exists; remove it first (or run 'export' to keep its commits)"
  mkdir -p "$(dirname "$dir")"
  git clone --quiet "$remote" "$dir"
  git -C "$dir" checkout --quiet -b fork "$commit"
  local p
  for p in $(queue_files "$repo"); do
    git -C "$dir" -c user.name=fork -c user.email=fork@localhost am --quiet "$p" \
      || die "queued patch $(basename "$p") does not apply to $commit (fork left in $dir)"
  done
  dir="$(cd "$dir" && pwd -P)"
  write_override "$repo" "$dir"
  echo "fork: $dir (branch 'fork', pin $commit, $(queue_files "$repo" | wc -l | tr -d ' ') queued patch(es) applied)"
  echo "wrote $RC_USER (absolute --override_module)"
}

cmd_export() {
  local repo="${1:-}"; check_repo "$repo"
  local commit dir
  commit="$(pin_field "$repo" commit)"; dir="$(fork_dir "$repo")"
  [[ -d "$dir/.git" ]] || die "no fork checkout at $dir (run: tool/rules_fork.sh checkout $repo)"
  [[ -z "$(git -C "$dir" status --porcelain)" ]] || die "fork has uncommitted changes; commit them first ($dir)"
  git -C "$dir" cat-file -e "$commit^{commit}" 2>/dev/null || die "pin $commit not in fork"
  git -C "$dir" merge-base --is-ancestor "$commit" HEAD || die "fork HEAD is not based on pin $commit"
  local bin
  bin="$(git -C "$dir" diff --numstat "$commit" HEAD | awk -F'\t' '$1 == "-" && $2 == "-" { print $3 }')"
  if [[ -n "$bin" ]]; then
    echo "rules_fork: refusing to export, binary change(s) cannot go in a text patch queue:" >&2
    echo "$bin" | sed 's/^/  /' >&2
    exit 1
  fi
  out="$(mktemp -d)"
  trap 'rm -rf "${out:-}"' EXIT
  git -C "$dir" format-patch --quiet --no-signature --zero-commit --no-stat -o "$out" "$commit..HEAD"
  mkdir -p "$QUEUE_ROOT/$repo"
  rm -f "$QUEUE_ROOT/$repo"/[0-9][0-9][0-9][0-9]-*.patch
  local n=0 f
  for f in "$out"/*.patch; do [[ -e "$f" ]] || continue; cp "$f" "$QUEUE_ROOT/$repo/"; n=$((n+1)); done
  echo "exported $n patch(es) to third_party/rules_patches/$repo/"
  echo "MODULE.bazel git_override($repo) must list, with patch_strip = 1:"
  echo "    patches = ["
  for f in $(queue_files "$repo"); do echo "        \"//third_party/rules_patches/$repo:$(basename "$f")\","; done
  echo "    ],"
}

cmd_status() {
  local repo
  for repo in ai_rules_dart ai_rules_flutter; do
    local commit dir n listed
    commit="$(pin_field "$repo" commit)"; dir="$(fork_dir "$repo")"
    n="$(queue_files "$repo" | wc -l | tr -d ' ')"
    listed="$(grep -v '^[[:space:]]*#' "$MODULE" | grep -c "\"//third_party/rules_patches/$repo:" || true)"
    echo "$repo: pin ${commit:0:12}, queue $n patch(es), MODULE.bazel lists $listed"
    if [[ -d "$dir/.git" ]]; then
      echo "  fork: $dir ($(git -C "$dir" rev-list --count "$commit..HEAD" 2>/dev/null || echo '?') commit(s) over pin, $(git -C "$dir" status --porcelain | wc -l | tr -d ' ') dirty file(s))"
    else
      echo "  fork: none (run: tool/rules_fork.sh checkout $repo)"
    fi
    if [[ -f "$RC_USER" ]] && grep -q "override_module=${repo}=" "$RC_USER"; then
      echo "  override: ACTIVE in .bazelrc.user (builds use the fork, not the queue)"
    else
      echo "  override: none (builds use pin + queue)"
    fi
  done
}

case "${1:-}" in
  checkout) shift; cmd_checkout "$@" ;;
  export)   shift; cmd_export "$@" ;;
  status)   cmd_status ;;
  *) sed -n '2,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
