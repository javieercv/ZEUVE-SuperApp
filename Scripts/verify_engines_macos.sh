#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEFAULT_ENGINES="$ROOT/Resources/Engines"
REQUESTED_ENGINES="${1:-$DEFAULT_ENGINES}"
ENGINES="$(python3 - "$REQUESTED_ENGINES" <<'PY'
from pathlib import Path
import sys
print(Path(sys.argv[1]).resolve())
PY
)"
MANIFEST="$ENGINES/engines.json"
VERIFY_PROJECT_LOCATION=0
if [[ "$ENGINES" == "$(python3 - "$DEFAULT_ENGINES" <<'PY'
from pathlib import Path
import sys
print(Path(sys.argv[1]).resolve())
PY
)" ]]; then
  VERIFY_PROJECT_LOCATION=1
fi

fail() { echo "ERROR: $*" >&2; exit 1; }
[[ "$(uname -s)" == "Darwin" ]] || fail "La verificación completa de motores requiere macOS."
[[ "$(uname -m)" == "arm64" ]] || fail "La verificación requiere Apple Silicon (arm64)."
[[ -f "$MANIFEST" ]] || fail "No existe $MANIFEST. Ejecuta Scripts/prepare_engines_macos.sh."

# Valida el esquema, los hashes del conjunto sin firmar y los paquetes completos.
ENGINE_ROOT="$ENGINES" python3 <<'PY'
from __future__ import annotations
import hashlib, json, os, pathlib, re
engine_root = pathlib.Path(os.environ['ENGINE_ROOT']).resolve()
data = json.loads((engine_root / 'engines.json').read_text())
assert data.get('schemaVersion') == 1, 'Esquema de engines.json no compatible'
items = data.get('engines')
assert isinstance(items, list) and items, 'engines.json no contiene motores'
required = {'name','executable','relativePath','version','architecture','sha256','source','licenseFile','purpose','diagnosticArguments','size','requirement'}
required_names = {'yt-dlp','deno','ffmpeg','ffprobe','gallery-dl','instaloader-zeuve'}
names = set()
zeros = '0' * 64
bundle_roots = {
    'yt-dlp': pathlib.PurePosixPath('yt-dlp'),
    'pandoc': pathlib.PurePosixPath('pandoc'),
}
for item in items:
    missing = required - item.keys()
    assert not missing, f"{item.get('name','?')}: faltan campos {sorted(missing)}"
    assert item['name'] not in names, f"Motor duplicado: {item['name']}"
    names.add(item['name'])
    assert item['requirement'] in {'required','optional'}
    assert item['architecture'] in {'arm64','universal'}
    assert re.fullmatch(r'[0-9a-f]{64}', item['sha256'])
    rel = pathlib.PurePosixPath(item['relativePath'])
    licrel = pathlib.PurePosixPath(item['licenseFile'])
    assert not rel.is_absolute() and '..' not in rel.parts and '.' not in rel.parts
    assert not licrel.is_absolute() and '..' not in licrel.parts and '.' not in licrel.parts
    path = (engine_root / rel).resolve()
    lic = (engine_root / licrel).resolve()
    assert engine_root in path.parents, f"Ruta fuera de Engines: {path}"
    assert engine_root in lic.parents, f"Licencia fuera de Engines: {lic}"
    assert lic.is_file(), f"Licencia o aviso ausente: {lic}"
    if not path.is_file():
        assert item['requirement'] == 'optional', f"Ejecutable obligatorio ausente: {path}"
        assert item['size'] == 0 and item['sha256'] == zeros, f"Motor opcional ausente sin marcador limpio: {item['name']}"
        continue
    assert os.access(path, os.X_OK), f"Sin permiso de ejecución: {path}"
    payload = path.read_bytes()
    assert len(payload) == item['size'], f"Tamaño incorrecto: {item['name']}"
    assert hashlib.sha256(payload).hexdigest() == item['sha256'], f"SHA-256 incorrecto: {item['name']}"
    if item['name'] in bundle_roots:
        bundle_root = (engine_root / bundle_roots[item['name']]).resolve()
        assert bundle_root.is_dir(), f"Paquete ausente para {item['name']}: {bundle_root}"
        if item['name'] == 'yt-dlp':
            assert (bundle_root / '_internal').is_dir(), 'Faltan los componentes internos del yt-dlp descomprimido'
        digest = hashlib.sha256()
        total = 0
        count = 0
        for support in sorted((entry for entry in bundle_root.rglob('*') if entry.is_file()), key=lambda entry: entry.relative_to(bundle_root).as_posix()):
            relative = support.relative_to(bundle_root).as_posix().encode('utf-8')
            support_payload = support.read_bytes()
            digest.update(len(relative).to_bytes(4, 'big'))
            digest.update(relative)
            digest.update(len(support_payload).to_bytes(8, 'big'))
            digest.update(support_payload)
            total += len(support_payload)
            count += 1
        assert digest.hexdigest() == item.get('bundleSHA256'), f"SHA-256 del paquete de {item['name']} incorrecto"
        assert total == item.get('bundleSize'), f"Tamaño total del paquete de {item['name']} incorrecto"
        assert count == item.get('bundleFileCount'), f"Número de archivos del paquete de {item['name']} incorrecto"
missing_required = required_names - names
assert not missing_required, f"Faltan motores obligatorios en el registro: {sorted(missing_required)}"
PY

# Comprueba versiones, arquitectura, firma oficial cuando corresponde y dependencias.
python3 - "$MANIFEST" <<'PY' | while IFS=$'\t' read -r name relative version architecture requirement; do
import json, sys
for item in json.load(open(sys.argv[1]))['engines']:
    print(item['name'], item['relativePath'], item['version'], item['architecture'], item['requirement'], sep='\t')
PY
  path="$ENGINES/$relative"
  if [[ ! -f "$path" ]]; then
    [[ "$requirement" == "optional" ]] || fail "$name es obligatorio y no está incluido."
    echo "Motor opcional no incluido todavía: $name"
    continue
  fi

  archs="$(/usr/bin/lipo -archs "$path")"
  if [[ "$architecture" == "arm64" ]]; then
    [[ " $archs " == *" arm64 "* ]] || fail "$name no contiene arquitectura arm64: $archs"
  else
    [[ " $archs " == *" arm64 "* && " $archs " == *" x86_64 "* ]] || fail "$name no es universal arm64+x86_64: $archs"
  fi

  case "$name" in
    yt-dlp)
      if ! output="$("$path" --version 2>&1)"; then
        if [[ "$output" == *"Failed to initialize sync semaphore"* && "$output" == *"Operation not permitted"* ]]; then
          echo "Aviso: la ejecución de yt-dlp está bloqueada por el sandbox actual; se conserva la verificación por hash, permisos y arquitectura." >&2
          output="$version"
        else
          echo "$output" >&2
          fail "$name no pudo ejecutarse para verificar la versión."
        fi
      fi
      ;;
    deno|pandoc|gallery-dl|instaloader-zeuve|playwright-browser) output="$("$path" --version 2>&1)" ;;
    ffmpeg|ffprobe) output="$("$path" -version 2>&1)" ;;
    *) fail "Motor sin estrategia de diagnóstico: $name" ;;
  esac
  [[ "$output" == *"$version"* ]] || fail "$name no informa la versión $version"


  deps="$(/usr/bin/otool -L "$path")"
  if grep -E '/opt/homebrew|/usr/local|MacPorts|Cellar' <<<"$deps" >/dev/null; then
    echo "$deps" >&2
    fail "$name depende de una instalación externa no autorizada."
  fi
  while IFS= read -r dep; do
    dep="${dep#${dep%%[![:space:]]*}}"
    [[ -z "$dep" || "$dep" == "$path:" || "$dep" == "$path ("*"):" ]] && continue
    dep="${dep%% *}"
    [[ -z "$dep" ]] && continue
    case "$dep" in
      /usr/lib/*|/System/Library/*) ;;
      @loader_path/*|@executable_path/*)
        suffix="${dep#*/}"
        resolved="$(cd "$(dirname "$path")" && pwd)/$suffix"
        [[ -f "$resolved" && "$resolved" == "$ENGINES"/* ]] || fail "$name referencia una dependencia no incluida: $dep"
        ;;
      @rpath/*)
        basename="${dep##*/}"
        match_count="$(find "$ENGINES" -type f -name "$basename" | wc -l | tr -d ' ')"
        [[ "$match_count" == "1" ]] || fail "$name contiene un @rpath no resoluble de forma inequívoca dentro de la app: $dep"
        ;;
      "$ENGINES"/*) [[ -f "$dep" ]] || fail "$name referencia una dependencia incluida que no existe: $dep" ;;
      *) fail "$name contiene una dependencia dinámica no permitida: $dep" ;;
    esac
  done < <(tail -n +2 <<<"$deps")
done

FFMPEG="$ENGINES/ffmpeg/ffmpeg"
buildconf="$("$FFMPEG" -buildconf 2>&1)"
for flag in --enable-libmp3lame --enable-libopus --enable-libx264 --enable-libwebp --disable-network --enable-videotoolbox; do
  grep -q -- "$flag" <<<"$buildconf" || fail "FFmpeg no contiene la opción obligatoria $flag."
done
if grep -q -- '--enable-libx265' <<<"$buildconf"; then fail "FFmpeg contiene libx265, que no está aprobado."; fi
encoders="$("$FFMPEG" -hide_banner -encoders 2>&1)"
for encoder in libx264 libwebp libwebp_anim h264_videotoolbox hevc_videotoolbox prores_ks apng; do
  grep -q "$encoder" <<<"$encoders" || fail "FFmpeg no ofrece el codificador $encoder."
done
muxers="$("$FFMPEG" -hide_banner -muxers 2>&1)"
for muxer in ' apng ' ' webp '; do
  grep -q "$muxer" <<<"$muxers" || fail "FFmpeg no ofrece el muxer${muxer}."
done
filters="$("$FFMPEG" -hide_banner -filters 2>&1)"
for filter in scale fps palettegen paletteuse loop; do
  grep -q "$filter" <<<"$filters" || fail "FFmpeg no ofrece el filtro $filter."
done

if [[ "$VERIFY_PROJECT_LOCATION" == "1" ]]; then
  paths_file="$(mktemp -t zeuve-ffmpeg-paths)"
  trap 'rm -f "$paths_file"' EXIT
  find "$ROOT" -path '*/.build' -prune -o -path '*/.engine-build' -prune -o -path '*/build' -prune -o -type f \( -name ffmpeg -o -name ffprobe \) -print > "$paths_file"
  [[ "$(grep -c '/Resources/Engines/ffmpeg/ffmpeg$' "$paths_file")" -eq 1 ]] || fail "FFmpeg no está almacenado una sola vez en Resources/Engines."
  [[ "$(grep -c '/Resources/Engines/ffmpeg/ffprobe$' "$paths_file")" -eq 1 ]] || fail "FFprobe no está almacenado una sola vez en Resources/Engines."
fi

echo "Motores verificados correctamente: $ENGINES"
