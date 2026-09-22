#!/usr/bin/env python3
from __future__ import annotations

import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)

# Las vistas que usan tipos de ZEUVECore deben importarlo por archivo.
for relative in [
    "Sources/ZEUVEApp/DashboardView.swift",
    "Sources/ZEUVEApp/RootView.swift",
]:
    lines = Path(relative).read_text().splitlines()
    if "import ZEUVECore" not in lines:
        raise SystemExit(f"{relative} debe importar ZEUVECore explícitamente.")

# Regresión: AppModel debe resolver por completo el estado local antes de asignar self.
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
    'universalDownloader = UniversalDownloaderViewModel',
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

# Regresión 0.12.3: arranque idempotente, historial fuera de MainActor y errores acumulados.
from pathlib import Path
app = Path('Sources/ZEUVEApp/AppModel.swift').read_text()
history = Path('Sources/ZEUVEApp/History/GlobalHistoryView.swift').read_text()
for required in ['private var didStart = false', 'guard !didStart else { return }', 'didStart = true', 'appendStartupIssue(', 'operationObserver?.cancel()']:
    if required not in app:
        raise SystemExit('Falta protección de arranque 0.12.3: ' + required)
for required in ['Task.detached(priority: .userInitiated)', 'GlobalHistoryLoadOutcome', 'self.selectedModuleID == moduleID']:
    if required not in history:
        raise SystemExit('El historial global no conserva la carga segura fuera de MainActor: ' + required)

# La configuración persistente debe estar centralizada en Ajustes y no duplicarse en los módulos.
from pathlib import Path
settings = Path('Sources/ZEUVEApp/SettingsView.swift').read_text() + '\n' + Path('Sources/ZEUVEApp/BuiltInModules/BuiltInModuleCatalog.swift').read_text() + '\n' + Path('Sources/ZEUVEApp/BuiltInModules/BuiltInModuleSettingsRouter.swift').read_text() + '\n' + '\n'.join(path.read_text() for path in Path('Sources/ZEUVEApp/UniversalDownloader/Settings').rglob('*.swift'))
downloader_root = Path('Sources/ZEUVEApp/UniversalDownloader')
downloader_view = Path(downloader_root / 'UniversalDownloaderView.swift').read_text() + '\n' + '\n'.join(path.read_text() for path in sorted((downloader_root / 'Views').glob('*.swift')))
organizer_view = Path('Sources/ZEUVEApp/Organizer/OrganizerView.swift').read_text()
downloader_model = Path('Sources/ZEUVEApp/UniversalDownloader/UniversalDownloaderViewModel.swift').read_text()
organizer_model = Path('Sources/ZEUVEApp/Organizer/OrganizerViewModel.swift').read_text()
organizer_keys = Path('Sources/OrganizerModule/OrganizerStorageKeys.swift').read_text()
for required in [
    'case general', 'case module(BuiltInModuleID)', 'ForEach(app.settingsModules)',
    'settingsOrder: 10', 'settingsOrder: 20', 'settingsOrder: 30', 'settingsOrder: 40', 'settingsOrder: nil',
    'UniversalDownloaderSettingsSection', 'case defaults', 'case presets', 'case diagnostics',
    'OrganizerModuleSettingsView', 'UniversalDownloaderSettingsView', 'ChatAnalyzerModuleSettingsView', 'UniversalConverterSettingsView',
]:
    if required not in settings:
        raise SystemExit('Falta una sección centralizada de Ajustes: ' + required)
for forbidden in ['Button("Presets"', 'Button("Diagnóstico"', 'showPresets', 'showDiagnostics', 'gearshape']:
    if forbidden in downloader_view:
        raise SystemExit('El Descargador conserva un acceso de ajustes dentro del módulo: ' + forbidden)
if 'gearshape' in organizer_view:
    raise SystemExit('El Organizador contiene una rueda de ajustes dentro del módulo.')
downloader_storage = Path('Sources/UniversalDownloaderModule/Storage/UniversalDownloaderStorageKeys.swift').read_text()
for required in ['"universalDownloader.defaultSettings"', '"universalDownloader.defaultAdvancedMode"', '"youtube.defaultSettings"', '"youtube.defaultAdvancedMode"', 'normalizedDefaults', 'UniversalDownloaderSettingsStore']:
    if required not in downloader_storage:
        raise SystemExit('Falta persistencia o compatibilidad de valores predeterminados del Descargador: ' + required)
for required in ['"organizer.defaultOptions"', '"organizer.lastFolder"', '"organizer.recentFolders"', '"organizer.options"']:
    if required not in organizer_keys:
        raise SystemExit('Falta una clave persistente o legacy del Organizador: ' + required)
for required in ['OrganizerStorageKeys.defaultOptions', 'OrganizerStorageKeys.Legacy.options', 'persistDefaultOptions', 'applyDefaultOptionsToCurrentOperation', 'options = defaultOptions']:
    if required not in organizer_model:
        raise SystemExit('Falta persistencia de valores predeterminados del Organizador: ' + required)
if 'settings?.set(options, forKey: OrganizerStorageKeys.Legacy.options)' in organizer_model:
    raise SystemExit('Las opciones de una operación siguen sobrescribiendo los ajustes permanentes del Organizador.')
if 'Aplicar preset' not in downloader_view:
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

# Regresión 0.12.4: los logs del Organizador no deben persistir rutas del usuario.
for forbidden in ['metadata: ["carpeta": folderURL.path]', 'metadata: ["carpeta": result.baseFolder.path]']:
    if forbidden in organizer_model:
        raise SystemExit('El Organizador vuelve a registrar rutas privadas: ' + forbidden)

# Regresión 0.12.4: fallos degradantes de logger/motores no deben quedar silenciados con try?.
for required in [
    'loggerInitializationFailed',
    'engineRegistryInitializationFailed',
    'ZEUVE se ha iniciado, pero los registros locales de diagnóstico no están disponibles.',
    'ZEUVE se ha iniciado con disponibilidad degradada de motores.',
]:
    if required not in app:
        raise SystemExit('Falta diagnóstico degradante de arranque 0.12.4: ' + required)
for forbidden in ['try? LocalLogger(', 'try? EngineRegistry.bundled()']:
    if forbidden in app:
        raise SystemExit('AppModel vuelve a silenciar un fallo de arranque relevante: ' + forbidden)
