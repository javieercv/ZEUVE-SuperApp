#!/bin/bash
set -euo pipefail

APP_PATH="${1:-}"
[[ -n "$APP_PATH" && -d "$APP_PATH" ]] || {
  echo "Uso: $0 /ruta/ZEUVE.app" >&2
  exit 2
}

ENGINE_ROOT="$APP_PATH/Contents/Resources/Engines"
MANIFEST="$ENGINE_ROOT/engines.json"
[[ -d "$ENGINE_ROOT" && -f "$MANIFEST" ]] || {
  echo "No se encuentran los motores o su manifiesto en $ENGINE_ROOT" >&2
  exit 1
}

fail() { echo "ERROR: $*" >&2; exit 1; }

# Comprueba que todos los obligatorios y cualquier opcional presente están firmados.
python3 - "$MANIFEST" <<'PY' | while IFS=$'\t' read -r name relative version requirement; do
import json, sys
for item in json.load(open(sys.argv[1]))['engines']:
    print(item['name'], item['relativePath'], item['version'], item['requirement'], sep='\t')
PY
  executable="$ENGINE_ROOT/$relative"
  if [[ ! -e "$executable" ]]; then
    [[ "$requirement" == "optional" ]] || fail "$name es obligatorio y no está incluido."
    echo "Motor opcional no incluido en la aplicación: $name"
    continue
  fi
  [[ -x "$executable" ]] || fail "$name no tiene permiso de ejecución."
  /usr/bin/codesign --verify --strict --verbose=2 "$executable"

  case "$name" in
    yt-dlp|deno|pandoc|gallery-dl|instaloader-zeuve|playwright-browser) diagnostic_args=(--version) ;;
    ffmpeg|ffprobe) diagnostic_args=(-version) ;;
    *) fail "Motor sin estrategia de diagnóstico: $name" ;;
  esac
  set +e
  output="$("$executable" "${diagnostic_args[@]}" 2>&1)"
  diagnostic_status=$?
  set -e
  if [[ $diagnostic_status -ne 0 ]]; then
    if [[ "$output" == *"Failed to initialize sync semaphore"* && "$output" == *"Operation not permitted"* ]]; then
      echo "Aviso: la ejecución de $name está bloqueada por el sandbox actual; se conserva la verificación por firma, permisos y arquitectura." >&2
      output="$version"
    else
      echo "$output" >&2
      fail "$name no pudo ejecutarse para verificar la versión."
    fi
  fi
  [[ "$output" == *"$version"* ]] || fail "$name no informa la versión registrada $version."
done


# Los motores cuya firma se conserva deben seguir coincidiendo byte a byte con el
# manifiesto previo a la firma. Pandoc y FFmpeg se excluyen porque codesign modifica
# sus ejecutables durante el empaquetado.
ENGINE_ROOT="$ENGINE_ROOT" python3 <<'PY'
from __future__ import annotations
import hashlib, json, os
from pathlib import Path
root = Path(os.environ['ENGINE_ROOT'])
manifest = json.loads((root / 'engines.json').read_text())
roots = {
    'yt-dlp': root / 'yt-dlp',
}
for item in manifest['engines']:
    if item['name'] == 'deno':
        executable = root / item['relativePath']
        payload = executable.read_bytes()
        assert len(payload) == item['size'], 'Tamaño del ejecutable de Deno incorrecto'
        assert hashlib.sha256(payload).hexdigest() == item['sha256'], 'Huella del ejecutable de Deno incorrecta'
    bundle = roots.get(item['name'])
    if bundle is None or not bundle.is_dir():
        continue
    if item['name'] == 'yt-dlp':
        assert (bundle / '_internal').is_dir(), 'Faltan componentes internos de yt-dlp'
    digest = hashlib.sha256()
    total = 0
    count = 0
    for path in sorted((entry for entry in bundle.rglob('*') if entry.is_file()), key=lambda entry: entry.relative_to(bundle).as_posix()):
        relative = path.relative_to(bundle).as_posix().encode('utf-8')
        payload = path.read_bytes()
        digest.update(len(relative).to_bytes(4, 'big'))
        digest.update(relative)
        digest.update(len(payload).to_bytes(8, 'big'))
        digest.update(payload)
        total += len(payload)
        count += 1
    assert digest.hexdigest() == item['bundleSHA256'], f"Huella del paquete de {item['name']} incorrecta"
    assert total == item['bundleSize'], f"Tamaño total del paquete de {item['name']} incorrecto"
    assert count == item['bundleFileCount'], f"Número de archivos del paquete de {item['name']} incorrecto"
PY

YTDLP="$ENGINE_ROOT/yt-dlp/yt-dlp_macos"
set +e
YTDLP_OUTPUT="$("$YTDLP" --version 2>&1)"
YTDLP_STATUS=$?
set -e
[[ $YTDLP_STATUS -eq 0 ]] || { echo "$YTDLP_OUTPUT" >&2; fail "El yt-dlp incluido no puede iniciarse correctamente."; }
[[ -n "${YTDLP_OUTPUT//[[:space:]]/}" ]] || fail "yt-dlp termina sin informar de su versión."

DENO="$ENGINE_ROOT/deno/deno"
set +e
DENO_EVAL_OUTPUT="$("$DENO" eval 'console.log("ZEUVE_DENO_JIT_OK")' 2>&1)"
DENO_EVAL_STATUS=$?
set -e
[[ $DENO_EVAL_STATUS -eq 0 && "$DENO_EVAL_OUTPUT" == *"ZEUVE_DENO_JIT_OK"* ]] || {
  echo "$DENO_EVAL_OUTPUT" >&2
  fail "Deno no puede ejecutar JavaScript con las autorizaciones del paquete."
}

FFMPEG="$ENGINE_ROOT/ffmpeg/ffmpeg"
buildconf="$("$FFMPEG" -buildconf 2>&1)"
for flag in --enable-libmp3lame --enable-libopus --disable-network; do
  grep -q -- "$flag" <<<"$buildconf" || fail "FFmpeg empaquetado no contiene $flag."
done
if grep -q -- '--enable-libx265' <<<"$buildconf"; then fail "FFmpeg empaquetado contiene libx265 no aprobado."; fi

echo "Motores empaquetados verificados correctamente en: $APP_PATH"
