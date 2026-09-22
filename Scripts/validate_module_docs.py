#!/usr/bin/env python3
"""Validate the module documentation and its machine-readable examples."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "Docs"
MODULE_DEVELOPMENT = DOCS / "Modulos" / "Desarrollo"
EXAMPLES = DOCS / "Modulos" / "Ejemplos"

required_docs = [
    MODULE_DEVELOPMENT / "MODULE_DEVELOPMENT_GUIDE.md",
    MODULE_DEVELOPMENT / "MODULE_CHAT_INSTRUCTIONS.md",
    MODULE_DEVELOPMENT / "MODULE_IMPLEMENTATION_CHECKLIST.md",
    MODULE_DEVELOPMENT / "MODULE_EXAMPLES.md",
    MODULE_DEVELOPMENT / "MODULE_BRIEF_TEMPLATE.md",
    MODULE_DEVELOPMENT / "MODULE_API.md",
]

for path in required_docs:
    if not path.is_file() or path.stat().st_size < 200:
        raise SystemExit(f"Documento de módulos ausente o vacío: {path.relative_to(ROOT)}")

manifest_path = EXAMPLES / "module-manifest.example.json"
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
required_manifest_fields = {
    "schemaVersion",
    "identifier",
    "name",
    "summary",
    "version",
    "minimumZEUVEVersion",
    "moduleAPI",
    "technology",
    "executionMode",
    "permissions",
    "capabilities",
    "presentation",
}
missing = required_manifest_fields - manifest.keys()
if missing:
    raise SystemExit(f"Campos ausentes en el manifiesto de ejemplo: {sorted(missing)}")
if manifest["schemaVersion"] != 1 or manifest["moduleAPI"] != "1.0":
    raise SystemExit("El manifiesto de ejemplo no usa schema 1 / API 1.0")

allowed_technologies = {"swift", "python", "rust", "executable", "web", "mixed"}
allowed_execution_modes = {"builtIn", "isolatedProcess"}
allowed_permissions = {
    "readUserSelectedFiles",
    "writeUserSelectedFolder",
    "persistentFolderAccess",
    "networkAccess",
    "executeBundledTools",
    "webContent",
    "browserCookies",
    "clipboard",
    "openExternalApplications",
}
allowed_capabilities = {
    "preview",
    "progress",
    "cancellation",
    "history",
    "presets",
    "favorites",
    "undo",
    "dragAndDrop",
    "diagnostics",
}
if manifest["technology"] not in allowed_technologies:
    raise SystemExit("Tecnología no válida en el manifiesto de ejemplo")
if manifest["executionMode"] not in allowed_execution_modes:
    raise SystemExit("Modo de ejecución no válido en el manifiesto de ejemplo")
if not set(manifest["permissions"]) <= allowed_permissions:
    raise SystemExit("Permiso no válido en el manifiesto de ejemplo")
if not set(manifest["capabilities"]) <= allowed_capabilities:
    raise SystemExit("Capacidad no válida en el manifiesto de ejemplo")

request = json.loads((EXAMPLES / "module-request.example.json").read_text(encoding="utf-8"))
request_id = request.get("requestID")
if request.get("protocolVersion") != "1.0" or not request_id:
    raise SystemExit("Petición de ejemplo no válida")

sequences: list[int] = []
for filename in [
    "module-event-accepted.example.json",
    "module-event-progress.example.json",
    "module-event-result.example.json",
]:
    event = json.loads((EXAMPLES / filename).read_text(encoding="utf-8"))
    if event.get("protocolVersion") != "1.0":
        raise SystemExit(f"Versión de protocolo incorrecta en {filename}")
    if event.get("requestID") != request_id:
        raise SystemExit(f"requestID no correlacionado en {filename}")
    sequences.append(event["sequence"])
if sequences != sorted(sequences) or len(sequences) != len(set(sequences)):
    raise SystemExit("Las secuencias de eventos de ejemplo no son crecientes y únicas")

ai_text = (MODULE_DEVELOPMENT / "MODULE_CHAT_INSTRUCTIONS.md").read_text(encoding="utf-8")
for required_phrase in [
    "Wait for approval",
    "keep the complete active project folder updated in place",
    "create a ZIP only when the user explicitly requests one",
    "User-imported modules are a future feature",
    "OperationCoordinator",
]:
    if required_phrase not in ai_text:
        raise SystemExit(f"Falta una instrucción esencial para asistentes: {required_phrase}")

print("Documentación de módulos y ejemplos JSON validados correctamente.")
