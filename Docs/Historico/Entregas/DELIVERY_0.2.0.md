# Informe de entrega — ZEUVE 0.2.0

Fecha: 1 de julio de 2026.

## 1. Resumen breve

ZEUVE 0.2.0 incorpora el módulo nativo **Descargador de YouTube**, una infraestructura compartida de motores externos, historial global dirigido por datos y soporte seguro para análisis y descarga secuencial de vídeos, audio y playlists.

La implementación utiliza Swift y SwiftUI para la interfaz y la orquestación, `yt-dlp` para la extracción, Deno para los desafíos JavaScript de YouTube y FFmpeg/FFprobe para unión, remultiplexado, conversión y validación. No utiliza Flask, Electron, servidores locales, Python del sistema, Homebrew, shell ni actualizaciones automáticas.

## 2. Estado

**Parcialmente completada por limitación del entorno de compilación.**

Completado:

- código fuente del módulo y su integración en la aplicación;
- infraestructura compartida `ZEUVEEngines`;
- ejecución POSIX segura y cancelación de grupos de procesos;
- validación, análisis, formatos, playlists, subtítulos, progreso y publicación segura;
- interfaz SwiftUI en español;
- historial global extensible;
- historial, presets, favoritos y diagnósticos del módulo;
- bookmarks de carpetas;
- scripts reproducibles para preparar, verificar, firmar y empaquetar motores;
- documentación y versión 0.2.0;
- 60 pruebas automáticas superadas;
- compilación Swift Package Manager en Debug y Release.

Pendiente de realizar en un Mac Apple Silicon:

- descargar y generar los motores macOS aprobados;
- generar `Resources/Engines/engines.json` con hashes y tamaños finales;
- verificar `otool -L` sobre los ejecutables reales;
- compilar la aplicación con Xcode en Debug y Release;
- firmar y abrir `ZEUVE.app`;
- ejecutar pruebas manuales y online separadas.

No se incluyen binarios arbitrarios, ejecutables de Linux ni placeholders. Por ello, el código está preparado, pero el Descargador no será ejecutable en la aplicación final hasta completar el paso documentado de preparación de motores en macOS.

## 3. Pruebas realizadas

El detalle completo se encuentra en `Docs/TEST_RESULTS_0.2.0.md`.

Resultados:

- 60 pruebas ejecutadas;
- 60 superadas;
- 0 fallos;
- 30 pruebas originales conservadas;
- compilación SwiftPM Debug superada;
- compilación SwiftPM Release superada;
- validación de documentación y manifiestos superada;
- parsing sintáctico de las vistas Swift superado;
- scripts Bash y Python validados sintácticamente;
- verificación integral `Scripts/verify_project.sh` superada en 31,24 segundos.

No se afirma que la aplicación macOS haya sido compilada o abierta.

## 4. Explicación detallada

### 4.1 Infraestructura compartida de motores

Se creó `ZEUVEEngines`, reutilizable por futuros módulos como el Conversor universal. Contiene únicamente responsabilidades generales:

- lectura y validación de `engines.json`;
- localización segura dentro de `Resources/Engines`;
- SHA-256 incremental;
- inspección Mach-O y arquitectura;
- comprobación de permisos;
- diagnóstico de versión y arranque;
- lectura incremental de salida;
- ejecución sin shell;
- grupos de procesos independientes;
- cancelación de procesos descendientes;
- registro global para cierre de la aplicación.

La capa C `CZEUVEProcess` encapsula `posix_spawn` y crea un grupo de procesos nuevo sin incluir el proceso principal de ZEUVE.

### 4.2 Descargador de YouTube

El módulo `com.zeuve.youtube-downloader` tiene versión 0.2.0, tecnología `mixed` y modo `builtIn`.

Incluye:

- URLs de vídeo, enlaces cortos, playlists y múltiples URLs;
- eliminación de duplicados;
- análisis cancelable antes de descargar;
- información del contenido, formatos, codecs, FPS, HDR, audio, subtítulos y directos;
- modos simple y avanzado;
- selección automática o exacta de vídeo y audio;
- audio original, M4A, MP3, FLAC, WAV y Opus;
- selección de playlist, rango e índices;
- continuidad segura cuando falla un elemento;
- subtítulos manuales y automáticos separados;
- metadatos, miniatura, capítulos, descripción y JSON sanitario;
- nombres seguros y vista previa;
- conflictos con renombrado automático predeterminado;
- progreso real e indeterminado según la información disponible;
- cancelación y resumen final;
- historial local sin URLs completas ni secretos;
- presets versionados y favoritos;
- proxy opcional con credenciales solo en memoria;
- `cookies.txt` opcional, sin copia ni persistencia;
- diagnóstico en español.

Los directos activos y futuros se detectan y se rechazan con una explicación clara. Los ya finalizados se tratan como vídeos normales cuando yt-dlp lo permite.

### 4.3 Privacidad

No se almacenan:

- cookies;
- rutas de cookies;
- tokens;
- credenciales de proxy;
- cabeceras privadas;
- URLs firmadas de `googlevideo`;
- argumentos completos de procesos;
- URLs completas en el historial predeterminado.

Los JSON nativos de información de yt-dlp se desactivan. Cuando el usuario solicita información JSON o metadatos de playlist, ZEUVE genera un documento sanitario propio con campos aprobados.

No existe telemetría, analítica, publicidad, actualización automática ni descarga de motores durante el uso normal.

### 4.4 Archivos y publicación

Cada operación crea un espacio temporal marcado con un UUID y un archivo de propiedad. Solo se limpian ubicaciones verificadas como propias.

La publicación:

- rechaza archivos incompletos `.part` y `.ytdl`;
- rechaza enlaces simbólicos y nombres ocultos accidentales;
- verifica el resultado antes de publicarlo;
- nunca permite que yt-dlp escriba sobre un resultado existente;
- usa renombrado automático por defecto;
- requiere confirmación explícita para reemplazar;
- copia primero a un nombre temporal del destino cuando cambia el volumen;
- realiza después el renombrado final;
- nunca elimina archivos ajenos.

### 4.5 Historial global

La pantalla global no contiene una lista fija de dos módulos. Filtra por `moduleID`, obtiene nombre e icono del registro y permite presentadores específicos por módulo. Una prueba usa un tercer módulo simulado para verificar la extensibilidad.

Los registros y funciones del Organizador se mantienen. El adaptador visual del historial del Organizador reside en la aplicación, sin cambiar su servicio de historial ni su lógica.

### 4.6 Organizador

La única modificación funcional autorizada en su módulo es añadir `openExternalApplications` al manifiesto porque ya abre Finder. Se añadió una prueba de coherencia de permisos. No se modificó su funcionamiento, interfaz, planificación, ejecución o deshacer.

### 4.7 Motores y construcción reproducible

`Scripts/prepare_engines_macos.sh`:

- exige macOS Apple Silicon;
- descarga versiones fijadas mediante HTTPS;
- verifica hashes de artefactos y fuentes;
- incorpora yt-dlp 2026.06.09 y Deno 2.9.0;
- compila Opus 1.5.2 y LAME 3.100 de forma estática;
- compila FFmpeg y FFprobe 8.1.2 ARM64;
- habilita `libmp3lame` y `libopus`;
- desactiva red en FFmpeg;
- no habilita x264 ni x265;
- copia avisos de licencia;
- genera hashes y tamaños reales en `engines.json`.

`Scripts/verify_engines_macos.sh` comprueba versión, hash, tamaño, arquitectura, permisos, licencia, ejecución, perfil de codecs y dependencias dinámicas mediante `otool -L`.

## 5. Versión

- Versión anterior: 0.1.4, build 5.
- Versión nueva: **0.2.0, build 6**.
- Descargador de YouTube: **0.2.0**.
- Module API: 1.0.

El incremento `MINOR` corresponde a un nuevo módulo importante compatible con las funciones anteriores.

## 6. Motores y hashes

Los hashes de los artefactos de entrada fijados están en `Docs/ENGINE_HASHES_0.2.0.md`.

Los hashes finales de los ejecutables se generarán en `Resources/Engines/engines.json` durante la preparación real en macOS. No se inventan hashes finales antes de disponer de los binarios reales.

## 7. Limitaciones reales

- Los motores ARM64 no se han fabricado ni ejecutado en este entorno.
- `engines.json` final no se incluye porque debe representar bytes reales generados en macOS.
- No se ha compilado ni abierto la aplicación con Xcode.
- No se ha comprobado firma, Hardened Runtime, notarización o Gatekeeper.
- No se han realizado descargas reales contra YouTube.
- La compatibilidad de YouTube puede cambiar y requerir una nueva versión de ZEUVE; no existe actualización automática.
- Directos activos y futuros están fuera del alcance de 0.2.0.
- Acceso directo a cookies de navegadores y Keychain está fuera del alcance de 0.2.0.
- App Sandbox permanece desactivado y pendiente de una prueba técnica específica.

## 8. Paso obligatorio en el Mac de desarrollo

Antes de considerar lista la aplicación macOS:

```bash
cd ZEUVE_Swift_0.2.0
bash Scripts/prepare_engines_macos.sh
bash Scripts/verify_engines_macos.sh
bash Scripts/verify_project.sh
bash Scripts/build_macos.sh
```

Después deben realizarse las pruebas manuales descritas en `Docs/TESTING.md` y, de forma separada y voluntaria, las pruebas online de `Scripts/run_youtube_integration_tests_macos.sh`.

## 9. Protección del original

El archivo original `ZEUVE_Swift_0.1.4.zip` se ha mantenido intacto. Todo el trabajo se realizó sobre una copia extraída independiente.

## 10. Archivos creados y modificados

La lista siguiente se obtiene comparando la entrega con ZEUVE 0.1.4. No se eliminó ningún archivo.

### Archivos nuevos

- `Docs/DELIVERY_0.2.0.md`: informe de entrega de la versión 0.2.0.
- `Docs/ENGINE_HASHES_0.2.0.md`: documentación técnica específica de 0.2.0.
- `Docs/TEST_RESULTS_0.2.0.md`: informe verificable de pruebas de la versión 0.2.0.
- `Docs/YOUTUBE_DOWNLOADER.md`: documentación técnica específica de 0.2.0.
- `Docs/YOUTUBE_ENGINES.md`: documentación técnica específica de 0.2.0.
- `Docs/YOUTUBE_PACKAGING.md`: documentación técnica específica de 0.2.0.
- `Docs/YOUTUBE_PRIVACY_AND_NETWORK.md`: documentación técnica específica de 0.2.0.
- `Resources/Engines/README.md`: estructura documentada para motores compartidos.
- `Resources/Engines/licenses/deno/LICENSE.md`: aviso o licencia de terceros.
- `Resources/Engines/licenses/ffmpeg/COPYING.GPLv2`: aviso o licencia de terceros.
- `Resources/Engines/licenses/ffmpeg/LICENSE.md`: aviso o licencia de terceros.
- `Resources/Engines/licenses/lame/COPYING`: aviso o licencia de terceros.
- `Resources/Engines/licenses/opus/COPYING`: aviso o licencia de terceros.
- `Resources/Engines/licenses/yt-dlp/LICENSE`: aviso o licencia de terceros.
- `Resources/Engines/licenses/yt-dlp/THIRD_PARTY_LICENSES.txt`: aviso o licencia de terceros.
- `Scripts/prepare_engines_macos.sh`: preparación, verificación, firma o pruebas opcionales de motores.
- `Scripts/run_youtube_integration_tests_macos.sh`: preparación, verificación, firma o pruebas opcionales de motores.
- `Scripts/sign_embedded_engines.sh`: preparación, verificación, firma o pruebas opcionales de motores.
- `Scripts/static_pkg_config.py`: preparación, verificación, firma o pruebas opcionales de motores.
- `Scripts/verify_engines_macos.sh`: preparación, verificación, firma o pruebas opcionales de motores.
- `Sources/CZEUVEProcess/CZEUVEProcess.c`: puente POSIX para procesos y grupos independientes.
- `Sources/CZEUVEProcess/include/CZEUVEProcess.h`: puente POSIX para procesos y grupos independientes.
- `Sources/CZEUVEProcess/module.modulemap`: puente POSIX para procesos y grupos independientes.
- `Sources/YouTubeDownloaderModule/Commands/YouTubeCommandBuilder.swift`: dominio, operaciones, almacenamiento o manifiesto del nuevo módulo.
- `Sources/YouTubeDownloaderModule/Commands/YouTubeFormatSelector.swift`: dominio, operaciones, almacenamiento o manifiesto del nuevo módulo.
- `Sources/YouTubeDownloaderModule/Errors/YouTubeDownloaderError.swift`: dominio, operaciones, almacenamiento o manifiesto del nuevo módulo.
- `Sources/YouTubeDownloaderModule/Files/YouTubeDiskSpaceChecker.swift`: dominio, operaciones, almacenamiento o manifiesto del nuevo módulo.
- `Sources/YouTubeDownloaderModule/Files/YouTubeFilenamePolicy.swift`: dominio, operaciones, almacenamiento o manifiesto del nuevo módulo.
- `Sources/YouTubeDownloaderModule/Files/YouTubeOutputPublisher.swift`: dominio, operaciones, almacenamiento o manifiesto del nuevo módulo.
- `Sources/YouTubeDownloaderModule/Files/YouTubeSafeMetadata.swift`: dominio, operaciones, almacenamiento o manifiesto del nuevo módulo.
- `Sources/YouTubeDownloaderModule/Files/YouTubeTemporaryWorkspace.swift`: dominio, operaciones, almacenamiento o manifiesto del nuevo módulo.
- `Sources/YouTubeDownloaderModule/Models/YouTubeModels.swift`: dominio, operaciones, almacenamiento o manifiesto del nuevo módulo.
- `Sources/YouTubeDownloaderModule/Operations/YouTubeAnalysisService.swift`: dominio, operaciones, almacenamiento o manifiesto del nuevo módulo.
- `Sources/YouTubeDownloaderModule/Operations/YouTubeDownloadService.swift`: dominio, operaciones, almacenamiento o manifiesto del nuevo módulo.
- `Sources/YouTubeDownloaderModule/Operations/YouTubeEngineLocator.swift`: dominio, operaciones, almacenamiento o manifiesto del nuevo módulo.
- `Sources/YouTubeDownloaderModule/Parsing/YouTubeAnalysisParser.swift`: dominio, operaciones, almacenamiento o manifiesto del nuevo módulo.
- `Sources/YouTubeDownloaderModule/Parsing/YouTubeErrorClassifier.swift`: dominio, operaciones, almacenamiento o manifiesto del nuevo módulo.
- `Sources/YouTubeDownloaderModule/Parsing/YouTubeProgressParser.swift`: dominio, operaciones, almacenamiento o manifiesto del nuevo módulo.
- `Sources/YouTubeDownloaderModule/Resources/manifest.json`: dominio, operaciones, almacenamiento o manifiesto del nuevo módulo.
- `Sources/YouTubeDownloaderModule/Storage/SecurityScopedFolderBookmarkStore.swift`: dominio, operaciones, almacenamiento o manifiesto del nuevo módulo.
- `Sources/YouTubeDownloaderModule/Storage/YouTubeHistoryService.swift`: dominio, operaciones, almacenamiento o manifiesto del nuevo módulo.
- `Sources/YouTubeDownloaderModule/Storage/YouTubePresetService.swift`: dominio, operaciones, almacenamiento o manifiesto del nuevo módulo.
- `Sources/YouTubeDownloaderModule/Validation/YouTubePathValidator.swift`: dominio, operaciones, almacenamiento o manifiesto del nuevo módulo.
- `Sources/YouTubeDownloaderModule/Validation/YouTubeURLValidator.swift`: dominio, operaciones, almacenamiento o manifiesto del nuevo módulo.
- `Sources/YouTubeDownloaderModule/YouTubeDownloaderModuleDefinition.swift`: dominio, operaciones, almacenamiento o manifiesto del nuevo módulo.
- `Sources/ZEUVEApp/History/GlobalHistoryView.swift`: historial global dirigido por datos.
- `Sources/ZEUVEApp/YouTubeDownloader/YouTubeDownloaderView.swift`: interfaz nativa y ViewModel del Descargador.
- `Sources/ZEUVEApp/YouTubeDownloader/YouTubeDownloaderViewModel.swift`: interfaz nativa y ViewModel del Descargador.
- `Sources/ZEUVECore/HistoryPresentation.swift`: contrato y servicio compartido de presentación del historial.
- `Sources/ZEUVEEngines/EngineDiagnostics.swift`: infraestructura compartida de motores externos.
- `Sources/ZEUVEEngines/EngineModels.swift`: infraestructura compartida de motores externos.
- `Sources/ZEUVEEngines/EngineRegistry.swift`: infraestructura compartida de motores externos.
- `Sources/ZEUVEEngines/ExternalProcessRunner.swift`: infraestructura compartida de motores externos.
- `Sources/ZEUVEEngines/MachOInspector.swift`: infraestructura compartida de motores externos.
- `Sources/ZEUVEEngines/SHA256.swift`: infraestructura compartida de motores externos.
- `Sources/ZEUVEStorage/GlobalHistoryService.swift`: contrato y servicio compartido de presentación del historial.
- `Tests/YouTubeDownloaderModuleTests/GlobalHistoryTests.swift`: pruebas del Descargador y del historial extensible.
- `Tests/YouTubeDownloaderModuleTests/YouTubeFilesStorageAndManifestTests.swift`: pruebas del Descargador y del historial extensible.
- `Tests/YouTubeDownloaderModuleTests/YouTubeParsingTests.swift`: pruebas del Descargador y del historial extensible.
- `Tests/YouTubeDownloaderModuleTests/YouTubeURLAndCommandTests.swift`: pruebas del Descargador y del historial extensible.
- `Tests/ZEUVEEnginesTests/EngineRegistryTests.swift`: pruebas del registro, diagnóstico y procesos externos.
- `Tests/ZEUVEEnginesTests/ExternalProcessRunnerTests.swift`: pruebas del registro, diagnóstico y procesos externos.

### Archivos modificados

- `CHANGELOG.md`: entrada completa de la versión 0.2.0.
- `Docs/ARCHITECTURE.md`: arquitectura, seguridad, alcance, API, desarrollo o pruebas actualizadas.
- `Docs/BUILDING.md`: arquitectura, seguridad, alcance, API, desarrollo o pruebas actualizadas.
- `Docs/Examples/module-manifest.example.json`: arquitectura, seguridad, alcance, API, desarrollo o pruebas actualizadas.
- `Docs/FUNCTIONAL_SCOPE.md`: arquitectura, seguridad, alcance, API, desarrollo o pruebas actualizadas.
- `Docs/MODULE_API.md`: arquitectura, seguridad, alcance, API, desarrollo o pruebas actualizadas.
- `Docs/MODULE_DEVELOPMENT_GUIDE.md`: arquitectura, seguridad, alcance, API, desarrollo o pruebas actualizadas.
- `Docs/MODULE_EXAMPLES.md`: arquitectura, seguridad, alcance, API, desarrollo o pruebas actualizadas.
- `Docs/SECURITY.md`: arquitectura, seguridad, alcance, API, desarrollo o pruebas actualizadas.
- `Docs/TESTING.md`: arquitectura, seguridad, alcance, API, desarrollo o pruebas actualizadas.
- `PROJECT_DECISIONS.md`: decisiones aprobadas para motores, cookies, procesos, historial, sandbox y privacidad.
- `Package.swift`: targets y pruebas de ZEUVEEngines, CZEUVEProcess y YouTubeDownloaderModule.
- `README.md`: módulos, preparación de motores, ejecución, privacidad y limitaciones actuales.
- `Scripts/build_macos.sh`: construcción, verificación, generación Xcode o empaquetado limpio.
- `Scripts/generate_xcode_project.py`: construcción, verificación, generación Xcode o empaquetado limpio.
- `Scripts/package_release.py`: construcción, verificación, generación Xcode o empaquetado limpio.
- `Scripts/verify_project.sh`: construcción, verificación, generación Xcode o empaquetado limpio.
- `Sources/OrganizerModule/Resources/manifest.json`: únicamente permiso openExternalApplications.
- `Sources/ZEUVEApp/AppModel.swift`: integración de navegación, dashboard, ajustes, ciclo de vida o historial.
- `Sources/ZEUVEApp/DashboardView.swift`: integración de navegación, dashboard, ajustes, ciclo de vida o historial.
- `Sources/ZEUVEApp/RootView.swift`: integración de navegación, dashboard, ajustes, ciclo de vida o historial.
- `Sources/ZEUVEApp/SettingsView.swift`: integración de navegación, dashboard, ajustes, ciclo de vida o historial.
- `Sources/ZEUVEApp/ZEUVEApp.swift`: integración de navegación, dashboard, ajustes, ciclo de vida o historial.
- `Tests/OrganizerModuleTests/OrganizerManifestTests.swift`: prueba de coherencia del permiso de Finder.
- `VERSION`: versión 0.2.0.
- `ZEUVE.xcodeproj/project.pbxproj`: proyecto regenerado con versión, targets, recursos y firma de motores.

### Archivos eliminados

- Ninguno.

## 11. Entrega

El proyecto se entrega completo en un ZIP limpio, sin `.build`, `.engine-build`, cachés, registros, resultados de prueba, credenciales ni binarios de otra plataforma.
