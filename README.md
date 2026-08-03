# ZEUVE 0.7.5

ZEUVE es una aplicación nativa y modular para macOS Apple Silicon. La versión 0.7.5 corrige la conversión de vídeo para que el modo simple recodifique realmente y acelera vídeo → fotogramas mediante escritura visible directa, CSV en una sola pasada y PNG sin pérdida con compresión más rápida, sin añadir dependencias.

## Estado de esta entrega

El código fuente incluye:

- aplicación nativa para macOS 14 o posterior, ARM64 y Hardened Runtime;
- Organizador, Descargador de YouTube, Analizador de chats y Conversor universal;
- procesamiento local, sin telemetría, publicidad ni actualizaciones automáticas;
- conversión real de vídeo en modo simple; MP4 utiliza H.264 automáticamente y la copia rápida/remux queda como opción avanzada explícita y desactivada por defecto;
- extracción de fotogramas directamente en una carpeta visible de salida, sin duplicar todo el resultado al finalizar;
- conservación segura de fotogramas válidos en una carpeta `Incompleto` cuando se cancela, falla o se recupera una operación abandonada;
- PNG sin pérdida con compresión nivel 3 y predictor Up, `tiempos.csv` creado durante la misma ejecución de FFmpeg y progreso real por número de fotogramas;
- caché temporal compacta de búsqueda creada bajo demanda y eliminada con la sesión del Analizador;
- inserción SQLite temporal por lotes y cálculos analíticos sin duplicaciones innecesarias;
- diagnóstico de motores compartido entre módulos, reutilizado mientras los archivos no cambian;
- progreso agrupado para evitar actualizaciones excesivas de SwiftUI sin simular porcentajes;
- escáner reutilizable y protección de rutas originales precalculada en el Conversor;
- historial cargado fuera del hilo principal e indexado por fecha;
- rechazo explícito de formatos ofimáticos en el Conversor, con CSV conservado como datos;
- protección de los originales, nombres resueltos antes de ejecutar y publicación atómica.

La copia entregada conserva los motores ya presentes —yt-dlp, Deno, FFmpeg y FFprobe—. Pandoc, Calibre y Ghostscript continúan registrados como **opcionales no proporcionados** hasta ejecutar `Scripts/prepare_engines_macos.sh` en un Mac Apple Silicon.

## Motores aprobados

- yt-dlp 2026.06.09.
- Deno 2.9.0.
- FFmpeg y FFprobe 8.1.2 ARM64.
- libmp3lame 3.100, libopus 1.5.2, libx264 r3222 y libwebp 1.6.0 enlazados estáticamente en FFmpeg.
- Pandoc 3.10 ARM64 para TXT, Markdown, HTML y EPUB.
- Calibre 9.11.0 para libros electrónicos.
- Ghostscript 10.07.1 ARM64 para EPS.

LibreOffice no se descarga, registra, firma ni empaqueta. No se añade libx265. El usuario final no debe instalar Homebrew, Python ni motores manualmente.

## Preparación de motores en macOS

```bash
./Scripts/prepare_engines_macos.sh
./Scripts/verify_engines_macos.sh
```

## Compilación

```bash
python3 Scripts/generate_xcode_project.py
./Scripts/build_macos.sh Debug
./Scripts/build_macos.sh Release
```

La compilación y apertura nativa deben verificarse en un Mac Apple Silicon. Esta entrega se ha validado lógicamente en Linux x86_64; no incluye una `.app` abierta ni firmada en macOS.

## Pruebas

```bash
./Scripts/run_tests.sh
./Scripts/verify_project.sh
```

Consulta `Docs/TEST_RESULTS_0.7.5.md` para los resultados exactos y las limitaciones del entorno.

## Documentación

- `Docs/CHAT_ANALYZER.md`: funcionamiento y caché temporal del Analizador.
- `Docs/UNIVERSAL_CONVERTER.md`: alcance y optimizaciones del Conversor.
- `Docs/IMPLEMENTATION_REPORT_0.7.5.md`: cambios realizados.
- `Docs/TEST_RESULTS_0.7.5.md`: pruebas ejecutadas y pendientes.
- `Docs/DELIVERY_0.7.5.md`: contenido de la entrega.

## Crear un ZIP limpio

```bash
python3 Scripts/package_release.py
```

El empaquetado excluye `.build`, DerivedData, cachés, temporales, logs, `.DS_Store`, `__MACOSX`, datos locales de Xcode y archivos privados.
