#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is not installed or is not on PATH." >&2
  exit 1
fi

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

flutter create \
  --platforms=android \
  --project-name=adl_reminder \
  --org=et.adlreminder \
  "$tmp_dir/adl_reminder"

rm -rf "$project_root/android"
cp -R "$tmp_dir/adl_reminder/android" "$project_root/android"
cp "$tmp_dir/adl_reminder/.metadata" "$project_root/.metadata"

echo "Android host project created. Next run:"
echo "  flutter pub get"
echo "  flutter test"
echo "  flutter run"
