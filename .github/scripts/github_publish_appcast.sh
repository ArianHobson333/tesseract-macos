#!/bin/bash -eu
# Adds a release to the Sparkle appcast in tesseract-updates.
# Usage: github_publish_appcast.sh <dmg_path> <version> <release_url>
#
# Refuses DMGs that aren't notarized and stapled, so users are never offered
# an unnotarized build. The EdDSA private key comes from
# $TESSERACT_SPARKLE_ED_PRIVATE_KEY and is passed to sign_update on stdin.

_dmg="$1"
_version="$2"
_url="$3"
_repo="${APPCAST_REPO_URL:-https://github.com/ArianHobson333/tesseract-updates.git}"
_sign_update="${SPARKLE_SIGN_UPDATE:-sign_update}"
_appcast=mac/appcast-arm64.xml

die() { echo "error: $1" >&2; exit 1; }

[ -n "${TESSERACT_SPARKLE_ED_PRIVATE_KEY:-}" ] || die "TESSERACT_SPARKLE_ED_PRIVATE_KEY is not set"

# Gate: notarized Developer ID, ticket stapled
_assessment=$(spctl -a -vv -t install "$_dmg" 2>&1) || die "$_dmg is not notarized: $_assessment"
grep -q 'source=Notarized Developer ID' <<< "$_assessment" || die "$_dmg is not notarized: $_assessment"
xcrun stapler validate "$_dmg" > /dev/null || die "$_dmg has no stapled ticket"

_tmp="$(mktemp -d)"
trap 'hdiutil detach "$_tmp/mnt" -quiet 2> /dev/null || true; rm -rf "$_tmp"' EXIT

# Versions come from the app itself, which is what Sparkle compares against
hdiutil attach "$_dmg" -readonly -nobrowse -mountpoint "$_tmp/mnt" -quiet
_plist="$_tmp/mnt/Tesseract.app/Contents/Info.plist"
_bundle_version=$(plutil -extract CFBundleVersion raw "$_plist")
_short_version=$(plutil -extract CFBundleShortVersionString raw "$_plist")
_min_macos=$(plutil -extract LSMinimumSystemVersion raw "$_plist")
hdiutil detach "$_tmp/mnt" -quiet

_signature=$(printf '%s' "$TESSERACT_SPARKLE_ED_PRIVATE_KEY" \
  | "$_sign_update" --ed-key-file - "$_dmg") || die "sign_update failed"
grep -q 'sparkle:edSignature=' <<< "$_signature" || die "sign_update gave no signature"

git clone -q --depth 1 "$_repo" "$_tmp/updates"
mkdir -p "$_tmp/updates/mac"
[ -f "$_tmp/updates/$_appcast" ] || printf '%s\n' '<?xml version="1.0" encoding="utf-8"?>' \
  '<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">' \
  '<channel>' '<title>Tesseract</title>' '</channel>' '</rss>' > "$_tmp/updates/$_appcast"

_item="<item>
  <title>Tesseract $_version</title>
  <pubDate>$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')</pubDate>
  <sparkle:version>$_bundle_version</sparkle:version>
  <sparkle:shortVersionString>$_short_version</sparkle:shortVersionString>
  <sparkle:minimumSystemVersion>$_min_macos</sparkle:minimumSystemVersion>
  <enclosure url=\"$_url\" type=\"application/octet-stream\" $_signature/>
</item>"

# Newest item first, right after the channel title
python3 -I - "$_tmp/updates/$_appcast" "$_item" <<'PY'
import sys
path, item = sys.argv[1], sys.argv[2]
text = open(path).read()
anchor = '</title>\n' if '</title>\n' in text else '<channel>\n'
assert anchor in text, 'appcast has no <channel>'
head, tail = text.split(anchor, 1)
open(path, 'w').write(head + anchor + item + '\n' + tail)
PY

git -C "$_tmp/updates" add "$_appcast"
git -C "$_tmp/updates" commit -qm "Tesseract $_version"
git -C "$_tmp/updates" push -q origin HEAD
echo "published Tesseract $_version to $_appcast"
