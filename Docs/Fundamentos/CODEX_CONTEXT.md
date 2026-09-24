# Contexto operativo para agentes — ZEUVE 0.20.3.0

Este documento es un mapa rápido. No sustituye a `SUPERAPP_PROJECT_RULES.md`, `PROJECT_DECISIONS.md` ni a la documentación funcional concreta.

## Fuentes canónicas

1. `SUPERAPP_PROJECT_RULES.md`: reglas permanentes y aprobaciones.
2. `PROJECT_DECISIONS.md`: decisiones aprobadas y su trazabilidad.
3. `Docs/Fundamentos/`: arquitectura, alcance, seguridad, build y pruebas actuales.
4. `Docs/Modulos/Funcionales/`: comportamiento vigente de cada módulo.
5. `Docs/Motores/` y `Resources/Engines/engines.json`: motores y empaquetado.
6. `Docs/Historico/`: evidencia de versiones anteriores; no es especificación vigente.

No existe una dependencia de contexto en `../../.agents/skills/` ni debe suponerse que recursos externos al proyecto están disponibles.

## Estado de producto

- ZEUVE: `0.20.3.0`.
- Marketing: `0.20.3`.
- Build: `69`.
- Plataforma: macOS 14+ Apple Silicon.
- Swift 6; SwiftUI + AppKit; Hardened Runtime; sin App Sandbox en esta fase.

## Módulos built-in

| ID | Versión | Atajo por defecto |
| --- | --- | --- |
| `com.zeuve.organizer` | 0.1.4 | ⌘1 |
| `com.zeuve.universal-downloader` | 0.7.3 | ⌘2 |
| `com.zeuve.chat-analyzer` | 0.1.6 | ⌘3 |
| `com.zeuve.universal-converter` | 0.3.0 | ⌘4 |
| `com.zeuve.instagram-followers` | 0.1.0 | ⌘5 |
| `com.zeuve.multimedia-inspector` | 0.7.2 | ⌘6 |
| `com.zeuve.cleaner` | 0.1.1 | ⌘7 |

Historial usa ⌘8 por defecto. `BuiltInModuleCatalog` conserva IDs/defaults; `NavigationPreferences` determina orden y atajos efectivos personalizados.

## Fronteras importantes

- No hay carga dinámica de módulos externos implementada.
- Los módulos no deben depender entre sí; comparten capacidades mediante Core/Storage/Operations/Engines.
- `SettingsRepository` centraliza preferencias persistentes; `GlobalHistoryService`/repositorios de historial evitan almacenar contenido privado innecesario.
- `OperationCoordinator` es la autoridad para una operación pesada principal.
- Motores se ejecutan por `ExternalProcessRunner`, sin shell interpolado.
- FFprobe compartido vive en `ZEUVEEngines`; módulos multimedia no deben duplicar un ejecutor inseguro.
- Calibre, Ghostscript y LibreOffice están retirados.

## Cómo leer el histórico

Una frase de un `IMPLEMENTATION_REPORT_*`, `DELIVERY_*` o `TEST_RESULTS_*` describe esa entrega, no necesariamente el presente. Si contradice una fuente viva o el código actual, conserva el documento histórico y corrige la documentación viva; no reescribas el pasado para que parezca actual.
