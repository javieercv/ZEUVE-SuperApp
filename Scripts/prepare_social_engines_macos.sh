#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGING="${1:?Indica el directorio staging de Resources/Engines}"
BUILD_ROOT="${2:-${TMPDIR:-/tmp}/ZEUVE-social-engines}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
GALLERY_DL_VERSION="1.32.9"
INSTALOADER_VERSION="4.15.3"
INSTALOADER_ZEUVE_VERSION="4.15.3-zeuve.2"
BROWSER_COOKIE3_VERSION="0.20.1"
PYINSTALLER_VERSION="6.16.0"

fail() { echo "ERROR: $*" >&2; exit 1; }
command -v "$PYTHON_BIN" >/dev/null 2>&1 || fail "No se encuentra Python 3 para preparar los motores sociales."
[[ "$(uname -s)" == "Darwin" && "$(uname -m)" == "arm64" ]] || fail "Los motores sociales deben prepararse en macOS Apple Silicon."
[[ -f "$ROOT/Scripts/engine_helpers/gallery_dl_main.py" ]] || fail "Falta gallery_dl_main.py."
[[ -f "$ROOT/Scripts/engine_helpers/instagram_catalog.py" ]] || fail "Falta instagram_catalog.py."

VENV="$BUILD_ROOT/venv"
DIST="$BUILD_ROOT/dist"
WORK="$BUILD_ROOT/work"
SPEC="$BUILD_ROOT/spec"
rm -rf "$VENV" "$DIST" "$WORK" "$SPEC" "$STAGING/gallery-dl" "$STAGING/instaloader"
mkdir -p "$BUILD_ROOT" "$STAGING/gallery-dl" "$STAGING/instaloader" \
  "$STAGING/licenses/gallery-dl" "$STAGING/licenses/instaloader" "$STAGING/licenses/browser-cookie3"

"$PYTHON_BIN" -m venv "$VENV"
"$VENV/bin/python" -m pip install --disable-pip-version-check --no-input --upgrade "pip<26"
"$VENV/bin/python" -m pip install --disable-pip-version-check --no-input \
  "gallery-dl==$GALLERY_DL_VERSION" \
  "instaloader==$INSTALOADER_VERSION" \
  "browser-cookie3==$BROWSER_COOKIE3_VERSION" \
  "pyinstaller==$PYINSTALLER_VERSION"

COMMON=(--noconfirm --clean --onefile --target-architecture arm64 --distpath "$DIST" --workpath "$WORK" --specpath "$SPEC")
"$VENV/bin/pyinstaller" "${COMMON[@]}" \
  --name gallery-dl \
  --collect-all gallery_dl \
  "$ROOT/Scripts/engine_helpers/gallery_dl_main.py"
"$VENV/bin/pyinstaller" "${COMMON[@]}" \
  --name instaloader-zeuve \
  --collect-all instaloader \
  --collect-all browser_cookie3 \
  "$ROOT/Scripts/engine_helpers/instagram_catalog.py"

install -m 755 "$DIST/gallery-dl" "$STAGING/gallery-dl/gallery-dl"
install -m 755 "$DIST/instaloader-zeuve" "$STAGING/instaloader/instaloader-zeuve"
[[ " $(/usr/bin/lipo -archs "$STAGING/gallery-dl/gallery-dl") " == *" arm64 "* ]] || fail "gallery-dl no contiene arm64."
[[ " $(/usr/bin/lipo -archs "$STAGING/instaloader/instaloader-zeuve") " == *" arm64 "* ]] || fail "instaloader-zeuve no contiene arm64."

SITE="$($VENV/bin/python - <<'PY'
import site
print(site.getsitepackages()[0])
PY
)"
copy_license() {
  local package="$1" destination="$2" candidate
  candidate="$(find "$SITE" -maxdepth 3 -type f \( -iname 'LICENSE*' -o -iname 'COPYING*' \) -path "*${package}*" | head -n 1 || true)"
  if [[ -n "$candidate" ]]; then
    install -m 644 "$candidate" "$destination"
  else
    printf '%s\n' "Licencia no localizada durante la preparación. Consulta la distribución oficial fijada." > "$destination"
  fi
}
copy_license "gallery_dl" "$STAGING/licenses/gallery-dl/LICENSE"
copy_license "instaloader" "$STAGING/licenses/instaloader/LICENSE"
copy_license "browser_cookie3" "$STAGING/licenses/browser-cookie3/LICENSE"

"$STAGING/gallery-dl/gallery-dl" --version | grep -F "$GALLERY_DL_VERSION" >/dev/null || fail "gallery-dl no informa la versión fijada."
"$STAGING/instaloader/instaloader-zeuve" --version | grep -F "$INSTALOADER_ZEUVE_VERSION" >/dev/null || fail "instaloader-zeuve no informa la revisión ZEUVE fijada."

if [[ -f "$STAGING/engines.json" ]]; then
  python3 "$ROOT/Scripts/refresh_social_engine_manifest.py" "$STAGING"
else
  echo "Manifest no presente en $STAGING; el preparador completo registrará hashes y tamaños al generar engines.json."
fi

echo "Motores sociales preparados y registrados en $STAGING"
