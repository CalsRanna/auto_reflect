#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

VERSION="$(awk '/^version:[[:space:]]*/ { sub(/^version:[[:space:]]*/, ""); print; exit }' pubspec.yaml)"

if [[ -z "$VERSION" ]]; then
  echo "Could not read version from pubspec.yaml" >&2
  exit 1
fi

mkdir -p build
dart compile exe -DJOURNAL_VERSION="$VERSION" bin/auto_reflect.dart -o build/journal
