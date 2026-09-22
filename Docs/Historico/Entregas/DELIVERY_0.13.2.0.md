# Entrega — ZEUVE 0.13.2.0

Fecha: 8 de septiembre de 2026.

## Versiones

- ZEUVE canónica: 0.13.2.0.
- `MARKETING_VERSION`: 0.13.2.
- `ZEUVEReleaseRevision`: 0.
- Build interno: 49.
- Inspector multimedia: 0.1.2.

## Estado

La Fase 2 incorpora planificación temporal adaptativa, PCM por bloques, buffers vDSP reutilizables, agregación directa de potencia, caché temporal acotada, progreso determinado, render rasterizado fuera del actor principal y cancelación efectiva de FFmpeg.

Los benchmarks reales muestran entre 3,72× y 6,08× de mejora total. El pico del proceso de prueba del MKV baja de unos 535 MiB a unos 29 MiB. El análisis corto conserva todos los hops; el largo limita el trabajo a ocho ventanas por columna y canal.

## QA y prueba manual

`./Scripts/run_tests.sh` pasa con 394 tests contabilizados y cero fallos. La prueba manual Release del MP3 cubre apertura, generación, FFT, Hann/Hamming, escala lineal/logarítmica, zoom y regeneración. El benchmark integrado cubre las cuatro pistas reales del MKV por índice, cambios de pista, caché, progreso, cancelación y recuperación.

`./Scripts/verify_project.sh` terminó correctamente sobre el árbol final. `./Scripts/build_macos.sh Release` terminó con `** BUILD SUCCEEDED **`; el paquete y los motores incluidos superaron las verificaciones de contenido y firma. Los resultados medidos se detallan en `Docs/TEST_RESULTS_0.13.2.0.md`.

## Privacidad y dependencias

No se añaden dependencias, motores, red, APIs, telemetría, analytics ni permisos. Los modelos y la caché viven solo en memoria. Los archivos de prueba se abrieron en lectura, no se copiaron ni modificaron, y sus hashes finales coinciden con los iniciales.

No se genera ZIP ni una carpeta versionada adicional. La única carpeta activa continúa siendo `ZEUVE_Swift`.
