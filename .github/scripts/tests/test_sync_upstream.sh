#!/bin/bash -eu
# Tests sync_upstream.sh against local bare repos standing in for
# imputnet (upstream) and ArianHobson333 (origin).

_script="$(cd "$(dirname "$0")/.." && pwd)/sync_upstream.sh"
_tmp="$(mktemp -d)"
trap 'rm -rf "$_tmp"' EXIT

export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
export GIT_CONFIG_COUNT=2
export GIT_CONFIG_KEY_0=protocol.file.allow GIT_CONFIG_VALUE_0=always
export GIT_CONFIG_KEY_1=init.defaultBranch GIT_CONFIG_VALUE_1=main

_failures=0
fail() { echo "FAIL: $*"; _failures=$((_failures + 1)); }
pass() { echo "ok: $*"; }

bare() { git init -q --bare "$_tmp/$1.git"; }

setup() {
  bare up_core; bare up_macos; bare our_core; bare our_macos

  git clone -q "$_tmp/up_core.git" "$_tmp/w_up_core"
  (cd "$_tmp/w_up_core" && printf 'a.patch\n' > series && git add series &&
    git commit -qm base && git push -q origin main)

  git clone -q "$_tmp/up_macos.git" "$_tmp/w_up_macos"
  (cd "$_tmp/w_up_macos" &&
    git submodule -q add "$_tmp/up_core.git" helium-chromium &&
    printf 'm.patch\n' > series && echo 1 > revision.txt &&
    git add . && git commit -qm base && git tag 1.0 && git push -q --tags origin main)

  # Our forks: upstream history plus one Tesseract commit each
  git -C "$_tmp/w_up_core" push -q "$_tmp/our_core.git" main
  git clone -q "$_tmp/our_core.git" "$_tmp/w_our_core"
  (cd "$_tmp/w_our_core" && printf 'tesseract.patch\n' >> series &&
    git commit -qam "feat: tesseract core" && git push -q origin main)

  git -C "$_tmp/w_up_macos" push -q --tags "$_tmp/our_macos.git" main
  git clone -q "$_tmp/our_macos.git" "$_tmp/w_our_macos"
  (cd "$_tmp/w_our_macos" &&
    git submodule -q set-url helium-chromium "$_tmp/our_core.git" &&
    git submodule -q update --init &&
    git -C helium-chromium checkout -q origin/main &&
    printf 'tesseract-macos.patch\n' >> series &&
    git add . && git commit -qm "feat: tesseract macos" && git push -q origin main)
}

# Fresh CI-like checkout of our macos repo, then run the sync
run_sync() {
  rm -rf "$_tmp/ci" "$_tmp/out"
  git clone -q --recurse-submodules "$_tmp/our_macos.git" "$_tmp/ci"
  touch "$_tmp/out"
  set +e
  (cd "$_tmp/ci" && GITHUB_OUTPUT="$_tmp/out" \
    UPSTREAM_MACOS_URL="$_tmp/up_macos.git" UPSTREAM_CORE_URL="$_tmp/up_core.git" \
    "$_script" > "$_tmp/log" 2>&1)
  _rc=$?
  set -e
}

has_branch() { git -C "$_tmp/$1.git" rev-parse -q --verify "refs/heads/$2" > /dev/null; }

setup

# (a) no new tag
run_sync
grep -qx 'status=up-to-date' "$_tmp/out" && [ "$_rc" -eq 0 ] \
  && pass "no new tag is up-to-date" || fail "no new tag: rc=$_rc $(cat "$_tmp/out")"
has_branch our_macos sync/1.0 && fail "up-to-date created a branch" || pass "up-to-date pushes nothing"

# (b) new tag that merges cleanly
(cd "$_tmp/w_up_core" && echo fix > b.txt && git add b.txt &&
  git commit -qm "security fix" && git push -q origin main)
(cd "$_tmp/w_up_macos" && git -C helium-chromium pull -q origin main &&
  echo 2 > revision.txt && git add . && git commit -qm "update: 1.1" &&
  git tag 1.1 && git push -q --tags origin main)
run_sync
grep -qx 'status=merged' "$_tmp/out" && grep -qx 'tag=1.1' "$_tmp/out" && [ "$_rc" -eq 0 ] \
  && pass "new tag merges" || fail "merge: rc=$_rc $(cat "$_tmp/out") $(cat "$_tmp/log")"
has_branch our_macos sync/1.1 && pass "sync/1.1 pushed" || fail "sync/1.1 missing"
_ptr=$(git -C "$_tmp/our_macos.git" rev-parse "sync/1.1:helium-chromium" 2>/dev/null || true)
_core_main=$(git -C "$_tmp/our_core.git" rev-parse main)
[ "$_ptr" = "$_core_main" ] && pass "submodule points at our merged core" || fail "pointer $_ptr != core main $_core_main"
git -C "$_tmp/our_core.git" show main:b.txt > /dev/null 2>&1 \
  && git -C "$_tmp/our_core.git" show main:series | grep -qx tesseract.patch \
  && pass "core keeps both upstream fix and our patch" || fail "core merge content"
git -C "$_tmp/our_macos.git" show sync/1.1:.gitmodules | grep -q our_core \
  && pass ".gitmodules still points at our core" || fail ".gitmodules repointed"

# (b2) rerun while the sync PR is still open
run_sync
grep -qx 'status=pending' "$_tmp/out" && [ "$_rc" -eq 0 ] \
  && pass "open sync branch is left alone" || fail "rerun: rc=$_rc $(cat "$_tmp/out") $(cat "$_tmp/log")"

# (c) new tag that conflicts in the macos series file
(cd "$_tmp/w_up_macos" && printf 'upstream-new.patch\n' >> series &&
  git commit -qam "update: 1.2" && git tag 1.2 && git push -q --tags origin main)
run_sync
grep -qx 'status=conflict' "$_tmp/out" && [ "$_rc" -ne 0 ] \
  && pass "conflict reported and fails" || fail "conflict: rc=$_rc $(cat "$_tmp/out")"
has_branch our_macos sync/1.2 && fail "conflict pushed a branch" || pass "conflict pushes nothing"

[ "$_failures" -eq 0 ] && echo "all passed" || { echo "$_failures failed"; exit 1; }
