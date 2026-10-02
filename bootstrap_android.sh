#!/usr/bin/env bash
# Regenerates the Android host project. Only needed when android/ is missing:
# the committed android/ folder contains custom code (MainActivity channels,
# manifest permissions, notification receivers, backup rules, signing) that a
# fresh `flutter create` would not have.
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is not installed or is not on PATH." >&2
  exit 1
fi

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -d "$project_root/android" ]]; then
  echo "android/ already exists; nothing to do." >&2
  echo "It contains custom code, so this script will not overwrite it." >&2
  echo "To regenerate anyway, move android/ aside first and re-apply its" >&2
  echo "customizations (see README.md) afterwards." >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

flutter create \
  --platforms=android \
  --project-name=adl_reminder \
  --org=et.adlreminder \
  "$tmp_dir/adl_reminder"

cp -R "$tmp_dir/adl_reminder/android" "$project_root/android"
[[ -f "$project_root/.metadata" ]] || cp "$tmp_dir/adl_reminder/.metadata" "$project_root/.metadata"

echo "Android host project created. Re-apply the customizations listed in"
echo "README.md, then run:"
echo "  flutter pub get"
echo "  flutter test"
echo "  flutter run"
