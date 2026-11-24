#!/bin/bash
# tool/rules_fork.sh: patch-queue tooling for the rules forks (plan 03 KD2, T-0024).
#
#   tool/rules_fork.sh checkout <repo>        clone the pinned commit into a fork dir, re-apply the
#                                             queued patches as commits, write .bazelrc.user
#   tool/rules_fork.sh export [--force] <repo>  turn the fork's commits (pin..HEAD) into numbered patches
#   tool/rules_fork.sh status                 pin, queue, fork dir and override per repo
#   tool/rules_fork.sh check [<repo>]         verify every queued patch applies strictly on the pin
#                                             (git am, no fuzz). Run before merging any queue change.
#
# <repo> is ai_rules_dart or ai_rules_flutter. The pin (commit + remote) is read from the
# git_override in MODULE.bazel. Fork dirs live outside the repo (a Bazel package inside it
# would be picked up by //...): $MC_FORK_DIR, default ~/.cache/mc-bazel/forks/<worktree>-<hash>/<repo>.
# Patches are `git format-patch` files in third_party/rules_patches/<repo>/ (patch_strip = 1).
# Export refuses: binary changes in any commit, merge commits, an unfinished `git am`/rebase,
# a fork HEAD that is not on branch `fork`, and (without --force) fewer patches than the queue has.
# The final MODULE.bazel must list the exported files in `patches`.
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
  if [[ -n "${MC_FORK_DIR:-}" ]]; then echo "$MC_FORK_DIR/$1"; return; fi
  local h; h="$(printf '%s' "$REPO_ROOT" | shasum | cut -c1-10)"
  echo "$HOME/.cache/mc-bazel/forks/$(basename "$REPO_ROOT")-$h/$1"
}

# Fill QUEUE with the queued patch paths (sorted; safe with spaces).
QUEUE=()
load_queue() {
  local old; old="$(shopt -p nullglob || true)"
  shopt -s nullglob
  QUEUE=("$QUEUE_ROOT/$1"/[0-9][0-9][0-9][0-9]-*.patch)
  eval "$old"
}

# Names listed in MODULE.bazel's patches for <repo>, in order (comments ignored).
listed_patches() {
  grep -v '^[[:space:]]*#' "$MODULE" | sed -n "s|.*\"//third_party/rules_patches/$1:\\([^\"]*\\)\".*|\\1|p"
}

# Rewrite only the managed block of .bazelrc.user; everything else is kept as is.
write_override() {  # repo, abs path
  local repo="$1" path="$2" others="" block
  if [[ -f "$RC_USER" ]]; then
    others="$(awk -v b="$BEGIN" -v e="$END" 'index($0,b)==1{i=1;next} index($0,e)==1{i=0;next} i' "$RC_USER" \
      | grep -E '^common --override_module=' | grep -v "override_module=${repo}=" || true)"
  fi
  block="$BEGIN (generated; git-ignored)"$'\n'"${others:+$others$'\n'}common --override_module=${repo}=${path}"$'\n'"$END"
  if [[ -f "$RC_USER" ]] && grep -qF "$BEGIN" "$RC_USER"; then
    BLK="$block" awk -v b="$BEGIN" -v e="$END" '
      index($0,b)==1 { print ENVIRON["BLK"]; skip=1; next }
      skip && index($0,e)==1 { skip=0; next }
      !skip { print }' "$RC_USER" > "$RC_USER.tmp" && mv "$RC_USER.tmp" "$RC_USER"
  else
    { [[ -f "$RC_USER" ]] && cat "$RC_USER"; echo "$block"; } > "$RC_USER.tmp" && mv "$RC_USER.tmp" "$RC_USER"
  fi
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
  load_queue "$repo"
  for p in ${QUEUE[@]+"${QUEUE[@]}"}; do
    git -C "$dir" -c user.name=fork -c user.email=fork@localhost am --quiet "$p" \
      || die "queued patch $(basename "$p") does not apply to $commit (fork left in $dir)"
  done
  dir="$(cd "$dir" && pwd -P)"
  write_override "$repo" "$dir"
  echo "fork: $dir (branch 'fork', pin $commit, ${#QUEUE[@]} queued patch(es) applied)"
  echo "wrote $RC_USER (absolute --override_module)"
}

cmd_export() {
  local force=0
  if [[ "${1:-}" == "--force" ]]; then force=1; shift; fi
  local repo="${1:-}"; check_repo "$repo"
  local commit dir
  commit="$(pin_field "$repo" commit)"; dir="$(fork_dir "$repo")"
  [[ -d "$dir/.git" ]] || die "no fork checkout at $dir (run: tool/rules_fork.sh checkout $repo)"
  local g
  for g in rebase-apply rebase-merge; do
    [[ ! -e "$(git -C "$dir" rev-parse --path-format=absolute --git-path "$g")" ]] \
      || die "unfinished git am/rebase in $dir ($g exists); finish or abort it first"
  done
  [[ "$(git -C "$dir" symbolic-ref --short -q HEAD || true)" == "fork" ]] \
    || die "fork HEAD is not on branch 'fork' ($dir)"
  [[ -z "$(git -C "$dir" status --porcelain)" ]] || die "fork has uncommitted changes; commit them first ($dir)"
  git -C "$dir" cat-file -e "$commit^{commit}" 2>/dev/null || die "pin $commit not in fork"
  git -C "$dir" merge-base --is-ancestor "$commit" HEAD || die "fork HEAD is not based on pin $commit"
  local merges
  merges="$(git -C "$dir" rev-list --merges "$commit..HEAD")"
  [[ -z "$merges" ]] || die "fork has merge commits (format-patch would drop them); rebase them away:
$merges"
  # Per commit, so a binary added and removed again is still caught.
  local bin
  bin="$(git -C "$dir" log --numstat --format= "$commit..HEAD" | awk -F'\t' '$1 == "-" && $2 == "-" { print $3 }' | sort -u)"
  if [[ -n "$bin" ]]; then
    echo "rules_fork: refusing to export, binary change(s) cannot go in a text patch queue:" >&2
    echo "$bin" | sed 's/^/  /' >&2
    exit 1
  fi
  local count
  count="$(git -C "$dir" rev-list --count "$commit..HEAD")"
  load_queue "$repo"
  if [[ $force == 0 && "$count" -lt "${#QUEUE[@]}" ]]; then
    die "fork has $count commit(s) but the queue holds ${#QUEUE[@]} patch(es); exporting would drop some. Re-run checkout, or pass --force"
  fi
  local out; out="$(mktemp -d)"
  trap 'rm -rf "${out:-}"' EXIT
  git -C "$dir" format-patch --quiet --no-signature --zero-commit --no-stat --no-binary -o "$out" "$commit..HEAD"
  if grep -lE '^Binary files |^GIT binary patch' "$out"/*.patch >/dev/null 2>&1; then
    die "export produced a binary hunk; refusing"
  fi
  mkdir -p "$QUEUE_ROOT/$repo"
  rm -f "$QUEUE_ROOT/$repo"/[0-9][0-9][0-9][0-9]-*.patch
  local n=0 f
  for f in "$out"/*.patch; do [[ -e "$f" ]] || continue; cp "$f" "$QUEUE_ROOT/$repo/"; n=$((n+1)); done
  echo "exported $n patch(es) to third_party/rules_patches/$repo/"
  echo "MODULE.bazel git_override($repo) must list, with patch_strip = 1:"
  echo "    patches = ["
  load_queue "$repo"
  for f in ${QUEUE[@]+"${QUEUE[@]}"}; do echo "        \"//third_party/rules_patches/$repo:$(basename "$f")\","; done
  echo "    ],"
}

# check: every queued patch must apply strictly (git am: context must match, no fuzz) on the pin.
# Bazel's own patcher is lenient and can silently drop a stale hunk (F-0022), so run this before
# merging any queue change. Uses the fork dir or the pin cache when it has the pin; else fetches.
cmd_check_one() {
  local repo="$1" commit remote src work p n=0
  commit="$(pin_field "$repo" commit)"; remote="${MC_FORK_REMOTE:-$(pin_field "$repo" remote)}"
  [[ -n "$commit" ]] || die "no git_override pin for $repo in MODULE.bazel"
  load_queue "$repo"
  if [[ ${#QUEUE[@]} -eq 0 ]]; then echo "check $repo: queue empty, OK"; return 0; fi
  src="$(fork_dir "$repo")"
  if ! git -C "$src" cat-file -e "$commit^{commit}" 2>/dev/null; then
    src="${MC_PIN_CACHE:-$HOME/.cache/mc-bazel/pins}/$repo"
    if [[ ! -d "$src/.git" ]]; then mkdir -p "$(dirname "$src")"; git clone --quiet --no-checkout "$remote" "$src"; fi
    git -C "$src" cat-file -e "$commit^{commit}" 2>/dev/null || git -C "$src" fetch --quiet origin "$commit" \
      || die "cannot fetch pin $commit for $repo"
  fi
  work="$(mktemp -d)"
  git clone --quiet --shared --no-checkout "$src" "$work/w"
  git -C "$work/w" checkout --quiet -b check "$commit"
  for p in "${QUEUE[@]}"; do
    if ! git -C "$work/w" -c user.name=check -c user.email=check@localhost am --quiet "$p" >"$work/log" 2>&1; then
      echo "rules_fork: patch $(basename "$p") does not apply strictly on pin ${commit:0:12} ($repo):" >&2
      sed 's/^/  /' "$work/log" >&2
      rm -rf "$work"; return 1
    fi
    n=$((n+1))
  done
  rm -rf "$work"
  echo "check $repo: $n patch(es) apply strictly on pin ${commit:0:12}"
}

cmd_check() {
  local repos=(ai_rules_dart ai_rules_flutter) r rc=0
  if [[ -n "${1:-}" ]]; then check_repo "$1"; repos=("$1"); fi
  for r in "${repos[@]}"; do cmd_check_one "$r" || rc=1; done
  return $rc
}

cmd_status() {
  local repo rc=0
  for repo in ai_rules_dart ai_rules_flutter; do
    local commit dir f queued listed
    commit="$(pin_field "$repo" commit)"; dir="$(fork_dir "$repo")"
    load_queue "$repo"
    queued=""
    for f in ${QUEUE[@]+"${QUEUE[@]}"}; do queued="$queued$(basename "$f")"$'\n'; done
    listed="$(listed_patches "$repo")"$'\n'
    [[ "$listed" == $'\n' ]] && listed=""
    echo "$repo: pin ${commit:0:12}, queue ${#QUEUE[@]} patch(es)"
    if [[ "$queued" == "$listed" ]]; then
      echo "  MODULE.bazel: patches match the queue (names and order)"
    else
      echo "  MODULE.bazel: MISMATCH. queue: [$(echo -n "$queued" | tr '\n' ' ')] listed: [$(echo -n "$listed" | tr '\n' ' ')]"
      rc=1
    fi
    if [[ -d "$dir/.git" ]]; then
      echo "  fork: $dir ($(git -C "$dir" rev-list --count "$commit..HEAD" 2>/dev/null || echo '?') commit(s) over pin, $(git -C "$dir" status --porcelain | wc -l | tr -d ' ') dirty file(s))"
    else
      echo "  fork: none (run: tool/rules_fork.sh checkout $repo)"
    fi
    if [[ -f "$RC_USER" ]] && grep -qE "^common --override_module=${repo}=" "$RC_USER"; then
      echo "  override: ACTIVE in .bazelrc.user (builds use the fork, not the queue)"
    else
      echo "  override: none (builds use pin + queue)"
    fi
  done
  return $rc
}

case "${1:-}" in
  checkout) shift; cmd_checkout "$@" ;;
  export)   shift; cmd_export "$@" ;;
  check)    shift; cmd_check "$@" ;;
  status)   cmd_status ;;
  *) sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
