#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "$#" != 2 ]]; then
  printf 'Usage: bash scripts/package.sh DICTIONARY_DIRECTORY OUTPUT_DIRECTORY\n' >&2
  exit 2
fi
dicts="$(cd "$1" && pwd)"
mkdir -p "$2"
output="$(cd "$2" && pwd)"
version="$(/usr/bin/plutil -extract CFBundleShortVersionString raw "$root/Resources/Info.plist")"
name="GlassGloss-$version-apple-silicon"
zip="$output/$name.zip"
stage="$(mktemp -d "${TMPDIR:-/tmp}/glassgloss-package.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
package="$stage/$name"
mkdir -p "$package/Payload/Dictionaries" "$package/Resources" "$package/Sources" "$package/docs"

bash "$root/install.sh" build
for file in install.sh Install.command LICENSE README.md README.zh-CN.md; do
  cp -p "$root/$file" "$package/"
done
cp "$root/Resources/Info.plist" "$package/Resources/"
cp "$root/Sources/GlassGloss.swift" "$package/Sources/"
cp -R "$root/docs/cover.png" "$root/docs/THIRD-PARTY.md" "$root/docs/licenses" "$package/docs/"
ditto --norsrc "$root/.build/GlassGloss.service" "$package/Payload/GlassGloss.service"
books=(
  'ECDICT 简明英汉字典.dictionary'
  'Google AI 术语（英汉）.dictionary'
  'MDN 编程术语（英汉）.dictionary'
  'Python 术语（英汉）.dictionary'
)
for book in "${books[@]}"; do
  test -s "$dicts/$book/Contents/Info.plist"
  test -s "$dicts/$book/Contents/Resources/Body.data"
  test -s "$dicts/$book/Contents/Resources/KeyText.index"
  ditto --norsrc "$dicts/$book" "$package/Payload/Dictionaries/$book"
done
cp "$root/docs/THIRD-PARTY.md" "$package/Payload/Dictionaries/"
cp "$root/docs/licenses/"*.txt "$package/Payload/Dictionaries/"
cp "$root/docs/FIRST-RUN.txt" "$package/开始使用 · Start here.txt"
ditto -c -k --norsrc --keepParent "$package" "$stage/$name.zip"
mv "$stage/$name.zip" "$zip"
(cd "$output" && shasum -a 256 "$name.zip" > SHA256SUMS.txt)
printf '%s\n' "$zip"
