#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESOURCES="$ROOT/Resources/Engines"
TMP_BASE="${TMPDIR:-/tmp}"
case "$TMP_BASE" in
  *[[:space:]]*) TMP_BASE="/tmp" ;;
esac
TMP_BASE="${TMP_BASE%/}"
PROJECT_KEY="$(printf '%s' "$ROOT" | /usr/bin/shasum -a 256 | /usr/bin/awk '{print substr($1,1,12)}')"
BUILD_ROOT="$TMP_BASE/ZEUVE-engine-build-$PROJECT_KEY"
DOWNLOADS="$BUILD_ROOT/downloads"
SOURCES="$BUILD_ROOT/sources"
PREFIX="$BUILD_ROOT/prefix"
STAGING="$BUILD_ROOT/staging/Engines"

YTDLP_VERSION="2026.08.19"
DENO_VERSION="2.9.0"
FFMPEG_VERSION="8.1.2"
PANDOC_VERSION="3.10"
GALLERY_DL_VERSION="1.32.9"
INSTALOADER_VERSION="4.15.3"
X264_VERSION="r3222"
X264_REVISION="b35605ace3ddf7c1a5d67a2eb553f034aef41d55"
LIBWEBP_VERSION="1.6.0"
OPUS_VERSION="1.5.2"
LAME_VERSION="3.100"

YTDLP_SHA256="07e54b0865303c864006925913bce2604f8ee8cc6f18699bac9c309f9328a6d8"
DENO_ZIP_SHA256="2d11cf0505d4600a4492de8d07456a7a5e7eedebf68bdcbcb9092f520fcde0f1"
FFMPEG_SOURCE_SHA256="464beb5e7bf0c311e68b45ae2f04e9cc2af88851abb4082231742a74d97b524c"
PANDOC_ZIP_SHA256="d9cad01d96ae774a0dc8c8c45bb1ad3e4c5ff2cc2e24f45958f5f9b7974aee34"
X264_SOURCE_SHA256="6eeb82934e69fd51e043bd8c5b0d152839638d1ce7aa4eea65a3fedcf83ff224"
LIBWEBP_SOURCE_SHA256="e4ab7009bf0629fd11982d4c2aa83964cf244cffba7347ecd39019a9e38c4564"
OPUS_SOURCE_SHA256="65c1d2f78b9f2fb20082c38cbe47c951ad5839345876e46941612ee87f9a7ce1"
LAME_SOURCE_SHA256="ddfe36cab873794038ae2c1210557ad34857a4b6bdc515785d1da9e175b1da1e"

YTDLP_URL="local-cache:yt-dlp_macos.zip"
DENO_URL="https://dl.deno.land/release/v${DENO_VERSION}/deno-aarch64-apple-darwin.zip"
FFMPEG_URL="https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz"
PANDOC_URL="local-cache:pandoc-${PANDOC_VERSION}-arm64-macOS.zip"
X264_URL="https://code.videolan.org/videolan/x264/-/archive/${X264_REVISION}/x264-${X264_REVISION}.tar.bz2"
LIBWEBP_URL="https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-${LIBWEBP_VERSION}.tar.gz"
OPUS_URL="https://downloads.xiph.org/releases/opus/opus-${OPUS_VERSION}.tar.gz"
LAME_URL="https://downloads.sourceforge.net/project/lame/lame/${LAME_VERSION}/lame-${LAME_VERSION}.tar.gz"

fail() { echo "ERROR: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "Falta la herramienta de desarrollo obligatoria: $1"; }
sha256() { /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'; }
verify_sha() {
  local file="$1" expected="$2" actual
  actual="$(sha256 "$file")"
  [[ "$actual" == "$expected" ]] || fail "SHA-256 incorrecto para $(basename "$file"). Esperado: $expected. Detectado: $actual"
}
download() {
  local url="$1" output="$2"
  /bin/mkdir -p "$(dirname "$output")"
  if [[ ! -f "$output" ]]; then
    if [[ "$url" == local-cache:* ]]; then
      fail "Falta el artefacto local $(basename "$output"). Cópialo en $DOWNLOADS para reconstruir motores sin servicios remotos."
    fi
    echo "Descargando $(basename "$output")…"
    /usr/bin/curl --fail --location --proto '=https' --tlsv1.2 --retry 3 --output "$output.part" "$url"
    /bin/mv "$output.part" "$output"
  fi
}
copy_existing_license() {
  local relative="$1" destination="$2" source="$RESOURCES/$relative"
  if [[ -f "$source" ]]; then
    install -m 644 "$source" "$destination"
  else
    printf '%s\n' "Licencia no localizada en el paquete local anterior. Revisa el artefacto fijado antes de publicar." > "$destination"
  fi
}
publish_staging() {
  local backup="$ROOT/Resources/.Engines.previous.$$"
  /bin/rm -rf "$backup"

  if [[ -d "$RESOURCES" ]]; then
    /bin/mv "$RESOURCES" "$backup"
  fi

  if ! /bin/mv "$STAGING" "$RESOURCES"; then
    [[ -d "$backup" ]] && /bin/mv "$backup" "$RESOURCES"
    fail "No se pudo publicar el conjunto de motores verificado. Se han conservado los motores anteriores."
  fi

  if "$ROOT/Scripts/verify_engines_macos.sh"; then
    /bin/rm -rf "$backup"
  else
    local status=$?
    /bin/rm -rf "$RESOURCES"
    [[ -d "$backup" ]] && /bin/mv "$backup" "$RESOURCES"
    fail "La verificación final falló con código $status. Se han restaurado los motores anteriores."
  fi
}

[[ "$(uname -s)" == "Darwin" ]] || fail "Este script solo puede ejecutarse en macOS."
[[ "$(uname -m)" == "arm64" ]] || fail "Este script requiere un Mac Apple Silicon (arm64)."
for tool in curl shasum awk tar unzip make python3 file lipo otool install xcrun ditto; do need "$tool"; done
[[ -x "$ROOT/Scripts/static_pkg_config.py" ]] || fail "No se puede ejecutar Scripts/static_pkg_config.py."
SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
CC="$(xcrun --sdk macosx --find clang)"
STRIP="$(xcrun --sdk macosx --find strip)"

[[ -d "$SDKROOT" ]] || fail "No se encuentra el SDK de macOS."
[[ -x "$CC" ]] || fail "No se encuentra clang dentro de Xcode."

echo "Directorio temporal de compilación: $BUILD_ROOT"
/bin/mkdir -p "$DOWNLOADS"
/bin/rm -rf "$SOURCES" "$PREFIX" "$BUILD_ROOT/staging"
/bin/mkdir -p "$SOURCES" "$PREFIX" \
  "$STAGING/yt-dlp" "$STAGING/deno" "$STAGING/ffmpeg" \
  "$STAGING/pandoc/bin" \
  "$STAGING/gallery-dl" "$STAGING/instaloader" "$STAGING/playwright" \
  "$STAGING/licenses/yt-dlp" "$STAGING/licenses/deno" \
  "$STAGING/licenses/pandoc" \
  "$STAGING/licenses/gallery-dl" "$STAGING/licenses/instaloader" "$STAGING/licenses/playwright-browser" \
  "$STAGING/licenses/ffmpeg" "$STAGING/licenses/opus" "$STAGING/licenses/lame" \
  "$STAGING/licenses/x264" "$STAGING/licenses/libwebp"

if [[ -f "$RESOURCES/README.md" ]]; then
  install -m 644 "$RESOURCES/README.md" "$STAGING/README.md"
fi

# 1. Motores oficiales precompilados. Todo se prepara fuera del proyecto.
download "$YTDLP_URL" "$DOWNLOADS/yt-dlp_macos.zip"
verify_sha "$DOWNLOADS/yt-dlp_macos.zip" "$YTDLP_SHA256"
/bin/rm -rf "$SOURCES/yt-dlp_macos"
/bin/mkdir -p "$SOURCES/yt-dlp_macos"
unzip -q -o "$DOWNLOADS/yt-dlp_macos.zip" -d "$SOURCES/yt-dlp_macos"
[[ -x "$SOURCES/yt-dlp_macos/yt-dlp_macos" ]] || fail "El paquete oficial descomprimido de yt-dlp no contiene su ejecutable raíz."
/usr/bin/ditto "$SOURCES/yt-dlp_macos" "$STAGING/yt-dlp"
/bin/chmod 755 "$STAGING/yt-dlp/yt-dlp_macos"

download "$DENO_URL" "$DOWNLOADS/deno-aarch64-apple-darwin.zip"
verify_sha "$DOWNLOADS/deno-aarch64-apple-darwin.zip" "$DENO_ZIP_SHA256"
/bin/mkdir -p "$SOURCES/deno"
unzip -q -o "$DOWNLOADS/deno-aarch64-apple-darwin.zip" -d "$SOURCES/deno"
install -m 755 "$SOURCES/deno/deno" "$STAGING/deno/deno"


# Pandoc oficial ARM64. Se normaliza a pandoc/bin/pandoc y se firma después con ZEUVE.
download "$PANDOC_URL" "$DOWNLOADS/pandoc-${PANDOC_VERSION}-arm64-macOS.zip"
verify_sha "$DOWNLOADS/pandoc-${PANDOC_VERSION}-arm64-macOS.zip" "$PANDOC_ZIP_SHA256"
/bin/rm -rf "$SOURCES/pandoc"
/bin/mkdir -p "$SOURCES/pandoc"
unzip -q -o "$DOWNLOADS/pandoc-${PANDOC_VERSION}-arm64-macOS.zip" -d "$SOURCES/pandoc"
PANDOC_BIN="$(/usr/bin/find "$SOURCES/pandoc" -type f -path '*/bin/pandoc' -perm -111 | /usr/bin/head -n 1)"
[[ -n "$PANDOC_BIN" ]] || fail "El ZIP oficial de Pandoc no contiene bin/pandoc."
install -m 755 "$PANDOC_BIN" "$STAGING/pandoc/bin/pandoc"
PANDOC_ROOT="$(cd "$(dirname "$PANDOC_BIN")/.." && pwd)"
if [[ -d "$PANDOC_ROOT/share" ]]; then /usr/bin/ditto "$PANDOC_ROOT/share" "$STAGING/pandoc/share"; fi
[[ " $(/usr/bin/lipo -archs "$STAGING/pandoc/bin/pandoc") " == *" arm64 "* ]] || fail "Pandoc no contiene arquitectura arm64."

# 2. Fuentes fijadas y verificadas para FFmpeg y sus codificadores externos.
download "$FFMPEG_URL" "$DOWNLOADS/ffmpeg-${FFMPEG_VERSION}.tar.xz"
verify_sha "$DOWNLOADS/ffmpeg-${FFMPEG_VERSION}.tar.xz" "$FFMPEG_SOURCE_SHA256"
download "$OPUS_URL" "$DOWNLOADS/opus-${OPUS_VERSION}.tar.gz"
verify_sha "$DOWNLOADS/opus-${OPUS_VERSION}.tar.gz" "$OPUS_SOURCE_SHA256"
download "$LAME_URL" "$DOWNLOADS/lame-${LAME_VERSION}.tar.gz"
verify_sha "$DOWNLOADS/lame-${LAME_VERSION}.tar.gz" "$LAME_SOURCE_SHA256"
download "$X264_URL" "$DOWNLOADS/x264-${X264_REVISION}.tar.bz2"
verify_sha "$DOWNLOADS/x264-${X264_REVISION}.tar.bz2" "$X264_SOURCE_SHA256"
download "$LIBWEBP_URL" "$DOWNLOADS/libwebp-${LIBWEBP_VERSION}.tar.gz"
verify_sha "$DOWNLOADS/libwebp-${LIBWEBP_VERSION}.tar.gz" "$LIBWEBP_SOURCE_SHA256"

tar -C "$SOURCES" -xf "$DOWNLOADS/ffmpeg-${FFMPEG_VERSION}.tar.xz"
tar -C "$SOURCES" -xzf "$DOWNLOADS/opus-${OPUS_VERSION}.tar.gz"
tar -C "$SOURCES" -xzf "$DOWNLOADS/lame-${LAME_VERSION}.tar.gz"
tar -C "$SOURCES" -xjf "$DOWNLOADS/x264-${X264_REVISION}.tar.bz2"
tar -C "$SOURCES" -xzf "$DOWNLOADS/libwebp-${LIBWEBP_VERSION}.tar.gz"

JOBS="$(sysctl -n hw.logicalcpu 2>/dev/null || echo 4)"
COMMON_CFLAGS="-O2 -arch arm64 -isysroot $SDKROOT -mmacosx-version-min=14.0"
COMMON_LDFLAGS="-arch arm64 -isysroot $SDKROOT -mmacosx-version-min=14.0"

pushd "$SOURCES/opus-${OPUS_VERSION}" >/dev/null
SDKROOT="$SDKROOT" \
MACOSX_DEPLOYMENT_TARGET="14.0" \
CC="$CC" \
CFLAGS="$COMMON_CFLAGS" \
LDFLAGS="$COMMON_LDFLAGS" \
./configure \
  --prefix="$PREFIX" \
  --disable-shared \
  --enable-static \
  --disable-doc \
  --disable-extra-programs
make -j"$JOBS"
make install
popd >/dev/null

pushd "$SOURCES/lame-${LAME_VERSION}" >/dev/null
SDKROOT="$SDKROOT" \
MACOSX_DEPLOYMENT_TARGET="14.0" \
CC="$CC" \
CFLAGS="$COMMON_CFLAGS" \
LDFLAGS="$COMMON_LDFLAGS" \
./configure \
  --prefix="$PREFIX" \
  --disable-shared \
  --enable-static \
  --disable-frontend
make -j"$JOBS"
make install
popd >/dev/null

# LAME 3.100 no instala un archivo pkg-config. Se genera localmente para FFmpeg.
/bin/mkdir -p "$PREFIX/lib/pkgconfig"
cat > "$PREFIX/lib/pkgconfig/libmp3lame.pc" <<EOF
prefix=$PREFIX
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: libmp3lame
Description: Codificador MP3 LAME
Version: ${LAME_VERSION}
Libs: -L\${libdir} -lmp3lame
Libs.private: -lm
Cflags: -I\${includedir}
EOF

pushd "$SOURCES/x264-${X264_REVISION}" >/dev/null
SDKROOT="$SDKROOT" \
MACOSX_DEPLOYMENT_TARGET="14.0" \
CC="$CC" \
CFLAGS="$COMMON_CFLAGS" \
LDFLAGS="$COMMON_LDFLAGS" \
./configure \
  --prefix="$PREFIX" \
  --host=aarch64-apple-darwin \
  --disable-cli \
  --disable-shared \
  --enable-static \
  --disable-opencl \
  --disable-lsmash \
  --disable-swscale \
  --disable-ffms
make -j"$JOBS"
make install-lib-static
popd >/dev/null

pushd "$SOURCES/libwebp-${LIBWEBP_VERSION}" >/dev/null
SDKROOT="$SDKROOT" \
MACOSX_DEPLOYMENT_TARGET="14.0" \
CC="$CC" \
CFLAGS="$COMMON_CFLAGS" \
LDFLAGS="$COMMON_LDFLAGS" \
./configure \
  --prefix="$PREFIX" \
  --disable-shared \
  --enable-static \
  --disable-sdl \
  --disable-gl
make -j"$JOBS"
make install
popd >/dev/null

# Validación previa de las consultas que FFmpeg realiza a pkg-config.
PKG_CONFIG_WRAPPER="$BUILD_ROOT/static_pkg_config.py"
install -m 755 "$ROOT/Scripts/static_pkg_config.py" "$PKG_CONFIG_WRAPPER"
PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig" "$PKG_CONFIG_WRAPPER" --version >/dev/null
PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig" "$PKG_CONFIG_WRAPPER" --exists --print-errors "opus >= 1.3.1"
PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig" "$PKG_CONFIG_WRAPPER" --exists --print-errors "libmp3lame >= 3.98.3"
PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig" "$PKG_CONFIG_WRAPPER" --exists --print-errors "x264"
PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig" "$PKG_CONFIG_WRAPPER" --exists --print-errors "libwebp >= 1.6.0"
[[ -n "$(PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig" "$PKG_CONFIG_WRAPPER" --variable=includedir opus)" ]] || fail "pkg-config no devuelve includedir para Opus."

pushd "$SOURCES/ffmpeg-${FFMPEG_VERSION}" >/dev/null
PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig" \
SDKROOT="$SDKROOT" \
MACOSX_DEPLOYMENT_TARGET="14.0" \
./configure \
  --pkg-config="$PKG_CONFIG_WRAPPER" \
  --prefix="$PREFIX/ffmpeg" \
  --arch=arm64 \
  --target-os=darwin \
  --cc="$CC" \
  --ld="$CC" \
  --host-cc="$CC" \
  --host-ld="$CC" \
  --host-cflags="$COMMON_CFLAGS" \
  --host-ldflags="$COMMON_LDFLAGS" \
  --sysroot="$SDKROOT" \
  --stdc=c11 \
  --extra-cflags="-I$PREFIX/include $COMMON_CFLAGS" \
  --extra-ldflags="-L$PREFIX/lib $COMMON_LDFLAGS" \
  --pkg-config-flags="--static" \
  --enable-static \
  --disable-shared \
  --disable-debug \
  --disable-doc \
  --disable-ffplay \
  --disable-sdl2 \
  --disable-network \
  --enable-videotoolbox \
  --enable-gpl \
  --enable-libmp3lame \
  --enable-libopus \
  --enable-libx264 \
  --enable-libwebp
make -j"$JOBS" ffmpeg ffprobe
"$STRIP" -x ffmpeg ffprobe
install -m 755 ffmpeg "$STAGING/ffmpeg/ffmpeg"
install -m 755 ffprobe "$STAGING/ffmpeg/ffprobe"
popd >/dev/null


# Motores sociales especializados. Se empaquetan como binarios ARM64 autosuficientes.
"$ROOT/Scripts/prepare_social_engines_macos.sh" "$STAGING" "$BUILD_ROOT/social-engines"
printf '%s\n' "El navegador de compatibilidad se instala opcionalmente desde Ajustes y no forma parte del paquete base." > "$STAGING/licenses/playwright-browser/NOT_PROVIDED.txt"

# 3. Avisos y licencias fijados a las mismas versiones.
copy_existing_license "licenses/yt-dlp/LICENSE" "$STAGING/licenses/yt-dlp/LICENSE"
copy_existing_license "licenses/yt-dlp/THIRD_PARTY_LICENSES.txt" "$STAGING/licenses/yt-dlp/THIRD_PARTY_LICENSES.txt"
copy_existing_license "licenses/deno/LICENSE.md" "$STAGING/licenses/deno/LICENSE.md"
install -m 644 "$SOURCES/ffmpeg-${FFMPEG_VERSION}/COPYING.GPLv2" "$STAGING/licenses/ffmpeg/COPYING.GPLv2"
if [[ -f "$SOURCES/ffmpeg-${FFMPEG_VERSION}/LICENSE.md" ]]; then install -m 644 "$SOURCES/ffmpeg-${FFMPEG_VERSION}/LICENSE.md" "$STAGING/licenses/ffmpeg/LICENSE.md"; fi
install -m 644 "$SOURCES/opus-${OPUS_VERSION}/COPYING" "$STAGING/licenses/opus/COPYING"
install -m 644 "$SOURCES/lame-${LAME_VERSION}/COPYING" "$STAGING/licenses/lame/COPYING"
install -m 644 "$SOURCES/x264-${X264_REVISION}/COPYING" "$STAGING/licenses/x264/COPYING"
install -m 644 "$SOURCES/libwebp-${LIBWEBP_VERSION}/COPYING" "$STAGING/licenses/libwebp/COPYING"
copy_existing_license "licenses/pandoc/COPYING.md" "$STAGING/licenses/pandoc/COPYING.md"

# 4. Manifiesto con hashes y tamaños reales del staging.
ENGINE_ROOT="$STAGING" \
YTDLP_VERSION="$YTDLP_VERSION" DENO_VERSION="$DENO_VERSION" FFMPEG_VERSION="$FFMPEG_VERSION" \
GALLERY_DL_VERSION="$GALLERY_DL_VERSION" INSTALOADER_VERSION="$INSTALOADER_VERSION" \
PANDOC_VERSION="$PANDOC_VERSION" PANDOC_URL="$PANDOC_URL" python3 <<'PY'
from __future__ import annotations
import hashlib, json, os
from pathlib import Path
engines = Path(os.environ['ENGINE_ROOT'])
def entry(name, executable, relative, version, architecture, source, license_file, purpose, args, requirement='required'):
    path = engines / relative
    return {
        'name': name,
        'executable': executable,
        'relativePath': relative,
        'version': version,
        'architecture': architecture,
        'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
        'source': source,
        'licenseFile': license_file,
        'purpose': purpose,
        'diagnosticArguments': args,
        'size': path.stat().st_size,
        'requirement': requirement,
    }
def optional_entry(name, executable, relative, version, architecture, source, license_file, purpose, args):
    path = engines / relative
    if path.is_file():
        return entry(name, executable, relative, version, architecture, source, license_file, purpose, args, 'optional')
    return {
        'name': name,
        'executable': executable,
        'relativePath': relative,
        'version': version,
        'architecture': architecture,
        'sha256': '0' * 64,
        'source': source,
        'licenseFile': license_file,
        'purpose': purpose,
        'diagnosticArguments': args,
        'size': 0,
        'requirement': 'optional',
    }

def bundle_integrity(directory):
    digest = hashlib.sha256()
    total_size = 0
    file_count = 0
    for path in sorted((item for item in directory.rglob('*') if item.is_file()), key=lambda item: item.relative_to(directory).as_posix()):
        relative = path.relative_to(directory).as_posix().encode('utf-8')
        payload = path.read_bytes()
        digest.update(len(relative).to_bytes(4, 'big'))
        digest.update(relative)
        digest.update(len(payload).to_bytes(8, 'big'))
        digest.update(payload)
        total_size += len(payload)
        file_count += 1
    return digest.hexdigest(), total_size, file_count
def with_bundle(item, root):
    item['bundleSHA256'], item['bundleSize'], item['bundleFileCount'] = bundle_integrity(root)
    return item

yt_dlp = with_bundle(entry('yt-dlp', 'yt-dlp_macos', 'yt-dlp/yt-dlp_macos', os.environ['YTDLP_VERSION'], 'universal',
               'local-bundle:yt-dlp/yt-dlp_macos',
               'licenses/yt-dlp/LICENSE', 'Analizar y descargar contenido público o autorizado de plataformas compatibles.', ['--version']), engines / 'yt-dlp')
pandoc = with_bundle(entry('pandoc', 'pandoc', 'pandoc/bin/pandoc', os.environ['PANDOC_VERSION'], 'arm64',
                     os.environ['PANDOC_URL'], 'licenses/pandoc/COPYING.md',
                     'Convertir texto, Markdown y HTML de forma local.', ['--version'], 'optional'), engines / 'pandoc')
manifest = {
    'schemaVersion': 1,
    'engines': [
        yt_dlp,
        entry('deno', 'deno', 'deno/deno', os.environ['DENO_VERSION'], 'arm64',
              f"https://dl.deno.land/release/v{os.environ['DENO_VERSION']}/deno-aarch64-apple-darwin.zip",
              'licenses/deno/LICENSE.md', 'Ejecutar los desafíos JavaScript requeridos por YouTube a petición de yt-dlp.', ['--version']),
        entry('ffmpeg', 'ffmpeg', 'ffmpeg/ffmpeg', os.environ['FFMPEG_VERSION'], 'arm64',
              f"https://ffmpeg.org/releases/ffmpeg-{os.environ['FFMPEG_VERSION']}.tar.xz",
              'licenses/ffmpeg/COPYING.GPLv2', 'Convertir audio, vídeo, animaciones, secuencias, metadatos y subtítulos.', ['-version']),
        entry('ffprobe', 'ffprobe', 'ffmpeg/ffprobe', os.environ['FFMPEG_VERSION'], 'arm64',
              f"https://ffmpeg.org/releases/ffmpeg-{os.environ['FFMPEG_VERSION']}.tar.xz",
              'licenses/ffmpeg/COPYING.GPLv2', 'Inspeccionar y validar resultados multimedia.', ['-version']),
        entry('gallery-dl', 'gallery-dl', 'gallery-dl/gallery-dl', os.environ['GALLERY_DL_VERSION'], 'arm64',
              f"https://pypi.org/project/gallery-dl/{os.environ['GALLERY_DL_VERSION']}/",
              'licenses/gallery-dl/LICENSE', 'Analizar y descargar fotografías, vídeos, carruseles, álbumes y galerías compatibles.', ['--version']),
        entry('instaloader-zeuve', 'instaloader-zeuve', 'instaloader/instaloader-zeuve', os.environ['INSTALOADER_VERSION'] + '-zeuve.2', 'arm64',
              f"https://pypi.org/project/instaloader/{os.environ['INSTALOADER_VERSION']}/",
              'licenses/instaloader/LICENSE', 'Resolver publicaciones directas y catalogar perfiles y contenido multimedia de Instagram.', ['--version']),
        optional_entry('playwright-browser', 'zeuve-browser-helper', 'playwright/zeuve-browser-helper', 'not-provided-0.10.0', 'arm64',
              'https://playwright.dev/', 'licenses/playwright-browser/NOT_PROVIDED.txt',
              'Compatibilidad opcional de último recurso para páginas dinámicas.', ['--version']),
        pandoc,
    ],
}
(engines / 'engines.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + '\n')
PY

# 5. Solo se sustituye Resources/Engines después de verificar el conjunto completo.
"$ROOT/Scripts/verify_engines_macos.sh" "$STAGING"
publish_staging

echo "Motores preparados y publicados en: $RESOURCES"
echo "Los motores anteriores se conservaron hasta completar la verificación final."
echo "El directorio temporal puede eliminarse con: rm -rf '$BUILD_ROOT'"
