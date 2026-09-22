#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ "${ZEUVE_ENABLE_YOUTUBE_INTEGRATION_TESTS:-0}" != "1" ]]; then
  echo "Pruebas online desactivadas. Define ZEUVE_ENABLE_YOUTUBE_INTEGRATION_TESTS=1 y ZEUVE_YOUTUBE_TEST_URL para ejecutarlas." >&2
  exit 2
fi
[[ "$(uname -s)" == "Darwin" && "$(uname -m)" == "arm64" ]] || { echo "Se requiere macOS Apple Silicon." >&2; exit 1; }
[[ -n "${ZEUVE_YOUTUBE_TEST_URL:-}" ]] || { echo "Falta ZEUVE_YOUTUBE_TEST_URL con contenido público y autorizado." >&2; exit 2; }

"$ROOT/Scripts/verify_engines_macos.sh"
YTDLP="$ROOT/Resources/Engines/yt-dlp/yt-dlp_macos"
DENO="$ROOT/Resources/Engines/deno/deno"
FFMPEG="$ROOT/Resources/Engines/ffmpeg/ffmpeg"
TEMP="$(mktemp -d -t zeuve-youtube-integration)"
trap 'rm -rf "$TEMP"' EXIT

COMMON=(
  --ignore-config
  --no-update
  --cache-dir "$TEMP/cache"
  --no-write-info-json
  --no-write-playlist-metafiles
  --js-runtimes "deno:$DENO"
  --ffmpeg-location "$FFMPEG"
)

"$YTDLP" "${COMMON[@]}" --skip-download --no-playlist --dump-single-json -- "$ZEUVE_YOUTUBE_TEST_URL" > "$TEMP/analysis.json"
python3 - "$TEMP/analysis.json" <<'PY'
import json, sys
value=json.load(open(sys.argv[1]))
assert value.get('id'), 'El análisis no contiene ID'
assert value.get('title'), 'El análisis no contiene título'
print('Análisis online superado:', value['id'])
PY

if [[ "${ZEUVE_YOUTUBE_ALLOW_DOWNLOAD:-0}" == "1" ]]; then
  mkdir -p "$TEMP/output" "$TEMP/work"
  "$YTDLP" "${COMMON[@]}" \
    --no-playlist --no-overwrites --no-continue \
    --paths "home:$TEMP/output" --paths "temp:$TEMP/work" \
    --output '%(title).120B [%(id)s].%(ext)s' \
    --format 'bestvideo*+bestaudio/best' \
    -- "$ZEUVE_YOUTUBE_TEST_URL"
  find "$TEMP/output" -type f ! -name '*.part' -size +0c | grep -q .
  echo "Descarga online temporal superada."
else
  echo "Descarga omitida. Define ZEUVE_YOUTUBE_ALLOW_DOWNLOAD=1 para habilitarla."
fi
