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

python3 Scripts/check_social_engines.py Resources/Engines || {
  echo "Faltan gallery-dl o instaloader-zeuve. Ejecuta primero Scripts/prepare_social_engines_macos.sh Resources/Engines." >&2
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
  clean build

APP_PATH="build/DerivedData/Build/Products/$CONFIGURATION/ZEUVE.app"
python3 - "$APP_PATH" <<'PY'
from pathlib import Path
import plistlib
import sys
import re
import subprocess
version = Path("VERSION").read_text().strip().split(".")
with (Path(sys.argv[1]) / "Contents/Info.plist").open("rb") as stream:
    info = plistlib.load(stream)
actual = [info.get("CFBundleShortVersionString"), info.get("ZEUVEReleaseRevision")]
expected = [".".join(version[:3]), version[3]]
if actual != expected:
    raise SystemExit(f"La versión del bundle no coincide con VERSION: {actual!r} != {expected!r}")
signature = subprocess.run(["/usr/bin/codesign", "-d", "--verbose=4", sys.argv[1]], capture_output=True, text=True, check=True)
flags = re.search(r"flags=0x([0-9a-fA-F]+)", signature.stderr)
if not flags or int(flags.group(1), 16) & 0x10000 == 0:
    raise SystemExit("La firma final no incluye Hardened Runtime.")
entitlements = subprocess.run(["/usr/bin/codesign", "-d", "--entitlements", ":-", sys.argv[1]], capture_output=True, check=True)
authorizations = plistlib.loads(entitlements.stdout)
if authorizations.get("com.apple.security.device.audio-input") is not True:
    raise SystemExit("Falta Audio Input en la firma efectiva de ZEUVE.")
if authorizations.get("com.apple.security.app-sandbox"):
    raise SystemExit("No está aprobado activar App Sandbox.")
print("Hardened Runtime y entitlements efectivos verificados.")
print(f"Versión del bundle verificada: {'.'.join(version)} (build {info.get('CFBundleVersion')})")
PY
Scripts/verify_packaged_engines_macos.sh "$APP_PATH"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_PATH"
