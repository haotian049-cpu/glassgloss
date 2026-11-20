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

case "${1:-install}" in
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
  install|build) ;;
  *)
    printf 'Usage: bash install.sh [install|build|uninstall]\n' >&2
    exit 2
    ;;
esac

if [[ "$(uname -s)" != Darwin || "$(uname -m)" != arm64 ]]; then
  printf 'GlassGloss requires an Apple silicon Mac.\n' >&2
  exit 1
fi
version="$(sw_vers -productVersion)"
IFS=. read -r major minor _ <<< "$version"
if (( major < 26 || (major == 26 && ${minor:-0} < 4) )); then
  printf 'GlassGloss requires macOS 26.4 or later.\n' >&2
  exit 1
fi
if ! xcrun --find swiftc >/dev/null 2>&1; then
  printf 'Install current Apple Command Line Tools with xcode-select --install, then try again.\n' >&2
  exit 1
fi

build="$root/.build"
mkdir -p "$build"
stage="$(mktemp -d "$build/stage.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
bundle="$stage/GlassGloss.service"
mkdir -p "$bundle/Contents/MacOS"
cp "$root/Resources/Info.plist" "$bundle/Contents/"
xcrun swiftc -O -parse-as-library -target arm64-apple-macos26.4 -module-cache-path "$build/module-cache" \
  -o "$bundle/Contents/MacOS/GlassGloss" "$root/Sources/GlassGloss.swift"
codesign --force --sign - --timestamp=none "$bundle"
codesign --verify --strict "$bundle"

if [[ "${1:-install}" == build ]]; then
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
  printf 'Could not register Control+Option+Command+Space. Check whether another tool uses that shortcut.\n' >&2
  exit 1
fi

/System/Library/CoreServices/pbs -update
printf 'Installed GlassGloss. Select English and press Control+Option+Command+Space.\n'
