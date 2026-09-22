#!/usr/bin/env python3
from __future__ import annotations

import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)

# Regresión 0.12.3: perfiles originales, navegador deshabilitado y versión HTTP centralizada.
from pathlib import Path
profiles = Path('Sources/UniversalDownloaderModule/Models/UniversalDownloadProfiles.swift').read_text()
router = Path('Sources/UniversalDownloaderModule/Models/UniversalDownloaderModels.swift').read_text()
settings = Path('Sources/ZEUVEApp/UniversalDownloader/Settings/UniversalCatalogSettingsView.swift').read_text()
store = Path('Sources/UniversalDownloaderModule/Storage/UniversalDownloaderStorageKeys.swift').read_text()
product = Path('Sources/ZEUVECore/ZEUVEProductInfo.swift').read_text()
network = '\n'.join([
    Path('Sources/UniversalDownloaderModule/Discovery/UniversalPageDiscovery.swift').read_text(),
    Path('Sources/UniversalDownloaderModule/Engines/DirectHTTP/DirectHTTPDownloadService.swift').read_text(),
    Path('Sources/UniversalDownloaderModule/Platforms/Instagram/InstagramProfilePictureArchiveService.swift').read_text(),
])
for required in ['currentSchemaVersion = 2', 'mode: .original', 'maximumResolution: .best', 'legacyYouTubeFactorySettings']:
    if required not in profiles:
        raise SystemExit('Falta política de perfiles 0.12.3: ' + required)
if '.browser]' in router or '+ browser' in router:
    raise SystemExit('El navegador opcional sigue entrando en el routing efectivo.')
if 'Usar el navegador opcional como último recurso' in settings:
    raise SystemExit('La opción de navegador incompleta sigue visible.')
if 'preferences.useOptionalBrowserFallback = false' not in store:
    raise SystemExit('La preferencia legacy del navegador no se normaliza a false.')
for forbidden in ['ZEUVE/0.10', 'ZEUVE/0.12.1']:
    if forbidden in network:
        raise SystemExit('User-Agent obsoleto: ' + forbidden)
if 'CFBundleShortVersionString' not in product or 'httpUserAgentToken' not in product:
    raise SystemExit('Falta información de producto centralizada.')

# Integración, migración, seguridad y rendimiento del Descargador universal 0.6.0.
from pathlib import Path
models = '\n'.join(path.read_text() for path in Path('Sources/UniversalDownloaderModule/Models').rglob('*.swift'))
validator = Path('Sources/UniversalDownloaderModule/Validation/UniversalDownloadInputValidator.swift').read_text()
discovery = Path('Sources/UniversalDownloaderModule/Discovery/UniversalPageDiscovery.swift').read_text()
analysis = Path('Sources/UniversalDownloaderModule/Analysis/UniversalDownloadAnalysisService.swift').read_text()
downloader_root = Path('Sources/ZEUVEApp/UniversalDownloader')
view = Path(downloader_root / 'UniversalDownloaderView.swift').read_text() + '\n' + Path(downloader_root / 'UniversalDownloaderCatalogView.swift').read_text() + '\n' + '\n'.join(path.read_text() for path in sorted((downloader_root / 'Views').glob('*.swift')))
view_model = Path('Sources/ZEUVEApp/UniversalDownloader/UniversalDownloaderViewModel.swift').read_text()
history = Path('Sources/UniversalDownloaderModule/Storage/UniversalDownloadHistoryService.swift').read_text()
manifest = Path('Sources/UniversalDownloaderModule/Resources/manifest.json').read_text()
for required in ['UniversalDownloadPlatform', 'UniversalMediaKind', 'UniversalEngineRouter', 'allowAdultContent']:
    if required not in models + validator + Path('Sources/UniversalDownloaderModule/Models/UniversalDownloaderModels.swift').read_text():
        raise SystemExit('Falta arquitectura social universal: ' + required)
for required in ['com.zeuve.universal-downloader', 'com.zeuve.youtube-downloader']:
    if required not in models + manifest:
        raise SystemExit('Falta identidad o alias del Descargador universal: ' + required)
for required in ['allowInsecureLocalNetwork', 'isLocalHost', 'https', 'http']:
    if required not in validator + models:
        raise SystemExit('Falta política de URL universal: ' + required)
for required in ['tagName: "video"', 'tagName: "source"', 'tagName: "iframe"', 'application/ld\\+json', 'og:video', '.m3u8', '.mpd']:
    if required not in discovery:
        raise SystemExit('Falta detección HTML universal: ' + required)
for required in ['Inicio del análisis universal', 'duplicateCount', 'deduplicationKey', 'Análisis universal completado']:
    if required not in analysis:
        raise SystemExit('Falta análisis o deduplicación universal: ' + required)
for required in ['Ya descargado', 'Posible duplicado', 'Contenido adulto permitido', 'Permitir HTTP y direcciones de la red local']:
    if required not in view:
        raise SystemExit('Falta estado visible del Descargador universal: ' + required)
if 'AsyncImage' not in view:
    raise SystemExit('El catálogo social no muestra las miniaturas obtenidas tras el análisis expreso.')
resolved = Path('Sources/UniversalDownloaderModule/Download/UniversalDownloadService.swift').read_text()
parser = Path('Sources/UniversalDownloaderModule/Engines/YTDLP/YTDLPAnalysisParser.swift').read_text()
command = Path('Sources/UniversalDownloaderModule/Engines/YTDLP/YTDLPCommandBuilder.swift').read_text()
publisher = Path('Sources/UniversalDownloaderModule/Publishing/DownloadOutputPublisher.swift').read_text()
adaptive = Path('Sources/UniversalDownloaderModule/Engines/YTDLP/YTDLPAdaptiveFragmentPolicy.swift').read_text()
for required in ['ResolvedMediaReference', 'mediaURL = nil', 'httpHeaders = [:]', 'adaptivePageFragments']:
    if required not in models:
        raise SystemExit('Falta referencia multimedia efímera o compatibilidad de ajustes: ' + required)
for required in ['resolvedMediaReference', 'manifest_url', 'http_headers', 'url_expiration']:
    if required not in parser:
        raise SystemExit('Falta extracción de la referencia resuelta: ' + required)
for required in ['resolvedMedia?.mediaURL ?? item.sourceURL', '--add-header', 'secretOptions = ["--cookies", "--cookies-from-browser", "--proxy", "--add-header"]']:
    if required not in command:
        raise SystemExit('Falta protección de la URL resuelta o de argumentos privados: ' + required)
for required in ['shouldResolveStableAnonymousYouTubeURL', 'item.platform == .youtube']:
    if required not in resolved:
        raise SystemExit('Falta la resolución estable para YouTube anónimo: ' + required)
for required in ['adaptiveFragmentCeiling = 16', 'target: "resuelto"', 'target: "respaldo"', 'resetForRetry']:
    if required not in resolved:
        raise SystemExit('Falta descarga directa adaptativa o respaldo seguro: ' + required)
for required in ['16, 8, 4, 1', 'shouldReduce']:
    if required not in adaptive:
        raise SystemExit('Falta política adaptativa de fragmentos: ' + required)
for required in ['sameVolume(source, destinationRoot)', 'moveItem(at: source, to: staging)', 'copyItem(at: source, to: staging)']:
    if required not in publisher:
        raise SystemExit('Falta publicación optimizada y segura: ' + required)
for required in ['downloadedCanonicalIDs', 'possibleDuplicateIDs', 'includeDownloaded: false', 'includeDownloaded: true']:
    if required not in view_model:
        raise SystemExit('Falta selección aprobada de duplicados o historial: ' + required)
for required in ['legacyYouTubeDownloaderModuleIdentifier', 'records(moduleID: universalDownloaderModuleIdentifier', 'records(moduleID: legacyYouTubeDownloaderModuleIdentifier']:
    if required not in history:
        raise SystemExit('Falta continuidad del historial anterior: ' + required)

# Regresión 0.12.4: una operación, una Task propietaria y un único ejecutor de descarga.
for required in [
    'private var operationTask:', 'private var instagramSessionImportTask:',
    'private func startDownload(allowingConfirmedReplacement:',
    'await finishOperation(startedOperationID', 'try? await coordinator.finish(id: operationID)',
    'registerPossibleDuplicates(in: analysis)',
]:
    if required not in view_model:
        raise SystemExit('Falta robustecimiento del ciclo de operación del Descargador 0.12.4: ' + required)
for forbidden in ['downloadAllowingConfirmedReplacement()', 'private var worker: Task<Void, Never>?']:
    if forbidden in view_model:
        raise SystemExit('Ha reaparecido el flujo duplicado/worker compartido del Descargador: ' + forbidden)
wayback = Path('Sources/UniversalDownloaderModule/Platforms/Instagram/InstagramProfilePictureArchiveService.swift').read_text()
for required in ['URLSessionConfiguration.ephemeral', 'timeoutIntervalForRequest = 30', 'timeoutIntervalForResource = 120', 'urlCache = nil', 'httpCookieStorage = nil']:
    if required not in wayback:
        raise SystemExit('Falta sesión efímera dedicada para Wayback: ' + required)
