# Resultados de pruebas — ZEUVE 0.20.6.0

## Evidencia ejecutada en macOS Apple Silicon

- `./Scripts/run_tests.sh`: PASS; suite Swift completa y 114 pruebas Python, incluidos los dos harness que compilan los métodos reales de reset global y ejecución/cancelación del Conversor.
- `./Scripts/verify_project.sh`: PASS, incluidos SwiftPM Release, 114 tests Python, verificadores documentales/de módulos/manifests, parseo, coherencia SwiftPM/Xcode y build Debug real.
- Suite dirigida de Conversor/Inspector/Limpiador: regresiones de canales efectivos, selección explícita, WebM incompatible, texto ambiguo/UTF-8 corrupto, metadata reordenada, carátulas y validadores con contrastes negativos. El test de vídeo ejecuta un proceso controlado real y prueba seek pausado y sustituciones rápidas sin runnerBusy.
- Persistencia: reapertura de SQLite conserva presets/reglas/favoritos tras reset de preferencias y recupera Deshacer; conflictos, cambios de objeto y ubicación fuera de Papelera se rechazan. La suite incluye Papelera nativa con un archivo desechable.
- Integración real `nativeQAEditing`: 5 casos PASS con FFmpeg/FFprobe empaquetados. Metadata de vídeo y attachment sin codec_name, conservación de carátula MKV, adición/sustitución MP4 y retirada de portada; misma cantidad de pistas audiovisuales y originales idénticos. Imagen MKV extraída antes/después: bytes idénticos. FFprobe con hashes SHA-256 de paquetes confirma que todos los paquetes de audio/vídeo de los cinco resultados de edición son idénticos a sus originales.
- Integración real `nativeQAConversion`: 9 casos PASS. Opus/OGG mono automático anunciado a 256 kb/s, Opus estéreo explícito 320 kb/s y seis rutas TXT/MD/HTML con Pandoc 3.10. Writers plain comprobados y originales idénticos.
- Builds oficiales Debug y Release: BUILD SUCCEEDED, motores empaquetados y firma ad hoc verificados. No se genera ZIP ni se altera la app instalada.

Pandoc 3.10 se reutiliza solo en una copia interna QA del bundle Debug. Binario oficial ARM64 SHA-256 `d0a20cc85a03ec30f602c6acb568158982240431e5589e0e7c01ce80e0253493`; no se instala globalmente ni se añade al empaquetado mantenido.

## Aceptación manual y límites

Se inició una app QA con ZEUVE_DATA_DIR aislado y se observó Inicio. Al intentar entrar en Conversor el controlador devolvió `Sky Computer Use native pipe closed before response`; reinicio del controlador y posteriores intentos tampoco recuperaron el acceso. No se completó ningún recorrido de aceptación de los 22 IDs. Todos conservan ❌ y la nota «corregido, pendiente de comprobación». El estado acumulado permanece 639 pruebas: 568 OK, 23 fallidas, 14 parciales y 34 pendientes.

Los doce originales sintéticos de la carpeta QA conservan exactamente sus SHA-256 de partida.

Estas pruebas no certifican el layout a distintos tamaños, latencia visual exacta, reproducción auditiva A/V ni todos los formatos de Release. Los originales y resultados son sintéticos; no se realizan resets personales, sesiones de Instagram ni comprobaciones remotas del Descargador. El fallo del controlador se separa de los fallos de producto.
