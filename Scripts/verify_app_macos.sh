#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "$(uname -s)" != "Darwin" ]] || [[ "$(uname -m)" != "arm64" ]] || ! command -v xcodebuild >/dev/null 2>&1; then
  echo "Validación real de ZEUVE.app omitida: el entorno no es macOS Apple Silicon con Xcode."
  exit 0
fi

Scripts/verify_engines_macos.sh
python3 Scripts/generate_xcode_project.py
python3 Scripts/verify/xcode_integration.py

xcodebuild \
  -project ZEUVE.xcodeproj \
  -scheme ZEUVE \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
