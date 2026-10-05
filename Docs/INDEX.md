# Documentación de ZEUVE

Esta carpeta separa la documentación **vigente** —la que se consulta para diseñar, desarrollar, validar y mantener ZEUVE 0.20.7.0— de las evidencias **históricas** de cada entrega. Empieza aquí para localizar la fuente adecuada sin recorrer el historial.

Si una afirmación histórica contradice una fuente vigente o el código actual, no se reescribe el histórico: se usa la fuente vigente y se corrige cualquier documentación viva desactualizada.

## Consulta rápida

| Necesidad | Ubicación |
| --- | --- |
| Reglas permanentes y flujo de aprobación | `../SUPERAPP_PROJECT_RULES.md` |
| Decisiones aprobadas | `../PROJECT_DECISIONS.md` |
| Sincronización, commits y publicación del repositorio | `Fundamentos/REPOSITORY_WORKFLOW.md` |
| Arquitectura, alcance, seguridad, compilación y pruebas | `Fundamentos/` |
| Licencias, créditos y avisos de terceros | `Fundamentos/LICENCIAS_Y_CREDITOS.md` + `../THIRD_PARTY_NOTICES.md` |
| Desarrollo de módulos, API, checklist y plantillas | `Modulos/Desarrollo/` |
| Comportamiento y límites de cada módulo integrado | `Modulos/Funcionales/` |
| Preparación, empaquetado y gestión de motores | `Motores/` |
| Ejemplos JSON del contrato de módulos | `Modulos/Ejemplos/` |
| Entregas, implementación, QA, hashes y compatibilidad anteriores | `Historico/` |

## Fundamentos

- [Arquitectura](Fundamentos/ARCHITECTURE.md): capas, módulos, navegación y fronteras compartidas.
- [Alcance funcional](Fundamentos/FUNCTIONAL_SCOPE.md): qué hace y qué no hace ZEUVE actualmente.
- [Seguridad y privacidad](Fundamentos/SECURITY.md): archivos, red, procesos, motores, logs y datos.
- [Flujo de repositorio](Fundamentos/REPOSITORY_WORKFLOW.md): sincronización obligatoria antes de trabajar, protección frente a divergencias y publicación/verificación final en GitHub.
- [Compilación](Fundamentos/BUILDING.md): versiones, motores, build, firma, validación y empaquetado.
- [Pruebas](Fundamentos/TESTING.md): estrategia, comandos y evidencia actual.
- [Licencias y créditos](Fundamentos/LICENCIAS_Y_CREDITOS.md): código propio, componentes del sistema, terceros, atribuciones y reglas de mantenimiento.
- [Avisos de software de terceros](../THIRD_PARTY_NOTICES.md): inventario consolidado y enlaces a los textos legales originales.
- [Contexto para agentes](Fundamentos/CODEX_CONTEXT.md): mapa operativo breve para trabajo asistido.

## Desarrollo de módulos

- [Guía de desarrollo](Modulos/Desarrollo/MODULE_DEVELOPMENT_GUIDE.md)
- [API de módulos](Modulos/Desarrollo/MODULE_API.md)
- [Checklist de implementación](Modulos/Desarrollo/MODULE_IMPLEMENTATION_CHECKLIST.md)
- [Instrucciones para chats/agentes](Modulos/Desarrollo/MODULE_CHAT_INSTRUCTIONS.md)
- [Plantilla de brief](Modulos/Desarrollo/MODULE_BRIEF_TEMPLATE.md)
- [Ejemplos de implementación](Modulos/Desarrollo/MODULE_EXAMPLES.md)

Ejemplos JSON del contrato: [`Modulos/Ejemplos/`](Modulos/Ejemplos/).

## Módulos funcionales

- [Organizador de archivos](Modulos/Funcionales/ORGANIZER.md)
- [Descargador universal](Modulos/Funcionales/UNIVERSAL_DOWNLOADER.md)
- [Privacidad y red del Descargador](Modulos/Funcionales/UNIVERSAL_DOWNLOADER_PRIVACY_AND_NETWORK.md)
- [Analizador de chats](Modulos/Funcionales/CHAT_ANALYZER.md)
- [Conversor universal](Modulos/Funcionales/UNIVERSAL_CONVERTER.md)
- [Comparador de seguidores de Instagram](Modulos/Funcionales/INSTAGRAM_FOLLOWERS_COMPARATOR.md)
- [Inspector multimedia](Modulos/Funcionales/MULTIMEDIA_INSPECTOR.md)
- [Limpiador](Modulos/Funcionales/CLEANER.md)
- [Privacidad y archivos del Limpiador](Modulos/Funcionales/CLEANER_PRIVACY_AND_FILES.md)

Compatibilidad histórica del antiguo módulo YouTube: [documento legacy](Modulos/Funcionales/YOUTUBE_DOWNLOADER.md) y [privacidad legacy](Modulos/Funcionales/YOUTUBE_PRIVACY_AND_NETWORK.md). No sustituyen la documentación del Descargador universal.

## Motores

- [Motores del Descargador](Motores/UNIVERSAL_DOWNLOADER_ENGINES.md)
- [Empaquetado de motores](Motores/UNIVERSAL_DOWNLOADER_ENGINE_PACKAGING.md)
- [Gestión y overrides](Motores/ENGINE_MANAGEMENT.md)
- [Compatibilidad histórica YouTube](Motores/YOUTUBE_ENGINES.md)

La instantánea empaquetable concreta se define en `../Resources/Engines/engines.json`.

## Entrega actual — 0.20.7.0

- [Implementación de parciales](Historico/Implementacion/IMPLEMENTATION_REPORT_0.20.7.0.md).
- [Verificación técnica](Historico/Pruebas/TEST_RESULTS_0.20.7.0.md).
- [QA manual 0.20.7.0 — 05/10/2026](Historico/Pruebas/MANUAL_QA_0.20.7.0_20261005.md): nueve parciales locales aceptados desde UI.
- [Entrega](Historico/Entregas/DELIVERY_0.20.7.0.md).

## Histórico

`Historico/` conserva lo que se entregó, implementó o probó en cada versión. No se actualiza para hacerlo coincidir con el presente y no debe usarse como especificación vigente cuando exista una fuente equivalente en `Fundamentos/`, `Modulos/` o `Motores/`.

Evidencia de la entrega anterior 0.20.6.0: [implementación](Historico/Implementacion/IMPLEMENTATION_REPORT_0.20.6.0.md), [pruebas](Historico/Pruebas/TEST_RESULTS_0.20.6.0.md), [entrega](Historico/Entregas/DELIVERY_0.20.6.0.md) y [revalidación manual de los 22 IDs corregidos](Historico/Pruebas/MANUAL_QA_0.20.6.0_20261004.md).

- [`Historico/Entregas/`](Historico/Entregas/): notas de entrega.
- [`Historico/Implementacion/`](Historico/Implementacion/): informes de implementación.
- [`Historico/Pruebas/`](Historico/Pruebas/): resultados de pruebas.
- [`Historico/HashesMotores/`](Historico/HashesMotores/): hashes/versiones históricas de motores.
- [`Historico/Compatibilidad/`](Historico/Compatibilidad/): matrices de compatibilidad antiguas.
- [`Historico/Informes/`](Historico/Informes/): informes técnicos puntuales.

## Fuente canónica por tema

| Tema | Fuente principal |
| --- | --- |
| Reglas y aprobación | `SUPERAPP_PROJECT_RULES.md` |
| Decisiones aprobadas | `PROJECT_DECISIONS.md` |
| Repositorio, sincronización y publicación | `Fundamentos/REPOSITORY_WORKFLOW.md` |
| Estado/entrada pública | `README.md` |
| Capas y dependencias | `Fundamentos/ARCHITECTURE.md` |
| Funciones y exclusiones | `Fundamentos/FUNCTIONAL_SCOPE.md` + documento de módulo |
| Seguridad/privacidad | `Fundamentos/SECURITY.md` + documento específico cuando exista |
| Build/firma | `Fundamentos/BUILDING.md` + scripts reales |
| Motores actuales | `Resources/Engines/engines.json` + `Motores/` |
| Licencias y créditos | `Fundamentos/LICENCIAS_Y_CREDITOS.md` + `THIRD_PARTY_NOTICES.md` + `Resources/Engines/licenses/` |
| Registro built-in | manifests + `BuiltInModuleCatalog.swift` |
| Evidencia de una versión | `Historico/` |

## Convención para cambios futuros

1. La documentación viva describe el estado actual, no una cronología acumulada.
2. Una decisión sustituida puede conservarse en `PROJECT_DECISIONS.md`, pero debe quedar inequívocamente marcada como histórica/sustituida.
3. Los cambios por versión se registran en `CHANGELOG.md` y `Historico/`.
4. Todo módulo built-in debe tener un documento funcional enlazado aquí y desde el README.
5. Una nueva fuente viva debe quedar enlazada desde este índice para no crear documentación huérfana.
6. Todo trabajo sobre el proyecto debe comenzar desde el estado remoto sincronizado y, si modifica archivos, finalizar con la publicación y verificación del resultado en el repositorio salvo instrucción expresa contraria.
