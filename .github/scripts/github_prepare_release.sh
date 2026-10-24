#!/bin/bash -eux

_root_dir="$(dirname "$(greadlink -f "$0")")"
_main_repo="$_root_dir/helium-chromium"

_helium_version=$(python3 "$_main_repo/utils/helium_version.py" --tree "$_main_repo" --platform-tree "$_root_dir" --print)

_file_name_base="tesseract_${_helium_version}"
_arm64_file_name="${_file_name_base}_arm64-macos.dmg"

echo "arm64_file_name=$_arm64_file_name" >> $GITHUB_OUTPUT
# Prefixed so it never collides with the Helium tags merged from upstream
echo "release_tag_version=tesseract-$_helium_version" >> $GITHUB_OUTPUT
echo "release_name=Tesseract $_helium_version" >> $GITHUB_OUTPUT
echo "version=$_helium_version" >> $GITHUB_OUTPUT
