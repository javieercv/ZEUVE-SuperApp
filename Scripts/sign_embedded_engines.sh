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
SOURCE_ENGINE_ROOT="$SCRIPT_DIR/../Resources/Engines"
[[ -d "$ENGINE_ROOT" ]] || {
  echo "No se encuentran motores en $ENGINE_ROOT" >&2
  exit 1
}

if [[ -z "$IDENTITY" || "$IDENTITY" == "-" ]]; then
  IDENTITY="-"
fi

# yt-dlp y Deno conservan sus firmas oficiales originales. Deno necesita las
# autorizaciones Hardened Runtime de su firma oficial para que V8 pueda usar JIT;
# volver a firmarlo sin ellas hace que falle al resolver desafíos de YouTube.
PRESERVED_EXECUTABLES=(
  "yt-dlp/yt-dlp_macos"
  "deno/deno"
)

# Los binarios oficiales simples o compilados específicamente para ZEUVE se firman
# con la identidad de la aplicación. Los motores opcionales ausentes se omiten.
RESIGNED_EXECUTABLES=(
  "ffmpeg/ffmpeg"
  "ffmpeg/ffprobe"
  "pandoc/bin/pandoc"
  "gallery-dl/gallery-dl"
  "instaloader/instaloader-zeuve"
)

[[ -e "$ENGINE_ROOT/yt-dlp/yt-dlp_macos" ]] || {
  echo "Ejecutable obligatorio ausente: $ENGINE_ROOT/yt-dlp/yt-dlp_macos" >&2
  exit 1
}

for relative in "${PRESERVED_EXECUTABLES[@]}"; do
  executable="$ENGINE_ROOT/$relative"
  source_executable="$SOURCE_ENGINE_ROOT/$relative"
  if [[ ! -e "$executable" ]]; then
    echo "Ejecutable obligatorio ausente: $executable" >&2
    exit 1
  fi
  [[ -f "$source_executable" ]] || { echo "Motor fuente ausente: $source_executable" >&2; exit 1; }
  # Una compilación incremental puede conservar una copia firmada por una fase
  # anterior. Restaurar desde Resources garantiza la firma oficial completa.
  if ! /usr/bin/cmp -s "$source_executable" "$executable" || [[ -x "$source_executable" && ! -x "$executable" ]]; then
    /bin/cp -p "$source_executable" "$executable"
  fi
  [[ -x "$executable" ]] || { echo "Ejecutable sin permisos: $executable" >&2; exit 1; }
done


for relative in "${RESIGNED_EXECUTABLES[@]}"; do
  executable="$ENGINE_ROOT/$relative"
  if [[ ! -e "$executable" ]]; then
    case "$relative" in
      pandoc/*) echo "Motor opcional no incluido; se omite: $relative"; continue ;;
      *) echo "Ejecutable obligatorio ausente: $executable" >&2; exit 1 ;;
    esac
  fi
  if [[ -x "$SOURCE_ENGINE_ROOT/$relative" && ! -x "$executable" ]]; then
    /bin/chmod +x "$executable"
  fi
  [[ -x "$executable" ]] || { echo "Ejecutable sin permisos: $executable" >&2; exit 1; }
  case "$relative" in
    gallery-dl/*|instaloader/*)
      # PyInstaller extrae un framework Python firmado de forma independiente.
      # La excepcion se limita a estos procesos auxiliares; ZEUVE.app conserva
      # la validacion de bibliotecas del Hardened Runtime.
      /usr/bin/codesign --force --options runtime --timestamp=none \
        --entitlements "$SCRIPT_DIR/social_engine.entitlements" \
        --sign "$IDENTITY" "$executable"
      ;;
    *)
      /usr/bin/codesign --force --options runtime --timestamp=none --sign "$IDENTITY" "$executable"
      ;;
  esac
done

"$SCRIPT_DIR/verify_packaged_engines_macos.sh" "$APP_PATH"
