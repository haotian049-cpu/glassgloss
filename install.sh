#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")" && pwd)"
service="$HOME/Library/Services/GlassGloss.service"
agents="$HOME/Library/LaunchAgents"
label=io.github.haotian049-cpu.glassgloss
agent="$agents/$label.plist"
domain="gui/$(id -u)"
job="$domain/$label"
logs="$HOME/Library/Logs"
log="$logs/GlassGloss.log"
legacy_job="$domain/org.local.offlinetranslate.hotkey"
mode="${1:-install}"

if [[ "$(uname -s)" != Darwin || "$(id -u)" == 0 ]]; then
  printf 'Run this installer as your regular macOS user, without sudo.\n' >&2
  exit 1
fi

install_dictionaries() {
  local folder="$HOME/Library/Dictionaries"
  local book name temp bundle_id existing existing_id
  local installed=0 skipped=0
  local -a books
  shopt -s nullglob
  books=("$root"/Payload/Dictionaries/*.dictionary)
  if (( ${#books[@]} == 0 )); then
    printf 'No dictionaries in this download. Use the complete ZIP from GitHub Releases.\n' >&2
    return 1
  fi
  for book in "${books[@]}"; do
    /usr/bin/plutil -lint "$book/Contents/Info.plist" >/dev/null
    /usr/bin/plutil -extract CFBundleIdentifier raw "$book/Contents/Info.plist" >/dev/null
    test -s "$book/Contents/Resources/Body.data"
    test -s "$book/Contents/Resources/KeyText.index"
  done
  mkdir -p "$folder"
  for book in "${books[@]}"; do
    name="${book##*/}"
    bundle_id="$(/usr/bin/plutil -extract CFBundleIdentifier raw "$book/Contents/Info.plist")"
    if [[ -e "$folder/$name" ]]; then
      printf 'Kept existing dictionary: %s\n' "$name"
      ((skipped+=1))
      continue
    fi
    for existing in "$folder"/*.dictionary; do
      existing_id="$(/usr/bin/plutil -extract CFBundleIdentifier raw "$existing/Contents/Info.plist" 2>/dev/null || true)"
      if [[ "$existing_id" == "$bundle_id" ]]; then
        printf 'Kept existing dictionary: %s\n' "${existing##*/}"
        ((skipped+=1))
        continue 2
      fi
    done
    temp="$(mktemp -d "$folder/.glassgloss.XXXXXX")"
    if ! ditto "$book" "$temp/$name" || ! mv -n "$temp/$name" "$folder/$name"; then
      rm -rf "$temp"
      printf 'Could not install dictionary: %s\n' "$name" >&2
      return 1
    fi
    rm -rf "$temp"
    ((installed+=1))
    printf 'Installed dictionary: %s\n' "$name"
  done
  printf '\nDictionaries: %s installed, %s already present.\n' "$installed" "$skipped"
  printf 'Quit and reopen Dictionary, then enable the new sources under Dictionary → Settings.\n'
}

case "$mode" in
  uninstall)
    if launchctl print "$job" >/dev/null 2>&1; then
      launchctl bootout "$job"
    fi
    rm -f "$agent"
    rm -rf "$service"
    /System/Library/CoreServices/pbs -update
    printf 'GlassGloss was removed. Its log, if any, is at %s.\n' "$log"
    exit 0
    ;;
  dictionaries) install_dictionaries; exit 0 ;;
  install|translate|source|build) ;;
  *)
    printf 'Usage: bash install.sh [install|translate|dictionaries|source|build|uninstall]\n' >&2
    exit 2
    ;;
esac

if [[ "$(uname -m)" != arm64 ]]; then
  printf 'GlassGloss requires an Apple silicon Mac.\n' >&2
  exit 1
fi
version="$(sw_vers -productVersion)"
IFS=. read -r major minor _ <<< "$version"
if (( major < 26 || (major == 26 && ${minor:-0} < 4) )); then
  printf 'GlassGloss requires macOS 26.4 or later.\n' >&2
  exit 1
fi
stage="$(mktemp -d "${TMPDIR:-/tmp}/glassgloss.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
bundle="$root/Payload/GlassGloss.service"
if [[ "$mode" == build || "$mode" == source || ! -d "$bundle" ]]; then
  if ! xcrun --find swiftc >/dev/null 2>&1; then
    printf 'Install current Apple Command Line Tools with xcode-select --install, or download the prebuilt ZIP.\n' >&2
    exit 1
  fi
  build="$root/.build"
  mkdir -p "$build"
  bundle="$stage/GlassGloss.service"
  mkdir -p "$bundle/Contents/MacOS"
  cp "$root/Resources/Info.plist" "$bundle/Contents/"
  xcrun swiftc -O -parse-as-library -target arm64-apple-macos26.4 -module-cache-path "$build/module-cache" \
    -o "$bundle/Contents/MacOS/GlassGloss" "$root/Sources/GlassGloss.swift"
  codesign --force --sign - --timestamp=none "$bundle"
fi
codesign --verify --strict "$bundle"

if [[ "$mode" == build ]]; then
  rm -rf "$build/GlassGloss.service"
  mv "$bundle" "$build/"
  printf 'Built and verified %s\n' "$build/GlassGloss.service"
  exit 0
fi

if launchctl print "$legacy_job" >/dev/null 2>&1; then
  printf 'The original OfflineTranslate service is running and uses the same shortcut. Stop it before installing GlassGloss.\n' >&2
  exit 1
fi

mkdir -p "$HOME/Library/Services" "$agents" "$logs"
agent_file="$stage/agent.plist"
/usr/bin/plutil -create xml1 "$agent_file"
/usr/bin/plutil -insert Label -string "$label" "$agent_file"
/usr/bin/plutil -insert ProgramArguments -array "$agent_file"
/usr/bin/plutil -insert ProgramArguments.0 -string "$service/Contents/MacOS/GlassGloss" "$agent_file"
/usr/bin/plutil -insert ProgramArguments.1 -string --listen-hotkey "$agent_file"
/usr/bin/plutil -insert RunAtLoad -bool YES "$agent_file"
/usr/bin/plutil -insert LimitLoadToSessionType -string Aqua "$agent_file"
/usr/bin/plutil -insert StandardErrorPath -string "$log" "$agent_file"

had_service=0
had_agent=0
was_running=0
if [[ -e "$service" ]]; then
  ditto "$service" "$stage/previous.service"
  had_service=1
fi
if [[ -f "$agent" ]]; then
  cp "$agent" "$stage/previous.plist"
  had_agent=1
fi
if launchctl print "$job" >/dev/null 2>&1; then
  launchctl bootout "$job"
  was_running=1
fi

rollback() {
  if launchctl print "$job" >/dev/null 2>&1; then
    launchctl bootout "$job" || true
  fi
  rm -rf "$service"
  rm -f "$agent"
  if (( had_service )); then ditto "$stage/previous.service" "$service"; fi
  if (( had_agent )); then cp "$stage/previous.plist" "$agent"; fi
  if (( was_running )); then launchctl bootstrap "$domain" "$agent" || true; fi
}

offset=0
if [[ -f "$log" ]]; then offset="$(wc -c < "$log")"; fi
if ! rm -rf "$service" || ! ditto "$bundle" "$service" || ! cp "$agent_file" "$agent" ||
   ! launchctl bootstrap "$domain" "$agent"; then
  rollback
  printf 'Unable to start GlassGloss. Restored the previous installation.\n' >&2
  exit 1
fi

registered=0
for ((attempt = 0; attempt < 40; attempt++)); do
  if [[ -f "$log" ]]; then
    registration="$(tail -c "+$((offset + 1))" "$log" | sed -n 's/.*Control+Option+Command+Space registration: //p' | tail -1)"
    if [[ "$registration" == 0 ]]; then registered=1; break; fi
    if [[ -n "$registration" ]]; then break; fi
  fi
  sleep 0.25
done
if (( ! registered )); then
  rollback
  printf 'GlassGloss did not register its shortcut. Check macOS security settings or a shortcut conflict.\n' >&2
  printf 'Log: %s\n' "$log" >&2
  exit 1
fi

/System/Library/CoreServices/pbs -update
printf 'Installed GlassGloss. Select English and press Control+Option+Command+Space.\n'
if [[ "$mode" == install && -d "$root/Payload/Dictionaries" ]]; then
  install_dictionaries
fi
