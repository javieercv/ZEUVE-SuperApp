#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
CONFIGURATION="${1:-Release}"
case "$CONFIGURATION" in Debug|Release) ;; *) echo "Configuración no válida: $CONFIGURATION" >&2; exit 2;; esac
if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
  echo "Esta compilación requiere macOS Apple Silicon con Xcode." >&2
  exit 1
fi
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "No se encuentra xcodebuild. Instala o selecciona Xcode." >&2
  exit 1
fi
[[ -f Resources/Engines/engines.json ]] || {
  echo "Los motores todavía no están preparados. Ejecuta primero Scripts/prepare_engines_macos.sh." >&2
  exit 1
}
Scripts/verify_engines_macos.sh
python3 Scripts/generate_xcode_project.py
xcodebuild \
  -project ZEUVE.xcodeproj \
  -scheme ZEUVE \
  -configuration "$CONFIGURATION" \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/DerivedData \
  build

APP_PATH="build/DerivedData/Build/Products/$CONFIGURATION/ZEUVE.app"
Scripts/verify_packaged_engines_macos.sh "$APP_PATH"
