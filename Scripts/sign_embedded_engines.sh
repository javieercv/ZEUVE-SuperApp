#!/bin/bash
set -euo pipefail

APP_PATH="${1:-}"
IDENTITY="${2:-${EXPANDED_CODE_SIGN_IDENTITY:-}}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

[[ -n "$APP_PATH" && -d "$APP_PATH" ]] || {
  echo "Uso: $0 /ruta/ZEUVE.app [identidad]" >&2
  exit 2
}

ENGINE_ROOT="$APP_PATH/Contents/Resources/Engines"
[[ -d "$ENGINE_ROOT" ]] || {
  echo "No se encuentran motores en $ENGINE_ROOT" >&2
  exit 1
}

if [[ -z "$IDENTITY" || "$IDENTITY" == "-" ]]; then
  IDENTITY="-"
fi

# La aplicación oficial de Calibre y yt-dlp conservan sus firmas originales.
PRESERVED_EXECUTABLES=(
  "yt-dlp/yt-dlp_macos"
  "calibre/Calibre.app/Contents/MacOS/ebook-convert"
)

# Los binarios oficiales simples o compilados específicamente para ZEUVE se firman
# con la identidad de la aplicación. Los motores opcionales ausentes se omiten.
RESIGNED_EXECUTABLES=(
  "deno/deno"
  "ffmpeg/ffmpeg"
  "ffmpeg/ffprobe"
  "pandoc/bin/pandoc"
  "ghostscript/bin/gs"
)

[[ -x "$ENGINE_ROOT/yt-dlp/yt-dlp_macos" ]] || {
  echo "Ejecutable obligatorio ausente: $ENGINE_ROOT/yt-dlp/yt-dlp_macos" >&2
  exit 1
}

for relative in "${PRESERVED_EXECUTABLES[@]}"; do
  executable="$ENGINE_ROOT/$relative"
  if [[ ! -e "$executable" ]]; then
    case "$relative" in
      calibre/*) echo "Motor opcional no incluido; se omite: $relative" ;;
      *) echo "Ejecutable obligatorio ausente: $executable" >&2; exit 1 ;;
    esac
    continue
  fi
  [[ -x "$executable" ]] || { echo "Ejecutable sin permisos: $executable" >&2; exit 1; }
done

if [[ -d "$ENGINE_ROOT/calibre/Calibre.app" ]]; then
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$ENGINE_ROOT/calibre/Calibre.app"
fi

for relative in "${RESIGNED_EXECUTABLES[@]}"; do
  executable="$ENGINE_ROOT/$relative"
  if [[ ! -e "$executable" ]]; then
    case "$relative" in
      pandoc/*|ghostscript/*) echo "Motor opcional no incluido; se omite: $relative"; continue ;;
      *) echo "Ejecutable obligatorio ausente: $executable" >&2; exit 1 ;;
    esac
  fi
  [[ -x "$executable" ]] || { echo "Ejecutable sin permisos: $executable" >&2; exit 1; }
  /usr/bin/codesign --force --options runtime --timestamp=none --sign "$IDENTITY" "$executable"
done

"$SCRIPT_DIR/verify_packaged_engines_macos.sh" "$APP_PATH"
