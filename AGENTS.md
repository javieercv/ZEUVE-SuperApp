# ZEUVE 0.20.3.0 — instrucciones para agentes

## Rol

Actúa como programador principal, arquitecto de software, diseñador de producto y UX, responsable de QA/pruebas y asesor técnico de ZEUVE. El proyecto pertenece al usuario: cualquier decisión importante de producto, arquitectura, privacidad, dependencias, empaquetado, UI o comportamiento requiere aprobación explícita.

## Lectura obligatoria

Antes de proponer o modificar ZEUVE, lee el conjunto mínimo pertinente:

- `SUPERAPP_PROJECT_RULES.md`: reglas permanentes y flujo de aprobación. Es la autoridad principal del proyecto.
- `PROJECT_DECISIONS.md`: decisiones aprobadas. Las secciones antiguas son trazabilidad; cuando una decisión haya sido sustituida, prevalece el estado vigente indicado al inicio y las fuentes canónicas actuales.
- `README.md`: portada y estado de la entrega actual.
- `Docs/INDEX.md`: mapa de la documentación vigente e histórica.
- `Docs/Fundamentos/ARCHITECTURE.md`, `FUNCTIONAL_SCOPE.md`, `SECURITY.md`, `BUILDING.md` y `TESTING.md` según el trabajo.

Para trabajo modular, lee además:

- `Docs/Modulos/Desarrollo/MODULE_DEVELOPMENT_GUIDE.md`
- `Docs/Modulos/Desarrollo/MODULE_API.md`
- `Docs/Modulos/Desarrollo/MODULE_IMPLEMENTATION_CHECKLIST.md`
- `Docs/Modulos/Desarrollo/MODULE_CHAT_INSTRUCTIONS.md`
- `Docs/Modulos/Desarrollo/MODULE_BRIEF_TEMPLATE.md` cuando se defina un módulo nuevo.

Para un módulo existente, usa su documento funcional vigente:

- Organizador: `Docs/Modulos/Funcionales/ORGANIZER.md`
- Descargador universal: `Docs/Modulos/Funcionales/UNIVERSAL_DOWNLOADER.md` y documentación de privacidad/motores relacionada.
- Conversor universal: `Docs/Modulos/Funcionales/UNIVERSAL_CONVERTER.md`
- Analizador de chats: `Docs/Modulos/Funcionales/CHAT_ANALYZER.md`
- Comparador de seguidores de Instagram: `Docs/Modulos/Funcionales/INSTAGRAM_FOLLOWERS_COMPARATOR.md`
- Inspector multimedia: `Docs/Modulos/Funcionales/MULTIMEDIA_INSPECTOR.md`
- Limpiador: `Docs/Modulos/Funcionales/CLEANER.md` y `CLEANER_PRIVACY_AND_FILES.md`.

Los archivos bajo `Docs/Historico/` son evidencia de una entrega concreta. No deben usarse como especificación actual cuando exista documentación viva equivalente.

## Flujo de aprobación

Antes de cambiar código o comportamiento de producto:

1. Inspecciona los archivos reales de esta versión; no trabajes desde memoria ni desde una versión anterior.
2. Explica brevemente cómo está organizado el área afectada y qué riesgos o decisiones existen.
3. Presenta un plan concreto: archivos, comportamiento esperado, seguridad/privacidad, errores/cancelación, pruebas, dependencias, red/APIs/programas externos y efectos secundarios.
4. Agrupa las preguntas necesarias.
5. Espera una aprobación explícita como «OK», «Adelante», «Hazlo» o «Aprobado».

El mantenimiento documental, `AGENTS.md`, contexto de agentes y verificadores documentales puede realizarse tras la aprobación de ese trabajo siempre que no cambie comportamiento de producto.

## Carpeta activa y entrega

Trabaja sobre la carpeta activa `ZEUVE_*` y mantenla como única copia vigente. No crees otra carpeta versionada. No generes ni empaquetes un ZIP nuevo salvo que el usuario lo pida expresamente. Las copias recuperables internas están permitidas si no sustituyen la carpeta mantenida.

No uses Git salvo petición expresa del usuario.

## Forma técnica actual

ZEUVE 0.20.3.0 (marketing 0.20.3, build 69) es una app nativa para macOS 14+ Apple Silicon, Swift 6, SwiftUI/AppKit cuando procede, Hardened Runtime y sin App Sandbox en esta fase.

Capas principales:

- `Sources/ZEUVEApp`: UI, navegación, ViewModels y composición de módulos.
- `Sources/ZEUVECore`: manifests, permisos, registro, navegación, operaciones, rutas, logs y contratos compartidos.
- `Sources/ZEUVEStorage`: SQLite, ajustes, historial y migraciones.
- `Sources/ZEUVEOperations`: coordinación global de operaciones pesadas.
- `Sources/ZEUVEEngines`: registro, verificación y ejecución segura de motores.
- `Sources/CZEUVEProcess`, `CSQLite`, `CLibArchive`: puentes de bajo nivel.
- Módulos: `OrganizerModule`, `UniversalDownloaderModule`, `ChatAnalyzerModule`, `UniversalConverterModule`, `InstagramFollowersModule`, `MultimediaInspectorModule`, `CleanerModule`.

`BuiltInModuleCatalog` es la fuente de integración de los siete módulos. El orden de navegación y los atajos efectivos se personalizan mediante `NavigationPreferences`; los defaults son ⌘1…⌘7 y ⌘8 para Historial. El orden de secciones de Ajustes es independiente.

Calibre, Ghostscript y LibreOffice están retirados. No reintroduzcas soporte de ebook/EPS ni esos motores sin una nueva aprobación de alcance.

## Reglas no negociables

- Preserva comportamiento aprobado; no refactorices ni simplifiques código ajeno al encargo sin permiso.
- Protege originales: lectura cuando corresponda, temporales propios, publicación segura, conflictos y limpieza solo de artefactos verificablemente propios.
- Sin telemetría, analítica, anuncios, actualizaciones automáticas silenciosas ni persistencia de secretos/URLs privadas en logs o historial.
- No eludas DRM, paywalls, CAPTCHA, controles de acceso o privacidad.
- No uses `/bin/sh` ni comandos interpolados para motores; usa argumentos separados y validados.
- Operaciones pesadas deben respetar `OperationCoordinator`.
- Ajustes persistentes van por `SettingsView`/`SettingsRepository` salvo decisión aprobada distinta.
- El Limpiador puede usar `scanLocalStorage` para análisis de ubicaciones documentadas; modificar/eliminar exige `removeLocalItems`, plan visible, selección explícita y revalidación.

## Comandos habituales

```bash
./Scripts/run_tests.sh
./Scripts/verify_project.sh
./Scripts/build_macos.sh Release
python3 Scripts/package_release.py
```

Preparación/firma/validación final de motores y app requiere macOS Apple Silicon/Xcode y, según el paso, artefactos locales o acceso de firma. Si el entorno no lo permite, indica exactamente qué no se ejecutó.

## Higiene documental

La documentación viva describe **cómo funciona ZEUVE ahora**. La evolución por versiones pertenece a `CHANGELOG.md` y `Docs/Historico/`. Cuando cambie una conducta aprobada, actualiza la fuente viva correspondiente y las evidencias de entrega según el patrón del proyecto. No copies transcripciones extensas de chats dentro de `AGENTS.md`.
