#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

SWIFT_JOBS="${ZEUVE_SWIFT_JOBS:-1}"
swift test --jobs "$SWIFT_JOBS"
swift build -c release --jobs "$SWIFT_JOBS"

# Regresión: las vistas que usan tipos de ZEUVECore deben importarlo por archivo.
grep -qx 'import ZEUVECore' Sources/ZEUVEApp/DashboardView.swift
grep -qx 'import ZEUVECore' Sources/ZEUVEApp/RootView.swift

# Regresión: AppModel debe resolver por completo el estado local antes de asignar self.
python3 - <<'PY_CHECK'
from pathlib import Path
text = Path('Sources/ZEUVEApp/AppModel.swift').read_text()
required = [
    'let localCoordinator = OperationCoordinator()',
    'let localRegistry = ModuleRegistry()',
    'let initialState:',
    'initialState = (',
    'storage: container,',
    'organizer: loadedOrganizer',
    'organizer: OrganizerViewModel.unavailable(message: message)',
    'youtubeDownloader = YouTubeDownloaderViewModel',
    'globalHistory = GlobalHistoryViewModel',
    'coordinator = localCoordinator',
    'registry = localRegistry',
    'storage = initialState.storage',
    'organizer = initialState.organizer',
    'theme = initialState.theme',
    'startupError = initialState.startupError',
]
missing = [snippet for snippet in required if snippet not in text]
if missing:
    raise SystemExit('AppModel no conserva el patrón de inicialización seguro: ' + ', '.join(missing))
forbidden = [
    'storage = container',
    'organizer = loadedOrganizer',
    'OrganizerViewModel.unavailable(message: startupError',
]
present = [snippet for snippet in forbidden if snippet in text]
if present:
    raise SystemExit('AppModel ha recuperado un patrón de inicialización inseguro: ' + ', '.join(present))
PY_CHECK


# Versión, arquitectura modular y políticas del descargador.
python3 - <<'PY_CHECK'
from pathlib import Path
import json
assert Path('VERSION').read_text().strip() == '0.7.5'
pbx = Path('ZEUVE.xcodeproj/project.pbxproj').read_text()
for required in ['MARKETING_VERSION = 0.7.5;', 'CURRENT_PROJECT_VERSION = 26;', 'ENABLE_HARDENED_RUNTIME = YES;', 'ZEUVEEngines', 'YouTubeDownloaderModule', 'ChatAnalyzerModule', 'UniversalConverterModule', 'Engines in Resources']:
    if required not in pbx:
        raise SystemExit('El proyecto Xcode no contiene: ' + required)
package = Path('Package.swift').read_text()
for required in ['ZEUVEEngines', 'YouTubeDownloaderModule', 'ChatAnalyzerModule', 'UniversalConverterModule', 'CLibArchive', 'CZEUVEProcess']:
    if required not in package:
        raise SystemExit('Package.swift no contiene: ' + required)
manifest = json.loads(Path('Sources/YouTubeDownloaderModule/Resources/manifest.json').read_text())
assert manifest['identifier'] == 'com.zeuve.youtube-downloader'
assert manifest['version'] == '0.4.1'
assert manifest['minimumZEUVEVersion'] == '0.2.0'
assert manifest['technology'] == 'mixed' and manifest['executionMode'] == 'builtIn'
assert 'browserCookies' not in manifest['permissions']
organizer = json.loads(Path('Sources/OrganizerModule/Resources/manifest.json').read_text())
assert 'openExternalApplications' in organizer['permissions']
chat = json.loads(Path('Sources/ChatAnalyzerModule/Resources/manifest.json').read_text())
assert chat['identifier'] == 'com.zeuve.chat-analyzer'
assert chat['version'] == '0.1.6'
assert chat['minimumZEUVEVersion'] == '0.5.0'
assert chat['technology'] == 'swift' and chat['executionMode'] == 'builtIn'
assert chat['permissions'] == ['readUserSelectedFiles']
assert 'networkAccess' not in chat['permissions']
converter = json.loads(Path('Sources/UniversalConverterModule/Resources/manifest.json').read_text())
assert converter['identifier'] == 'com.zeuve.universal-converter'
assert converter['version'] == '0.2.2'
assert converter['minimumZEUVEVersion'] == '0.7.0'
assert converter['technology'] == 'mixed' and converter['executionMode'] == 'builtIn'
assert 'networkAccess' not in converter['permissions']
engines = json.loads(Path('Resources/Engines/engines.json').read_text())
engine_names = {item['name'] for item in engines['engines']}
assert engine_names == {'yt-dlp','deno','ffmpeg','ffprobe','pandoc','calibre','ghostscript'}
yt_dlp = next(item for item in engines['engines'] if item['name'] == 'yt-dlp')
for name in {'pandoc','calibre','ghostscript'}:
    item = next(entry for entry in engines['engines'] if entry['name'] == name)
    assert item['requirement'] == 'optional'
    assert item['size'] >= 0
for required in ['bundleSHA256', 'bundleSize', 'bundleFileCount']:
    assert required in yt_dlp, 'Falta integridad del paquete descomprimido: ' + required
PY_CHECK

# Regresión: la licencia de Calibre debe descargarse desde el archivo existente del tag fijado.
python3 - <<'PY_CHECK'
from pathlib import Path
text = Path('Scripts/prepare_engines_macos.sh').read_text()
required = 'https://raw.githubusercontent.com/kovidgoyal/calibre/v${CALIBRE_VERSION}/LICENSE'
forbidden = 'https://raw.githubusercontent.com/kovidgoyal/calibre/v${CALIBRE_VERSION}/COPYING'
if required not in text:
    raise SystemExit('La preparación no usa la licencia LICENSE de Calibre.')
if forbidden in text:
    raise SystemExit('La preparación conserva la URL inexistente COPYING de Calibre.')
for required_path in [
    '$DOWNLOADS/licenses/calibre/LICENSE',
    '$STAGING/licenses/calibre/LICENSE',
    'CALIBRE_LICENSE_REL="licenses/calibre/LICENSE"',
]:
    if required_path not in text:
        raise SystemExit('La licencia de Calibre no se publica correctamente: ' + required_path)
PY_CHECK

# Regresión: la firma de macOS no puede invalidar los motores por tamaño o SHA-256 en ejecución.
python3 - <<'PY_CHECK'
from pathlib import Path
text = Path('Sources/ZEUVEEngines/EngineDiagnostics.swift').read_text()
for forbidden in ['descriptor.size', 'SHA256.hexDigest(fileAt: url)']:
    if forbidden in text:
        raise SystemExit('El diagnóstico en ejecución vuelve a comparar un valor alterado por codesign: ' + forbidden)
for required in ['fileExists(atPath:', 'isExecutableFile(atPath:', 'MachOInspector.satisfies', 'diagnosticArguments', 'technicalDetails:', 'Salida de error:']:
    if required not in text:
        raise SystemExit('El diagnóstico ha perdido una comprobación obligatoria: ' + required)
view = Path('Sources/ZEUVEApp/SettingsView.swift').read_text()
if 'DisclosureGroup("Detalles técnicos")' not in view:
    raise SystemExit('La interfaz no permite consultar los detalles técnicos del fallo del motor.')
PY_CHECK


# Regresión: yt-dlp conserva su firma oficial y se comprueba dentro de la app empaquetada.
python3 - <<'PY_CHECK'
from pathlib import Path
sign = Path('Scripts/sign_embedded_engines.sh').read_text()
verify = Path('Scripts/verify_packaged_engines_macos.sh').read_text()
preserved = sign.split('PRESERVED_EXECUTABLES=(', 1)[1].split(')', 1)[0]
resigned = sign.split('RESIGNED_EXECUTABLES=(', 1)[1].split(')', 1)[0]
if 'libreoffice' in sign.lower() or 'soffice' in sign.lower():
    raise SystemExit('La política de firma todavía contiene LibreOffice.')
if 'yt-dlp/yt-dlp_macos' not in preserved:
    raise SystemExit('yt-dlp no figura entre los ejecutables cuya firma debe conservarse.')
if 'yt-dlp' in resigned:
    raise SystemExit('yt-dlp vuelve a firmarse con la identidad de ZEUVE.')
for required in ['deno/deno', 'ffmpeg/ffmpeg', 'ffmpeg/ffprobe', 'verify_packaged_engines_macos.sh']:
    if required not in sign:
        raise SystemExit('La política de firma está incompleta: ' + required)
for required in ['codesign --verify --strict', '"$YTDLP" --version', 'YTDLP_STATUS', 'Calibre.app']:
    if required not in verify:
        raise SystemExit('La verificación del paquete está incompleta: ' + required)
build = Path('Scripts/build_macos.sh').read_text()
if 'verify_packaged_engines_macos.sh "$APP_PATH"' not in build:
    raise SystemExit('La compilación por Terminal no vuelve a verificar la aplicación final.')
PY_CHECK

# No puede existir una vía de descarga automática de motores durante el uso normal.
python3 - <<'PY_CHECK'
from pathlib import Path
for root in [Path('Sources')]:
    for path in root.rglob('*'):
        if not path.is_file() or path.suffix not in {'.swift','.c','.h','.json'}: continue
        text = path.read_text(errors='ignore')
        forbidden = ['--remote-components', 'brew install', '/bin/sh -c', 'ProcessInfo.processInfo.environment["PATH"]']
        for value in forbidden:
            if value in text:
                raise SystemExit(f'Contenido prohibido en {path}: {value}')
commands = Path('Sources/YouTubeDownloaderModule/Commands/YouTubeCommandBuilder.swift').read_text()
for required in ['--no-update', '--ignore-config', '--cache-dir', '--js-runtimes', '--ffmpeg-location']:
    if required not in commands:
        raise SystemExit('Falta política obligatoria de yt-dlp: ' + required)
PY_CHECK

# Los motores compartidos deben residir una sola vez en Resources/Engines.
python3 - <<'PY_CHECK'
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
PY_CHECK

# Regresión: LocalLogger.write devuelve una URL; ignorarla debe ser explícito.
python3 - <<'PY_CHECK'
from pathlib import Path
for path in Path('Sources').rglob('*.swift'):
    for number, line in enumerate(path.read_text().splitlines(), 1):
        if 'try? await logger?.write' in line and '_ = try?' not in line:
            raise SystemExit(f'{path}:{number}: resultado de LocalLogger.write ignorado sin "_ ="')
PY_CHECK

# SQLite y libarchive usan el SDK/sistema mediante module.modulemap, sin Homebrew o pkg-config.
python3 - <<'PY_CHECK'
from pathlib import Path
text = Path('Package.swift').read_text()
for forbidden in ['pkgConfig: "sqlite3"', 'providers: [.brew(["sqlite3"])', 'pkgConfig: "libarchive"', 'providers: [.brew(["libarchive"])']:
    if forbidden in text:
        raise SystemExit('Package.swift contiene una dependencia del entorno de desarrollo: ' + forbidden)
for module, link in [('CSQLite', 'sqlite3'), ('CLibArchive', 'archive')]:
    modulemap = Path(f'Sources/{module}/module.modulemap').read_text()
    for required in ['header "shim.h"', f'link "{link}"']:
        if required not in modulemap:
            raise SystemExit(f'{module}/module.modulemap está incompleto: falta ' + required)
PY_CHECK

# Las reglas permanentes de rendimiento e interacción deben estar completas y numeradas.
python3 - <<'PY_CHECK'
from pathlib import Path
import re
text = Path('SUPERAPP_PROJECT_RULES.md').read_text()
expected = {
    64: 'INTERFAZ RESPONSIVA Y CÁLCULOS FUERA DEL HILO PRINCIPAL',
    65: 'CACHÉ E INVALIDACIÓN SELECTIVA',
    66: 'CÁLCULO BAJO DEMANDA',
    67: 'CANCELACIÓN Y DESCARTE DE RESULTADOS OBSOLETOS',
    68: 'ESPERA BREVE EN CAMBIOS REPETITIVOS',
    69: 'SEPARACIÓN DEL ESTADO VISUAL Y DEL ESTADO ANALÍTICO',
    70: 'OBSERVACIÓN DIRECTA DE LA FUENTE REAL DEL ESTADO',
    71: 'ESTÁNDAR COMÚN PARA GRÁFICOS INTERACTIVOS',
    72: 'VISIBILIDAD Y POSICIONAMIENTO DE TOOLTIPS',
    73: 'INTERACCIÓN GRÁFICA LIGERA',
    74: 'COHERENCIA ENTRE GRÁFICOS',
    75: 'REGRESIONES DE RENDIMIENTO',
    76: 'PRUEBAS CON VOLÚMENES REPRESENTATIVOS',
    77: 'VALIDACIÓN EN EL ENTORNO OBJETIVO',
    78: 'REGLA FINAL',
}
headings = {int(n): title.strip() for n, title in re.findall(r'(?m)^(\d+)\. ([A-ZÁÉÍÓÚÜÑ][^\n]+)$', text)}
for number, title in expected.items():
    if headings.get(number) != title:
        raise SystemExit(f'Regla {number} ausente o incorrecta: {headings.get(number)!r}')
if text.count('REGLA FINAL') != 1:
    raise SystemExit('Debe existir una única REGLA FINAL')
for phrase in [
    'Un cambio puramente visual',
    'Un resultado antiguo nunca debe sustituir a uno más reciente',
    'Mover el cursor, seleccionar visualmente un dato o mostrar un tooltip no debe iniciar nuevos análisis',
    'Las pruebas automáticas realizadas en otro sistema operativo no sustituyen',
]:
    if phrase not in text:
        raise SystemExit('Falta una política aprobada: ' + phrase)
PY_CHECK

# Regresiones de rendimiento de ZEUVE 0.7.4.
python3 - <<'PY_CHECK'
from pathlib import Path
checks = {
    'Sources/ZEUVECore/LatestValueCoalescer.swift': ['generation', 'deliveryLock', 'minimumIntervalNanoseconds'],
    'Sources/ChatAnalyzerModule/Analysis/ChatSearchTextCache.swift': ['ChatSearchTextCache', 'mappedIfSafe', 'memoryThresholdBytes'],
    'Sources/ChatAnalyzerModule/Storage/ChatAnalyzerStorage.swift': ['executeBatch'],
    'Sources/ZEUVEStorage/StorageMigrations.swift': ['history_created'],
    'Sources/ZEUVEApp/AppModel.swift': ['sharedEngineRegistry', 'sharedEngineDiagnostics'],
    'Sources/ZEUVEApp/ChatAnalyzer/ChatAnalyzerViewModel.swift': ['searchTextCache', 'textIndex: compactIndex'],
    'Sources/ZEUVEApp/UniversalConverter/UniversalConverterViewModel.swift': ['inputScanner', 'engineDiagnostics: EngineDiagnosticService?'],
}
for filename, snippets in checks.items():
    text = Path(filename).read_text()
    missing = [value for value in snippets if value not in text]
    if missing:
        raise SystemExit(f'Regresión de rendimiento en {filename}: {missing}')
service = Path('Sources/ChatAnalyzerModule/ChatAnalyzerService.swift').read_text()
if '_ = ChatAnalytics.summary(all: messages, included: messages)' in service:
    raise SystemExit('Se ha recuperado el cálculo descartado del resumen del Analizador.')
PY_CHECK

# Regresiones de conversión real y vídeo a fotogramas de ZEUVE 0.7.5.
python3 - <<'PY_CHECK'
from pathlib import Path
builder = Path('Sources/UniversalConverterModule/Execution/FFmpegCommandBuilder.swift').read_text()
planner = Path('Sources/UniversalConverterModule/Planning/ConversionPlanner.swift').read_text()
execution = Path('Sources/UniversalConverterModule/Execution/UniversalConverterExecutionService.swift').read_text()
workspace = Path('Sources/UniversalConverterModule/Execution/ConverterWorkspace.swift').read_text()
visible = Path('Sources/UniversalConverterModule/Execution/VisibleFrameOutputSession.swift').read_text()
view_model = Path('Sources/ZEUVEApp/UniversalConverter/UniversalConverterViewModel.swift').read_text()
help_text = Path('Sources/ZEUVEApp/UniversalConverter/UniversalConverterHelp.swift').read_text()
for required in ['showinfo=checksum=0', '"-compression_level", "3"', '"-pred", "up"']:
    if required not in builder:
        raise SystemExit('Se ha perdido una optimización de fotogramas: ' + required)
for required in ['options.advancedMode', 'options.preferRemuxWhenPossible', '"-c:v", "copy"']:
    if required not in builder + planner:
        raise SystemExit('La copia rápida de vídeo no conserva su control avanzado: ' + required)
for required in ['VisibleFrameOutputCoordinator', 'preserveIncompleteFrames', 'result.wasCancelled', 'FrameTimingCSVCollector']:
    if required not in execution + visible:
        raise SystemExit('Falta una protección del flujo visible de fotogramas: ' + required)
for required in ['recoverAbandonedVisibleFrameOutputs', 'visibleFrameRecordURL']:
    if required not in workspace:
        raise SystemExit('Falta recuperación de fotogramas incompletos: ' + required)
for required in ['universalConverter.defaults.v4', 'legacySettingsV3Key', 'universalConverter.presets.v4', 'legacyPresetsV3Key']:
    if required not in view_model:
        raise SystemExit('Falta migración segura de los ajustes de recodificación: ' + required)
for required in ['Copia rápida sin recodificar', 'no reduce el tamaño']:
    if required not in help_text + Path('Sources/ZEUVEApp/UniversalConverter/UniversalConverterView.swift').read_text():
        raise SystemExit('La interfaz no explica correctamente el remux: ' + required)
PY_CHECK

# La documentación modular mínima debe existir y no contener marcadores de trabajo incompleto.
python3 - <<'PY_CHECK'
from pathlib import Path
required = [
    'Docs/MODULE_DEVELOPMENT_GUIDE.md',
    'Docs/MODULE_CHAT_INSTRUCTIONS.md',
    'Docs/MODULE_IMPLEMENTATION_CHECKLIST.md',
    'Docs/MODULE_BRIEF_TEMPLATE.md',
    'Docs/MODULE_EXAMPLES.md',
    'Docs/MODULE_API.md',
    'Docs/YOUTUBE_DOWNLOADER.md',
    'Docs/YOUTUBE_ENGINES.md',
    'Docs/YOUTUBE_PRIVACY_AND_NETWORK.md',
    'Docs/YOUTUBE_PACKAGING.md',
    'Docs/ENGINE_HASHES_0.2.0.md',
    'Docs/ENGINE_HASHES_0.2.4.md',
    'Docs/TEST_RESULTS_0.2.0.md',
    'Docs/DELIVERY_0.2.0.md',
    'Docs/TEST_RESULTS_0.2.1.md',
    'Docs/DELIVERY_0.2.1.md',
    'Docs/TEST_RESULTS_0.2.2.md',
    'Docs/DELIVERY_0.2.2.md',
    'Docs/TEST_RESULTS_0.2.3.md',
    'Docs/DELIVERY_0.2.3.md',
    'Docs/TEST_RESULTS_0.2.4.md',
    'Docs/DELIVERY_0.2.4.md',
    'Docs/TEST_RESULTS_0.3.0.md',
    'Docs/DELIVERY_0.3.0.md',
    'Docs/TEST_RESULTS_0.4.0.md',
    'Docs/DELIVERY_0.4.0.md',
    'Docs/CHAT_ANALYZER.md',
    'Docs/TEST_RESULTS_0.5.0.md',
    'Docs/DELIVERY_0.5.0.md',
    'Docs/TEST_RESULTS_0.5.1.md',
    'Docs/DELIVERY_0.5.1.md',
    'Docs/TEST_RESULTS_0.5.2.md',
    'Docs/DELIVERY_0.5.2.md',
    'Docs/TEST_RESULTS_0.5.5.md',
    'Docs/DELIVERY_0.5.5.md',
    'Docs/TEST_RESULTS_0.5.6.md',
    'Docs/DELIVERY_0.5.6.md',
    'Docs/UNIVERSAL_CONVERTER.md',
    'Docs/TEST_RESULTS_0.6.0.md',
    'Docs/DELIVERY_0.6.0.md',
    'Docs/COMPATIBILITY_MATRIX_0.7.0.md',
    'Docs/IMPLEMENTATION_REPORT_0.7.0.md',
    'Docs/TEST_RESULTS_0.7.0.md',
    'Docs/DELIVERY_0.7.0.md',
    'Docs/IMPLEMENTATION_REPORT_0.7.2.md',
    'Docs/TEST_RESULTS_0.7.2.md',
    'Docs/DELIVERY_0.7.2.md',
    'Docs/IMPLEMENTATION_REPORT_0.7.3.md',
    'Docs/TEST_RESULTS_0.7.3.md',
    'Docs/DELIVERY_0.7.3.md',
    'Docs/IMPLEMENTATION_REPORT_0.7.4.md',
    'Docs/TEST_RESULTS_0.7.4.md',
    'Docs/DELIVERY_0.7.4.md',
    'Docs/IMPLEMENTATION_REPORT_0.7.5.md',
    'Docs/TEST_RESULTS_0.7.5.md',
    'Docs/DELIVERY_0.7.5.md',
]
for name in required:
    path = Path(name)
    if not path.is_file() or path.stat().st_size < 200:
        raise SystemExit(f'Documentación modular ausente o incompleta: {name}')
for path in map(Path, required):
    text = path.read_text()
    if 'TODO_AUTOGENERADO' in text or 'PLACEHOLDER_AUTOGENERADO' in text:
        raise SystemExit(f'Marcador de documentación incompleta en {path}')
PY_CHECK

python3 - <<'PY_CHECK'
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
    'CALIBRE_VERSION="9.11.0"',
    'GHOSTSCRIPT_VERSION="10.07.1"',
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
PY_CHECK


# La configuración persistente debe estar centralizada en Ajustes y no duplicarse en los módulos.
python3 - <<'PY_CHECK'
from pathlib import Path
settings = Path('Sources/ZEUVEApp/SettingsView.swift').read_text()
youtube_view = Path('Sources/ZEUVEApp/YouTubeDownloader/YouTubeDownloaderView.swift').read_text()
organizer_view = Path('Sources/ZEUVEApp/Organizer/OrganizerView.swift').read_text()
youtube_model = Path('Sources/ZEUVEApp/YouTubeDownloader/YouTubeDownloaderViewModel.swift').read_text()
organizer_model = Path('Sources/ZEUVEApp/Organizer/OrganizerViewModel.swift').read_text()
for required in [
    'case general', 'case organizer', 'case youtubeDownloader', 'case chatAnalyzer', 'case universalConverter',
    'YouTubeSettingsSection', 'case defaults', 'case presets', 'case diagnostics',
    'OrganizerModuleSettingsView', 'YouTubeModuleSettingsView', 'ChatAnalyzerModuleSettingsView', 'UniversalConverterSettingsView',
]:
    if required not in settings:
        raise SystemExit('Falta una sección centralizada de Ajustes: ' + required)
for forbidden in ['Button("Presets"', 'Button("Diagnóstico"', 'showPresets', 'showDiagnostics', 'gearshape']:
    if forbidden in youtube_view:
        raise SystemExit('El Descargador conserva un acceso de ajustes dentro del módulo: ' + forbidden)
if 'gearshape' in organizer_view:
    raise SystemExit('El Organizador contiene una rueda de ajustes dentro del módulo.')
for required in ['"youtube.defaultSettings"', '"youtube.defaultAdvancedMode"', 'normalizedDefaults']:
    if required not in youtube_model:
        raise SystemExit('Falta persistencia de valores predeterminados del Descargador: ' + required)
for required in ['"organizer.defaultOptions"', 'persistDefaultOptions', 'applyDefaultOptionsToCurrentOperation', 'options = defaultOptions']:
    if required not in organizer_model:
        raise SystemExit('Falta persistencia de valores predeterminados del Organizador: ' + required)
if 'try? settings?.set(options, forKey: "organizer.options")' in organizer_model:
    raise SystemExit('Las opciones de una operación siguen sobrescribiendo los ajustes permanentes del Organizador.')
if 'Aplicar preset' not in youtube_view:
    raise SystemExit('Falta el selector rápido de presets dentro del Descargador.')
chat_view = Path('Sources/ZEUVEApp/ChatAnalyzer/ChatAnalyzerView.swift').read_text()
chat_model = Path('Sources/ZEUVEApp/ChatAnalyzer/ChatAnalyzerViewModel.swift').read_text()
for forbidden in ['gearshape', 'Abrir ajustes', 'Ventana de ajustes']:
    if forbidden in chat_view:
        raise SystemExit('El Analizador contiene ajustes persistentes dentro del módulo: ' + forbidden)
for required in ['ChatAnalyzerSettingsService', 'chatAnalyzer.defaultSettings', 'applyDefaultSettingsToCurrentAnalysis']:
    target = chat_model + Path('Sources/ChatAnalyzerModule/Storage/ChatAnalyzerStorage.swift').read_text()
    if required not in target:
        raise SystemExit('Falta integración de ajustes del Analizador: ' + required)
PY_CHECK

# Integración, privacidad y seguridad del Analizador de chats.
python3 - <<'PY_CHECK'
from pathlib import Path
required_files = [
    'Sources/ChatAnalyzerModule/ChatAnalyzerService.swift',
    'Sources/ChatAnalyzerModule/Archive/ChatArchive.swift',
    'Sources/ChatAnalyzerModule/Import/WhatsAppImporter.swift',
    'Sources/ChatAnalyzerModule/Import/InstagramImporter.swift',
    'Sources/ChatAnalyzerModule/Storage/ChatAnalyzerStorage.swift',
    'Sources/ChatAnalyzerModule/Analysis/ChatAnalyticsCache.swift',
    'Sources/ZEUVEApp/ChatAnalyzer/ChatAnalyzerView.swift',
    'Sources/ZEUVEApp/ChatAnalyzer/ChatAnalyzerResultsView.swift',
]
for name in required_files:
    if not Path(name).is_file():
        raise SystemExit('Falta un componente del Analizador: ' + name)
app = '\n'.join(path.read_text() for path in Path('Sources/ZEUVEApp').rglob('*.swift'))
for required in ['com.zeuve.chat-analyzer', 'ChatAnalyzerView', 'ChatAnalyzerModuleSettingsView', 'ChatAnalyzerHistoryPresenter']:
    if required not in app:
        raise SystemExit('Falta integración del Analizador en la aplicación: ' + required)
module = '\n'.join(path.read_text(errors='ignore') for path in Path('Sources/ChatAnalyzerModule').rglob('*') if path.is_file())
for forbidden in ['URLSession', 'WKWebView', 'NSWorkspace.shared.open', 'http://localhost', 'https://api.']:
    if forbidden in module:
        raise SystemExit('El Analizador contiene una vía de red o apertura externa: ' + forbidden)
for required in ['SafeArchivePath', 'readUserSelectedFiles', '.zeuve-chat-operation', 'MessageDeduplicator']:
    if required not in module:
        raise SystemExit('Falta una protección obligatoria del Analizador: ' + required)

archive = Path('Sources/ChatAnalyzerModule/Archive/ChatArchive.swift').read_text()
whatsapp = Path('Sources/ChatAnalyzerModule/Import/WhatsAppImporter.swift').read_text()
instagram = Path('Sources/ChatAnalyzerModule/Import/InstagramImporter.swift').read_text()
models = Path('Sources/ChatAnalyzerModule/ChatAnalyzerModels.swift').read_text()
view = Path('Sources/ZEUVEApp/ChatAnalyzer/ChatAnalyzerView.swift').read_text()
view_model = Path('Sources/ZEUVEApp/ChatAnalyzer/ChatAnalyzerViewModel.swift').read_text()
settings = Path('Sources/ZEUVEApp/SettingsView.swift').read_text()
results = Path('Sources/ZEUVEApp/ChatAnalyzer/ChatAnalyzerResultsView.swift').read_text()
for required in ['readPrefixes(', 'public func stream(']:
    if required not in archive:
        raise SystemExit('Falta lectura ZIP progresiva del Analizador: ' + required)
for required in ['reader.readPrefixes', 'reader.stream', 'conversationFileMaximumBytes', 'unverifiedAttachments']:
    if required not in whatsapp + models:
        raise SystemExit('Falta corrección de WhatsApp: ' + required)
for required in ['usesDirectConversationLayout', 'resolveAttachmentPath(']:
    if required not in instagram:
        raise SystemExit('Falta compatibilidad con ZIP individual de Instagram: ' + required)
for required in ['dropTitle', 'dropSubtitle', 'allowedContentTypes', 'Arrastra el ZIP de Instagram']:
    if required not in view:
        raise SystemExit('El cuadro de importación no depende de la plataforma: ' + required)
if view_model.count('instagramSelections[url] =') < 2:
    raise SystemExit('No se selecciona automáticamente el único chat de Instagram en ZIP y carpeta.')
for required in ['Limitar el tamaño de cada archivo de conversación', 'Por defecto no hay límite']:
    if required not in settings:
        raise SystemExit('Falta el límite opcional centralizado: ' + required)
if 'Adjuntos no comprobados' not in results:
    raise SystemExit('El resumen no diferencia adjuntos no comprobados.')

analytics = Path('Sources/ChatAnalyzerModule/Analysis/ChatAnalytics.swift').read_text()
analytics_cache = Path('Sources/ChatAnalyzerModule/Analysis/ChatAnalyticsCache.swift').read_text()
for required in [
    '@Published private(set) var coreSnapshot', 'detachedAnalyticsValue',
    'Task.sleep(nanoseconds: 200_000_000)', 'handleOperationSettingsChange',
    'searchTask?.cancel()', 'analyticsRevision',
]:
    if required not in view_model:
        raise SystemExit('Falta arquitectura de rendimiento del Analizador: ' + required)
for required in [
    'ChatCoreAnalyticsSnapshot', 'ChatActivityAnalyticsSnapshot',
    'ChatWordsAnalyticsSnapshot', 'ChatSearchIndex',
]:
    if required not in analytics_cache:
        raise SystemExit('Falta una instantánea analítica: ' + required)
for required in [
    'guard filter.activeCount > 0 else { return messages }',
    'guard needsWeekday || needsHour else { return true }',
    'var overallWords: [String: Int]',
    'var heatmapValues = Array(repeating: 0, count: 7 * 24)',
]:
    if required not in analytics:
        raise SystemExit('Falta una optimización analítica: ' + required)
for forbidden in [
    'ChatAnalytics.words(model.filteredMessages',
    'ChatAnalytics.timeSeries(model.filteredMessages',
]:
    if forbidden in results:
        raise SystemExit('La interfaz vuelve a recalcular estadísticas pesadas: ' + forbidden)

chart_support = Path('Sources/ZEUVEApp/Components/InteractiveChartSupport.swift').read_text()
for required in [
    'struct ChartTooltipCard: View', 'CursorFollowingTooltip',
    'tooltipCenter(in:', 'chartOverlay', 'onContinuousHover',
    'proxy.plotFrame', 'nearestDate(to:', 'trackChartDateHover',
    'trackChartCategoryHover', 'cursorLocation', 'chartCursorTooltip',
    'location.x - horizontalGap - halfWidth',
    'location.y + verticalGap + halfHeight',
    'containerSize.width - margin', 'containerSize.height - margin',
]:
    if required not in chart_support:
        raise SystemExit('Falta interacción común de gráficos: ' + required)
for required in [
    'activityTooltipRows', 'comparisonTemporalRows', 'HeatmapHoverValue',
    'hoveredCellLocation', 'ChartTooltipRow("Total"',
]:
    if required not in results:
        raise SystemExit('Falta tooltip en un gráfico del Analizador: ' + required)
if results.count('trackChartDateHover(') < 3 or results.count('trackChartCategoryHover(') < 5:
    raise SystemExit('No todos los gráficos Swift Charts tienen hover interactivo.')
if results.count('chartCursorTooltip(at:') < 9:
    raise SystemExit('No todos los gráficos colocan el tooltip junto al cursor.')
if '.annotation(position: .top' in results:
    raise SystemExit('Queda algún tooltip fijado al borde superior del gráfico.')
for forbidden in ['ChatAnalytics.timeSeries', 'ChatAnalytics.participants', 'ChatAnalytics.words']:
    if forbidden in chart_support:
        raise SystemExit('La capa de hover ejecuta análisis pesado: ' + forbidden)

if 'private struct ChatAnalyzerObservedContent: View' not in view or 'if model.session == nil' not in view:
    raise SystemExit('La vista del Analizador no observa directamente el cambio entre resultados e importación.')
if 'if app.chatAnalyzer.session == nil' in view:
    raise SystemExit('La navegación del Analizador sigue dependiendo únicamente de AppModel.')
for required in [
    'chatSummaryOverview', 'chatActivityOverview', 'chatParticipantOverview',
    'chatWordsOverview', 'chatSearchOverview', 'chatConversationsOverview',
    'chatResponsesOverview', 'chatComparisonOverview', 'chatFusionsOverview',
    'HelpTableHeader(', 'HelpGroupBox(', 'topic: ContextualHelpTopic?',
]:
    if required not in results:
        raise SystemExit('Falta ayuda contextual analítica en resultados: ' + required)
rules = Path('SUPERAPP_PROJECT_RULES.md').read_text()
for required in [
    '56. COHERENCIA AL CAMBIAR MODOS, PLATAFORMAS O TIPOS DE ENTRADA',
    '57. REGRESO AL ESTADO INICIAL DEL MÓDULO',
    '58. SELECCIÓN AUTOMÁTICA CUANDO SOLO EXISTE UNA OPCIÓN',
    '59. ARCHIVOS GRANDES Y LÍMITES CONFIGURABLES',
    '60. DIFERENCIAR AUSENTE, NO PROPORCIONADO Y NO COMPROBABLE',
    '61. USO TEMPORAL DE ARCHIVOS REALES PARA REPRODUCIR ERRORES',
    '62. AYUDA CONTEXTUAL EN RESULTADOS ANALÍTICOS',
    '63. INSPECCIÓN EFICIENTE DE ARCHIVOS COMPRIMIDOS',
    '78. REGLA FINAL',
]:
    if required not in rules:
        raise SystemExit('Falta una regla permanente aprobada: ' + required)
PY_CHECK

bash -n Scripts/prepare_engines_macos.sh Scripts/verify_engines_macos.sh Scripts/sign_embedded_engines.sh Scripts/verify_packaged_engines_macos.sh Scripts/build_macos.sh Scripts/run_youtube_integration_tests_macos.sh
python3 -m py_compile Scripts/static_pkg_config.py Scripts/package_release.py Scripts/generate_xcode_project.py Scripts/validate_module_docs.py Tests/ScriptTests/test_static_pkg_config.py Tests/ScriptTests/test_engine_signing_policy.py
python3 -m unittest discover -s Tests/ScriptTests -p 'test_*.py' -v

python3 Scripts/validate_module_docs.py

# Validación JSON de todos los manifiestos actuales.
python3 - <<'PY_CHECK'
import json
from pathlib import Path
for path in Path('Sources').glob('*/Resources/manifest.json'):
    data = json.loads(path.read_text())
    required = {
        'schemaVersion', 'identifier', 'name', 'summary', 'version',
        'minimumZEUVEVersion', 'moduleAPI', 'technology', 'executionMode',
        'permissions', 'capabilities', 'presentation'
    }
    missing = sorted(required - data.keys())
    if missing:
        raise SystemExit(f'{path}: faltan campos: {", ".join(missing)}')
PY_CHECK

for file in $(find Sources/ZEUVEApp -name '*.swift' -print); do
  swiftc -frontend -parse "$file" >/dev/null
done

python3 Scripts/generate_xcode_project.py

if [[ "$(uname -s)" == "Darwin" ]] && [[ "$(uname -m)" == "arm64" ]] && command -v xcodebuild >/dev/null 2>&1; then
  Scripts/verify_engines_macos.sh
  xcodebuild \
    -project ZEUVE.xcodeproj \
    -scheme ZEUVE \
    -configuration Debug \
    -destination 'platform=macOS,arch=arm64' \
    build
else
  echo "Validación de motores y Xcode omitida: el entorno no es macOS Apple Silicon."
fi

# El Conversor universal debe conservar su arquitectura, seguridad y rendimiento aprobados.
python3 - <<'PY_CHECK'
from pathlib import Path
required = [
    'Sources/UniversalConverterModule/UniversalConverterModuleDefinition.swift',
    'Sources/UniversalConverterModule/Execution/UniversalConverterExecutionService.swift',
    'Sources/UniversalConverterModule/Execution/NativeImageService.swift',
    'Sources/UniversalConverterModule/Execution/NativePDFService.swift',
    'Sources/UniversalConverterModule/Archive/ConverterArchive.swift',
    'Sources/ZEUVEApp/UniversalConverter/UniversalConverterView.swift',
    'Sources/ZEUVEApp/UniversalConverter/UniversalConverterViewModel.swift',
    'Tests/UniversalConverterModuleTests/UniversalConverterCoreTests.swift',
]
for name in required:
    if not Path(name).is_file(): raise SystemExit('Falta un archivo del Conversor: ' + name)
module = '\n'.join(path.read_text(errors='ignore') for path in Path('Sources/UniversalConverterModule').rglob('*.swift'))
for value in ['h264_videotoolbox', 'fps_mode', 'passthrough', 'tiempos.csv', 'ImageIO', 'PDFKit', 'ConverterSafePath', 'revision']:
    if value not in module: raise SystemExit('Falta una garantía del Conversor: ' + value)
for required in ['libx264', 'libwebp', 'GhostscriptCommandBuilder', 'PandocCommandBuilder', 'CalibreCommandBuilder']:
    if required not in module: raise SystemExit('Falta una capacidad aprobada del Conversor: ' + required)
for forbidden in ['/bin/sh', 'libx265', 'URLSession', 'ProcessInfo.processInfo.environment["PATH"]']:
    if forbidden in module: raise SystemExit('Contenido no aprobado en el Conversor: ' + forbidden)
for forbidden in ['LibreOffice', 'soffice', 'case doc, docx', 'case libreOffice']:
    if forbidden in module: raise SystemExit('El Conversor conserva soporte ofimático retirado: ' + forbidden)
models = Path('Sources/UniversalConverterModule/Models/UniversalConverterModels.swift').read_text()
for required in ['case txt, markdown, html, csv, json, xml', 'case .csv, .json, .xml: return .data']:
    if required not in models: raise SystemExit('CSV no se conserva como formato de datos genérico: ' + required)
for extension in ['doc','docx','xls','xlsx','ppt','pptx','odt','ods','odp','rtf']:
    if f'case "{extension}":' in models: raise SystemExit('Extensión ofimática todavía registrada: ' + extension)
view_model = Path('Sources/ZEUVEApp/UniversalConverter/UniversalConverterViewModel.swift').read_text()
for value in ['planRevision', 'planTask?.cancel()', 'Task.sleep', 'guard revision == self.planRevision']:
    if value not in view_model: raise SystemExit('Falta control de resultados obsoletos: ' + value)
PY_CHECK
