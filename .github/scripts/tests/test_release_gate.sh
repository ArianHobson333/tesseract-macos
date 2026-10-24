#!/bin/bash -eu
# An unsigned DMG must never reach the appcast.

_script="$(cd "$(dirname "$0")/.." && pwd)/github_publish_appcast.sh"
_tmp="$(mktemp -d)"
trap 'rm -rf "$_tmp"' EXIT

export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

_failures=0
fail() { echo "FAIL: $*"; _failures=$((_failures + 1)); }
pass() { echo "ok: $*"; }

# Fake appcast repo
git init -q --bare -b main "$_tmp/updates.git"
git clone -q "$_tmp/updates.git" "$_tmp/w" 2> /dev/null
mkdir -p "$_tmp/w/mac"
printf '<?xml version="1.0"?>\n<rss><channel></channel></rss>\n' > "$_tmp/w/mac/appcast-arm64.xml"
(cd "$_tmp/w" && git add . && git commit -qm init && git push -q origin main)
_before=$(git -C "$_tmp/updates.git" rev-parse main)

hdiutil create -quiet -size 1m -fs APFS -volname Tesseract "$_tmp/unsigned.dmg"

run() {
  set +e
  APPCAST_REPO_URL="$_tmp/updates.git" "$_script" "$_tmp/unsigned.dmg" 0.0.1 \
    https://example.com/unsigned.dmg > "$_tmp/log" 2>&1
  _rc=$?
  set -e
}

TESSERACT_SPARKLE_ED_PRIVATE_KEY=dummy run
[ "$_rc" -ne 0 ] && grep -q "not notarized" "$_tmp/log" && pass "unsigned DMG rejected" || fail "unsigned DMG accepted: $(cat "$_tmp/log")"
[ "$(git -C "$_tmp/updates.git" rev-parse main)" = "$_before" ] \
  && pass "appcast unchanged" || fail "appcast changed"

TESSERACT_SPARKLE_ED_PRIVATE_KEY= run
[ "$_rc" -ne 0 ] && grep -q "TESSERACT_SPARKLE_ED_PRIVATE_KEY" "$_tmp/log" \
  && pass "missing key rejected" || fail "missing key: rc=$_rc $(cat "$_tmp/log")"
grep -q dummy "$_tmp/log" && fail "key echoed to log" || pass "key not echoed"

[ "$_failures" -eq 0 ] && echo "all passed" || { echo "$_failures failed"; exit 1; }
