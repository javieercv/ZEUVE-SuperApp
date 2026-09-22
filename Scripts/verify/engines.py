#!/usr/bin/env python3
from __future__ import annotations

import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)

# Regresión: Calibre y Ghostscript no pueden volver a registrarse, prepararse o empaquetarse.
from pathlib import Path
paths = [
    Path('Resources/Engines/engines.json'),
    Path('Scripts/prepare_engines_macos.sh'),
    Path('Scripts/sign_embedded_engines.sh'),
    Path('Scripts/verify_engines_macos.sh'),
    Path('Scripts/verify_packaged_engines_macos.sh'),
]
for path in paths:
    text = path.read_text(errors='ignore').lower()
    for forbidden in ['calibre', 'ghostscript']:
        if forbidden in text:
            raise SystemExit(f'{path} vuelve a contener el motor retirado: {forbidden}')
for path in [
    Path('Sources/UniversalConverterModule/Execution/CalibreCommandBuilder.swift'),
    Path('Sources/UniversalConverterModule/Execution/GhostscriptCommandBuilder.swift'),
    Path('Resources/Engines/calibre'),
    Path('Resources/Engines/ghostscript'),
]:
    if path.exists():
        raise SystemExit('Recurso retirado todavía presente: ' + path.as_posix())
prepare = Path('Scripts/prepare_engines_macos.sh').read_text()
for required in ['PANDOC_VERSION="3.10"', 'pandoc/bin/pandoc', "'Convertir texto, Markdown y HTML de forma local.'"]:
    if required not in prepare:
        raise SystemExit('Pandoc no se conserva correctamente: ' + required)

# Regresión: la firma de macOS no puede invalidar los motores por tamaño o SHA-256 en ejecución.
from pathlib import Path
text = Path('Sources/ZEUVEEngines/EngineDiagnostics.swift').read_text()
for forbidden in ['descriptor.size', 'SHA256.hexDigest(fileAt: url)']:
    if forbidden in text:
        raise SystemExit('El diagnóstico en ejecución vuelve a comparar un valor alterado por codesign: ' + forbidden)
for required in ['fileExists(atPath:', 'isExecutableFile(atPath:', 'MachOInspector.satisfies', 'diagnosticArguments', 'technicalDetails:', 'Salida de error:']:
    if required not in text:
        raise SystemExit('El diagnóstico ha perdido una comprobación obligatoria: ' + required)
view = Path('Sources/ZEUVEApp/SettingsView.swift').read_text() + '\n' + '\n'.join(path.read_text() for path in Path('Sources/ZEUVEApp/UniversalDownloader/Settings').rglob('*.swift'))
if 'DisclosureGroup("Detalles técnicos")' not in view:
    raise SystemExit('La interfaz no permite consultar los detalles técnicos del fallo del motor.')

# Regresión: yt-dlp conserva su firma oficial y se comprueba dentro de la app empaquetada.
from pathlib import Path
sign = Path('Scripts/sign_embedded_engines.sh').read_text()
verify = Path('Scripts/verify_packaged_engines_macos.sh').read_text()
preserved = sign.split('PRESERVED_EXECUTABLES=(', 1)[1].split(')', 1)[0]
resigned = sign.split('RESIGNED_EXECUTABLES=(', 1)[1].split(')', 1)[0]
if 'libreoffice' in sign.lower() or 'soffice' in sign.lower():
    raise SystemExit('La política de firma todavía contiene LibreOffice.')
if 'yt-dlp/yt-dlp_macos' not in preserved:
    raise SystemExit('yt-dlp no figura entre los ejecutables cuya firma debe conservarse.')
if 'deno/deno' not in preserved:
    raise SystemExit('Deno no conserva la firma oficial necesaria para ejecutar V8 con JIT.')
if 'yt-dlp' in resigned:
    raise SystemExit('yt-dlp vuelve a firmarse con la identidad de ZEUVE.')
if 'deno/deno' in resigned:
    raise SystemExit('Deno vuelve a firmarse sin conservar sus autorizaciones oficiales de JIT.')
for required in ['deno/deno', 'ffmpeg/ffmpeg', 'ffmpeg/ffprobe', 'gallery-dl/gallery-dl', 'instaloader/instaloader-zeuve', 'verify_packaged_engines_macos.sh']:
    if required not in sign:
        raise SystemExit('La política de firma está incompleta: ' + required)
for required in ['codesign --verify --strict', '"$YTDLP" --version', 'YTDLP_STATUS', '"$DENO" eval', 'ZEUVE_DENO_JIT_OK']:
    if required not in verify:
        raise SystemExit('La verificación del paquete está incompleta: ' + required)
build = Path('Scripts/build_macos.sh').read_text()
if 'verify_packaged_engines_macos.sh "$APP_PATH"' not in build:
    raise SystemExit('La compilación por Terminal no vuelve a verificar la aplicación final.')
if 'clean build' not in build or 'codesign --verify --deep --strict --verbose=2 "$APP_PATH"' not in build:
    raise SystemExit('La compilación por Terminal no garantiza un paquete limpio con firma profunda válida.')

# No puede existir una vía de descarga automática de motores durante el uso normal.
from pathlib import Path
for root in [Path('Sources')]:
    for path in root.rglob('*'):
        if not path.is_file() or path.suffix not in {'.swift','.c','.h','.json'}: continue
        text = path.read_text(errors='ignore')
        forbidden = ['--remote-components', 'brew install', '/bin/sh -c', 'ProcessInfo.processInfo.environment["PATH"]']
        for value in forbidden:
            if value in text:
                raise SystemExit(f'Contenido prohibido en {path}: {value}')
commands = Path('Sources/UniversalDownloaderModule/Engines/YTDLP/YTDLPCommandBuilder.swift').read_text()
for required in ['--no-update', '--ignore-config', '--cache-dir', '--js-runtimes', '--ffmpeg-location']:
    if required not in commands:
        raise SystemExit('Falta política obligatoria de yt-dlp: ' + required)

# Los motores compartidos deben residir una sola vez en Resources/Engines.
from pathlib import Path
roots = []
for base in [Path('Resources'), Path('Sources'), Path('Tests')]:
    if not base.exists():
        continue
    for path in base.rglob('*'):
        if path.is_file() and path.name in {'ffmpeg','ffprobe'}:
            roots.append(path.as_posix())
for path in roots:
    if not path.startswith('Resources/Engines/ffmpeg/'):
        raise SystemExit('FFmpeg duplicado fuera del registro compartido: ' + path)
if Path('Resources/Engines/engines.json').exists():
    import json
    data=json.loads(Path('Resources/Engines/engines.json').read_text())
    assert sum(1 for x in data['engines'] if x['name']=='ffmpeg') == 1
    assert sum(1 for x in data['engines'] if x['name']=='ffprobe') == 1

# La compilación local no prepara motores sociales durante el build.
from pathlib import Path
build = Path('Scripts/build_macos.sh').read_text()
generator = Path('Scripts/generate_xcode_project.py').read_text()
prepare = Path('Scripts/prepare_social_engines_macos.sh').read_text()
if 'python3 Scripts/check_social_engines.py Resources/Engines' not in build:
    raise SystemExit('La build normal no comprueba los motores sociales obligatorios.')
if '\nScripts/prepare_social_engines_macos.sh Resources/Engines' in build:
    raise SystemExit('La build normal prepara motores sociales automáticamente.')
if 'check_social_engines.py' not in generator:
    raise SystemExit('El proyecto Xcode no comprueba los motores sociales obligatorios.')
if 'shellScript = "Scripts/prepare_social_engines_macos.sh' in generator:
    raise SystemExit('El proyecto Xcode prepara motores sociales automáticamente.')
checker = Path('Scripts/check_social_engines.py').read_text()
helper = Path('Scripts/engine_helpers/instagram_catalog.py').read_text()
full_prepare = Path('Scripts/prepare_engines_macos.sh').read_text()
for source, label in [(checker, 'comprobador'), (prepare, 'preparador'), (helper, 'ayudante')]:
    if '4.15.3-zeuve.2' not in source:
        raise SystemExit(f'La revisión social vigente no está fijada en el {label}.')
if 'refresh_social_engine_manifest.py' not in prepare:
    raise SystemExit('La preparación social no actualiza hashes y tamaños reales.')
for source, label in [(prepare, 'preparador social'), (full_prepare, 'preparador completo')]:
    if 'INSTALOADER_VERSION="4.15.3"' not in source:
        raise SystemExit(f'Instaloader 4.15.3 no está fijado en el {label}.')

# La documentación modular mínima debe existir y no contener marcadores de trabajo incompleto.
from pathlib import Path
text = Path('Scripts/prepare_engines_macos.sh').read_text()
required = [
    'PROJECT_KEY=',
    'STAGING="$BUILD_ROOT/staging/Engines"',
    'publish_staging()',
    'verify_engines_macos.sh" "$STAGING"',
    'libmp3lame.pc',
    '--variable=includedir opus',
    'yt-dlp_macos.zip',
    'yt-dlp/yt-dlp_macos',
    '--enable-libx264',
    '--enable-libwebp',
    'make install-lib-static',
    'PANDOC_VERSION="3.10"',
]
missing = [snippet for snippet in required if snippet not in text]
if missing:
    raise SystemExit('La preparación segura de motores está incompleta: ' + ', '.join(missing))
forbidden = [
    'BUILD_ROOT="${TMPDIR%/}/ZEUVE-engine-build-0.2.0"',
    'rm -rf "$RESOURCES/yt-dlp"',
    'make install-lib-static install-headers',
    'make install-headers',
]
present = [snippet for snippet in forbidden if snippet in text]
if present:
    raise SystemExit('La preparación de motores conserva un patrón inseguro: ' + ', '.join(present))
