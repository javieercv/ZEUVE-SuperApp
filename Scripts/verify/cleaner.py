#!/usr/bin/env python3
from __future__ import annotations

import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)

package = Path("Package.swift").read_text()
manifest = json.loads(Path("Sources/CleanerModule/Resources/manifest.json").read_text())
catalog = Path("Sources/ZEUVEApp/BuiltInModules/BuiltInModuleCatalog.swift").read_text()
router = Path("Sources/ZEUVEApp/BuiltInModules/BuiltInModuleViewRouter.swift").read_text()
settings_router = Path("Sources/ZEUVEApp/BuiltInModules/BuiltInModuleSettingsRouter.swift").read_text()
app_model = Path("Sources/ZEUVEApp/AppModel.swift").read_text()
settings = Path("Sources/ZEUVEApp/SettingsView.swift").read_text()
cleaner_settings = Path("Sources/ZEUVEApp/Cleaner/CleanerSettingsView.swift").read_text()
module_sources = "\n".join(p.read_text() for p in Path("Sources/CleanerModule").rglob("*.swift"))
ui_sources = "\n".join(p.read_text() for p in Path("Sources/ZEUVEApp/Cleaner").rglob("*.swift"))
tests = Path("Tests/CleanerModuleTests/CleanerModuleTests.swift").read_text()
analysis_service = Path("Sources/CleanerModule/Discovery/CleanerAnalysisService.swift").read_text()
repository = Path("Sources/CleanerModule/Storage/CleanerRepository.swift").read_text()
spotlight = Path("Sources/CleanerModule/Discovery/CleanerSpotlightDiscovery.swift").read_text()
undo_service = Path("Sources/CleanerModule/Execution/CleanerUndoService.swift").read_text()

for snippet in [
    '.library(name: "CleanerModule"',
    'name: "CleanerModule"',
    'path: "Sources/CleanerModule"',
    'name: "CleanerModuleTests"',
]:
    if snippet not in package:
        raise SystemExit("Package.swift no integra completamente CleanerModule: " + snippet)

for key, expected in {
    "identifier": "com.zeuve.cleaner",
    "name": "Limpiador",
    "version": "0.1.3",
    "minimumZEUVEVersion": "0.20.0",
    "executionMode": "builtIn",
}.items():
    if manifest.get(key) != expected:
        raise SystemExit(f"Manifest Limpiador: {key} debe ser {expected!r}")
permissions = set(manifest.get("permissions", []))
for required in {"scanLocalStorage", "removeLocalItems", "persistentFolderAccess", "openExternalApplications"}:
    if required not in permissions:
        raise SystemExit("Falta permiso del Limpiador: " + required)
for forbidden in {"networkAccess", "executeBundledTools", "readBrowserCookies"}:
    if forbidden in permissions:
        raise SystemExit("El Limpiador declara un permiso prohibido en V1: " + forbidden)

for snippet in [
    "case cleaner", "id: .cleaner", "primaryIdentifier: cleanerModuleIdentifier",
    'registrationName: "Limpiador"', "navigationOrder: 70", "settingsOrder: 60",
    'defaultShortcut: .command("7")', '(historyTargetID, .command("8"))',
]:
    if snippet not in catalog:
        raise SystemExit("Falta integración del Limpiador en el catálogo: " + snippet)
if "case .cleaner:" not in router or "CleanerView()" not in router:
    raise SystemExit("BuiltInModuleViewRouter no resuelve Limpiador.")
if "case .cleaner:" not in settings_router or "CleanerSettingsView" not in settings_router:
    raise SystemExit("BuiltInModuleSettingsRouter no resuelve Ajustes del Limpiador.")
for snippet in [
    "let cleaner: CleanerViewModel", "cleaner = CleanerViewModel(", "&& !cleaner.isBusy",
    "cleaner.restorePersistentDefaultsForGlobalReset()", "await cleaner.cancelAndWait()",
]:
    if snippet not in app_model:
        raise SystemExit("AppModel no integra completamente Limpiador: " + snippet)
for snippet in ["Herramientas y atajos", "ShortcutRecorderView", "restoreNavigationDefaults()"]:
    if snippet not in settings:
        raise SystemExit("Ajustes generales no integran navegación personalizable: " + snippet)
for snippet in ["Papelera", "Eliminar permanentemente", "Conservados", "Acceso total al disco", "Borrar inventario histórico"]:
    if snippet not in cleaner_settings:
        raise SystemExit("Ajustes del Limpiador incompletos: " + snippet)

for required in [
    "CleanerAssociationService", "CleanerInventoryService", "CleanerStorageScanner", "CleanerDevelopmentScanner",
    "CleanerUninstallAnalyzer", "CleanerExecutionService", "CleanerUndoService", "CleanerRepository",
    "OperationCoordinator", "CleanerFileFingerprint", "trashItem", "isSymbolicLink",
]:
    if required not in module_sources:
        raise SystemExit("Falta infraestructura del Limpiador: " + required)
for forbidden in ["URLSession", "/bin/sh", "Process()", "SMJobBless", "sudo "]:
    if forbidden in module_sources + ui_sources:
        raise SystemExit("El Limpiador contiene una capacidad prohibida en V1: " + forbidden)
for required in [
    "testSymlinkFingerprintDoesNotFollowTarget", "testPersistentDataIsNeverSafePreselected",
    "testRepositoryTracksTwoCopiesOfSameBundleIndependently", "testSharedAppGroupIsHighRiskAndCannotBeSelected",
    "testUninstallDoesNotRemoveRelatedDataWhenApplicationIsNotSelected", "testTrashOperationCanBeUndoneAndConflictNeverOverwrites",
    "testMalformedInventoryRowIsReportedInsteadOfSilentlyDiscarded",
    "testMalformedUndoRowIsReportedInsteadOfSilentlyDiscarded",
    "testMalformedConservedDecisionIsReportedInsteadOfWeakeningProtection",
    "testUndoHistoryUpdateFailureReturnsWarningAfterRestoringFiles",
]:
    if required not in tests:
        raise SystemExit("Falta test de seguridad del Limpiador: " + required)

if "(try? repository?.loadInventory()) ?? []" in analysis_service or "(try? repository?.keptPaths()) ?? []" in analysis_service:
    raise SystemExit("El análisis del Limpiador no puede convertir fallos de persistencia en protecciones vacías.")
for forbidden in ["compactMap { row in try? decoder.decode", "compactMap{try? $0.string(\"path\")", "let fp=try? d.decode"]:
    if forbidden in repository:
        raise SystemExit("CleanerRepository no puede descartar silenciosamente filas inválidas: " + forbidden)
for required in ["public struct CleanerUndoOutput", "historyWarning", "try history.updateUndoState"]:
    if required not in undo_service:
        raise SystemExit("CleanerUndoService debe separar restauración y warning de historial: " + required)
if "if Task.isCancelled { return .init(urls: [], status: .cancelled) }" not in spotlight:
    raise SystemExit("Spotlight portable debe respetar una tarea previamente cancelada.")

for doc in ["Docs/Modulos/Funcionales/CLEANER.md", "Docs/Modulos/Funcionales/CLEANER_PRIVACY_AND_FILES.md", "Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.20.0.0.md", "Docs/Historico/Pruebas/TEST_RESULTS_0.20.0.0.md", "Docs/Historico/Entregas/DELIVERY_0.20.0.0.md"]:
    if not Path(doc).is_file():
        raise SystemExit("Falta documentación del Limpiador: " + doc)

print("Limpiador 0.1.3: integración, seguridad, privacidad, persistencia, Undo y tests verificados.")
