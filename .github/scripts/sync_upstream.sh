#!/bin/bash -eu
# Merges the newest Helium release into Tesseract.
# Run from the root of a tesseract-macos checkout with the submodule.
#
# Writes status=up-to-date|pending|merged|conflict and tag=<tag> to $GITHUB_OUTPUT.
# On merged: our core main gets the merged Helium core, and branch
# sync/<tag> in this repo points at it (opened as a PR by the workflow).
# On conflict: nothing is pushed and the script exits 1.

_upstream_macos="${UPSTREAM_MACOS_URL:-https://github.com/imputnet/helium-macos.git}"
_upstream_core="${UPSTREAM_CORE_URL:-https://github.com/imputnet/helium.git}"
_core=helium-chromium

output() { echo "$1" | tee -a "$GITHUB_OUTPUT"; }

ensure_remote() {
  # $1 - repo dir; $2 - url
  if git -C "$1" remote get-url upstream > /dev/null 2>&1; then
    git -C "$1" remote set-url upstream "$2"
  else
    git -C "$1" remote add upstream "$2"
  fi
}

conflict() {
  echo "error: $1" >&2
  git merge --abort > /dev/null 2>&1 || true
  git -C "$_core" merge --abort > /dev/null 2>&1 || true
  output "status=conflict"
  exit 1
}

ensure_remote . "$_upstream_macos"
ensure_remote "$_core" "$_upstream_core"
git fetch -q --no-recurse-submodules upstream --tags
git fetch -q --no-recurse-submodules origin

# Newest upstream release tag (numeric tags only)
_tag=$(git ls-remote --tags --refs upstream | sed 's#.*refs/tags/##' \
  | grep -E '^[0-9]+(\.[0-9]+)*$' | sort -V | tail -1)
[ -n "$_tag" ] || conflict "no release tags found upstream"
output "tag=$_tag"

if git merge-base --is-ancestor "refs/tags/$_tag" origin/main; then
  output "status=up-to-date"
  exit 0
fi

# A sync PR for this tag is already open
if git ls-remote --exit-code --heads origin "sync/$_tag" > /dev/null; then
  output "status=pending"
  exit 0
fi

# Core: merge the Helium core commit that the upstream release pins
_upstream_core_commit=$(git rev-parse "refs/tags/$_tag:$_core")
[ "$(git -C "$_core" rev-parse --is-shallow-repository)" = false ] || git -C "$_core" fetch -q --unshallow origin
git -C "$_core" fetch -q upstream
git -C "$_core" fetch -q origin
git -C "$_core" checkout -q -B "sync/$_tag" origin/main
git -C "$_core" merge -q --no-edit -m "sync: Helium $_tag" "$_upstream_core_commit" \
  || conflict "core merge failed for $_tag"
_merged_core=$(git -C "$_core" rev-parse HEAD)

# macOS repo: merge the tag; the submodule pointer is expected to differ
git checkout -q -B "sync/$_tag" origin/main
_our_gitmodules=$(git show origin/main:.gitmodules)
if ! git merge -q --no-commit --no-ff "refs/tags/$_tag" > /dev/null 2>&1; then
  _unmerged=$(git diff --name-only --diff-filter=U)
  [ "$_unmerged" = "$_core" ] || conflict "macOS merge failed for $_tag: $_unmerged"
fi
printf '%s\n' "$_our_gitmodules" > .gitmodules
git -C "$_core" checkout -q "$_merged_core"
git add .gitmodules "$_core"
git commit -q --no-edit -m "sync: Helium $_tag"

git -C "$_core" push -q origin "$_merged_core:refs/heads/main"
git push -q origin "sync/$_tag"
output "status=merged"
