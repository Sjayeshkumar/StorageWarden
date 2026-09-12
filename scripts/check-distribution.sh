#!/bin/bash
set -euo pipefail
app="${1:?Pass the path of a distribution app}"
codesign --verify --deep --strict "$app"
lipo "$app/Contents/MacOS/StorageWarden" -verify_arch arm64 x86_64
entitlements=$(mktemp)
details=$(mktemp)
trap 'rm -f "$entitlements" "$details"' EXIT
codesign -d --entitlements - --xml "$app" > "$entitlements" 2> "$details"
if [ -s "$entitlements" ]; then
  plutil -lint "$entitlements" > /dev/null
  for key in com.apple.security.get-task-allow com.apple.security.cs.disable-library-validation com.apple.security.cs.allow-dyld-environment-variables com.apple.security.cs.allow-unsigned-executable-memory; do
    value=$(/usr/libexec/PlistBuddy -c "Print :$key" "$entitlements" 2>/dev/null || true)
    if [ -n "$value" ] && [ "$value" != false ]; then
      printf 'Refusing distribution: unsafe entitlement %s\n' "$key" >&2
      exit 1
    fi
  done
fi
codesign -dv "$app" 2> "$details"
if ! grep -q 'flags=.*runtime' "$details"; then
  printf 'Refusing distribution: hardened runtime is missing.\n' >&2
  exit 1
fi
printf 'Distribution safeguards passed (this does not certify notarization).\n'
