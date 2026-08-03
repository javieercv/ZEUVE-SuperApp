# Resultados de pruebas — ZEUVE 0.2.0

Fecha: 1 de julio de 2026.

## 1. Estado comprobado

La implementación fuente de ZEUVE 0.2.0 se ha compilado y probado mediante Swift Package Manager en el entorno disponible. Las pruebas automáticas normales no realizaron conexiones con YouTube ni descargaron motores.

Resultado principal:

- **60 pruebas ejecutadas**.
- **60 pruebas superadas**.
- **0 fallos**.
- Se mantienen y superan las **30 pruebas existentes de ZEUVE 0.1.4**.
- Se añaden **30 pruebas** para motores compartidos, proceso POSIX, Descargador de YouTube e historial global.

Entorno utilizado:

- Sistema de prueba: Linux `x86_64`.
- Swift Package Manager.
- Swift Testing Library 6.2.1.
- Sin Xcode, AppKit funcional ni SDK de macOS.
- Sin acceso de ejecución a binarios macOS ARM64.

## 2. Comandos ejecutados

```bash
swift test --jobs 1
swift build -c release --jobs 4
python3 Scripts/validate_module_docs.py
bash -n Scripts/prepare_engines_macos.sh \
  Scripts/verify_engines_macos.sh \
  Scripts/sign_embedded_engines.sh \
  Scripts/build_macos.sh \
  Scripts/run_youtube_integration_tests_macos.sh
python3 -m py_compile \
  Scripts/static_pkg_config.py \
  Scripts/package_release.py \
  Scripts/generate_xcode_project.py \
  Scripts/validate_module_docs.py
```

También se analizaron sintácticamente todos los archivos Swift de `Sources/ZEUVEApp` mediante `swiftc -frontend -parse` y se regeneró `ZEUVE.xcodeproj` desde el generador del proyecto.

## 3. Pruebas conservadas

Las 30 pruebas de ZEUVE 0.1.4 permanecen presentes y superadas:

- Contrato y registro de módulos.
- Logger local.
- Coordinador global de operaciones.
- SQLite, ajustes e historial.
- Planificación del Organizador.
- Conflictos del Organizador.
- Ejecución, cancelación y deshacer del Organizador.
- Protección frente a cambios posteriores y archivos ajenos.
- Manifiesto del Organizador.

No se eliminó, debilitó ni desactivó ninguna prueba anterior.

## 4. Pruebas nuevas realizadas

### Motores compartidos

- SHA-256 con vector conocido y lectura incremental.
- Rechazo de rutas absolutas, `..`, duplicados y escapes mediante enlaces simbólicos.
- Detección de motor ausente o modificado antes de ejecutarlo.
- Comprobación de que FFmpeg y FFprobe solo tienen una entrada compartida.
- Lectura incremental de salida sin conservar toda la salida en memoria.
- Ejecución sin `/bin/sh` ni comandos concatenados.

### Procesos y cancelación

- Ejecución en un grupo de procesos independiente.
- Ejecutable auxiliar real que crea un proceso hijo.
- Cancelación del padre y del hijo mediante el grupo completo.
- Espera efectiva de terminación.
- Cierre global de procesos al terminar la aplicación.
- Lectura separada e incremental de `stdout` y `stderr`.

Estas pruebas se realizaron con ejecutables auxiliares nativos del entorno Linux. La implementación usa `posix_spawn`, grupos POSIX, `SIGTERM`, periodo limitado y `SIGKILL` como último recurso. La equivalencia específica en macOS debe verificarse todavía en Apple Silicon.

### URL y comandos de yt-dlp

- URLs de vídeo, `youtu.be`, playlist y vídeo perteneciente a playlist.
- Entradas múltiples y eliminación de duplicados.
- Esquemas, hosts y entradas mal formadas.
- Argumentos separados y validados.
- Ruta explícita de Deno mediante `--js-runtimes`.
- Ruta explícita de FFmpeg mediante `--ffmpeg-location`.
- Ausencia de `--remote-components` y actualizaciones automáticas.
- Resolución máxima, formatos exactos, numeración de playlist y subtítulos.
- Cookies y proxy sin exposición de secretos.
- Desactivación permanente de los JSON nativos de yt-dlp que pueden contener URLs firmadas.

### Parsing y playlists

- Formatos progresivos y streams separados.
- HDR, FPS, codecs, idiomas y tamaños desconocidos.
- Subtítulos manuales y automáticos diferenciados.
- Directos activos, futuros y finalizados.
- Elementos de playlist no disponibles.
- Progreso con total conocido, desconocido, fragmentos y fase FFmpeg.
- Fixture de **5.000 elementos** procesado incrementalmente.
- Buffer acotado para evitar conservar toda la salida.

### Archivos, privacidad y almacenamiento

- Saneamiento de nombres y nombres largos.
- Renombrado automático predeterminado.
- Rechazo de `.part`, `.ytdl`, ocultos y enlaces simbólicos.
- Propiedad verificable del espacio temporal.
- Limpieza sin borrar archivos ajenos.
- Historial sin URL completa, cookies, tokens ni credenciales.
- JSON informativo sanitario sin URLs firmadas, cabeceras ni secretos.
- Presets versionados sin secretos ni argumentos libres.
- Bookmarks inexistentes, inválidos y obsoletos.
- Manifiesto del módulo con permisos aprobados.
- Ausencia de descarga automática de motores en el código de ejecución.

### Historial global

- Agrupación y filtrado por `moduleID`.
- Nombre e icono obtenidos del registro de módulos.
- Presentación específica por módulo.
- Tercer módulo simulado para comprobar que la pantalla no está limitada al Organizador y al Descargador.

### Organizador

- Se añadió una comprobación de que el manifiesto declara `openExternalApplications` porque abre Finder.
- No se cambió la lógica, interfaz ni comportamiento del Organizador.

## 5. Compilaciones realizadas

### Swift Package Manager, Debug

Realizada como parte de `swift test` y superada.

### Swift Package Manager, Release

Realizada con:

```bash
swift build -c release --jobs 4
```

Resultado: compilación completada correctamente.

Un primer intento que agrupaba dos ejecuciones completas de pruebas y la validación final excedió el límite temporal de la llamada de herramienta después de terminar la compilación de producción. La validación final se repitió de forma aislada y terminó correctamente en 31,24 segundos; no se trató de un error del compilador ni de una prueba fallida.

### Xcode/macOS

No realizada. El entorno no es macOS y no dispone de Xcode ni del SDK de macOS. Por tanto, no se afirma que:

- `ZEUVE.app` haya sido compilada con Xcode;
- la aplicación haya sido abierta;
- las vistas SwiftUI/AppKit se hayan probado visualmente;
- la firma, Hardened Runtime, notarización o Gatekeeper hayan sido comprobados.

## 6. Motores externos

No se generaron ni se probaron los ejecutables macOS ARM64 de yt-dlp, Deno, FFmpeg y FFprobe en este entorno. No se han sustituido por binarios de Linux ni por archivos ficticios.

Antes de considerar completa la distribución macOS debe ejecutarse en un Mac Apple Silicon:

```bash
bash Scripts/prepare_engines_macos.sh
bash Scripts/verify_engines_macos.sh
bash Scripts/build_macos.sh
```

Estas operaciones deben comprobar realmente:

- versiones y hashes;
- arquitectura;
- permiso de ejecución;
- `otool -L`;
- dependencias dinámicas;
- disponibilidad de `libmp3lame` y `libopus`;
- ausencia de x264 y x265;
- firma de ejecutables anidados;
- compilación Debug y Release de la aplicación.

## 7. Pruebas no realizadas

- Pruebas reales contra YouTube.
- Descarga real de vídeo, audio o playlist.
- Prueba sin conexión dentro de la aplicación macOS.
- Prueba visual de modo claro y oscuro.
- Arrastrar y soltar en macOS.
- Selector de carpeta y bookmarks reales de macOS.
- Selección de `cookies.txt` mediante `NSOpenPanel`.
- Cancelación real de yt-dlp, Deno y FFmpeg en macOS.
- Cierre de la aplicación macOS durante una descarga real.
- Verificación de binarios dañados dentro de un `.app` firmado.
- Compilación, apertura, firma, notarización y Gatekeeper.

Las pruebas online están separadas y desactivadas por defecto en `Scripts/run_youtube_integration_tests_macos.sh`.

## 8. Verificación integral final

Se ejecutó finalmente:

```bash
ZEUVE_SWIFT_JOBS=4 bash Scripts/verify_project.sh
```

Resultado: superada en 31,24 segundos. Incluyó las 60 pruebas, compilación SwiftPM Release, validación de manifiestos y documentación, comprobaciones de privacidad y estructura, análisis sintáctico de todos los archivos Swift de la aplicación y regeneración de `ZEUVE.xcodeproj`. La parte macOS/Xcode se omitió de forma explícita porque el entorno era Linux x86_64.

## 9. Conclusión de pruebas

El código fuente y las capas independientes de plataforma superan las pruebas automatizadas disponibles. La entrega no puede calificarse todavía como aplicación macOS final completamente comprobada porque faltan la generación de motores ARM64, la compilación Xcode y las pruebas manuales sobre un Mac Apple Silicon.
