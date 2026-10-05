# Cierre local de QA: volumen y sincronía — 05/10/2026

ZEUVE 0.20.7.0, marketing 0.20.7/build 73, copia interna Release. Base remota actualizada `d50a2a1c48f2c852be5875659d11aa02891955ac`, sin cambios locales iniciales ni divergencia. El usuario pide acabar todo menos el Descargador y autoriza continuar. No cambia código de producto, versión, dependencias, ajustes reales ni permisos de ZEUVE.

## Método

Fixture propio de 60 s: vídeo H.264 de 480×270 a 30 FPS con flashes blancos de 150 ms cada dos segundos desde el segundo 2; dos audios PCM de 48 kHz, pulsos de 880 y 1760 Hz con el mismo timing. Se abre por UI en Inspector/Pistas, se reproduce, se opera el volumen, se salta y reanuda y se sustituye la pista A/B. SQLite separado mediante `ZEUVE_DATA_DIR` en `AudioVideoClosure/Data`.

Un auxiliar externo de QA usa ScreenCaptureKit del sistema, con acceso de captura ya concedido. El filtro incluye únicamente el PID verificado del ejecutable de QA; excluye otras aplicaciones, escritorio y micrófono. Captura audio de la salida de la app (loopback software) y brillo de una región dentro de su vídeo mostrado a 60 FPS. No captura los archivos fuente para inferir que sonaron: mide la salida del proceso reproductor y la imagen presentada. Los timestamps de ambos tipos de sample buffer pertenecen al mismo reloj de captura.

El análisis identifica el inicio de los pulsos de audio por encima del 10 % de su amplitud y las transiciones de negro a blanco de los frames. Empareja por proximidad temporal y conserva todos los pares. El límite observado es inferior a 100 ms; la medición de vídeo tiene resolución de captura de 16,7 ms y el origen de 33,3 ms. Se declaran los valores medidos; no se afirma ausencia absoluta de desfase.

## I-29 — OK

Pico de audio con volumen máximo: **0,200083**. Slider operado con clic real a **0,494444**: pico **0,098925**, razón **0,494420**, coherente con la ganancia seleccionada. Con volumen cero, el PCM capturado es cero mientras se observan cuatro flashes: el vídeo sigue reproduciéndose, por lo que el silencio no se confunde con pausa. Al restaurar el volumen se vuelve a capturar señal; el control termina exactamente en **1**, comprobado por AX.

El primer intento de mute coincidió con una sesión detenida y no acredita aceptación. Se repite en reproducción activa; solo `mute-playing` acredita mute. Los intentos de preparación y salto pausado se conservan, sin contarlos como pulsos de sincronía.

## I-35 — OK

**21 pulsos audiovisuales emparejados**, con audio−vídeo entre **−32,79 y +93,53 ms**. Incluye el inicio, reproducción sostenida a 1×, salto de transporte/reanudación y sustitución de pista A por B. El tono de la salida capturada cambia de 880,00 a 1760,02 Hz, confirmando que el cambio de pista alcanzó el audio real de la app.

| Escenario | Pulsos | Audio − vídeo (ms) |
| --- | ---: | --- |
| Inicial | 4 | -6.48, -23.14, 93.53, 60.21 |
| Volumen máximo | 4 | 74.78, 91.46, 58.13, 24.79 |
| Volumen intermedio | 4 | 17.92, 24.76, 24.77, 8.11 |
| Después de salto/reanudación | 5 | 44.26, 43.51, -23.14, 76.87, 10.19 |
| Después de sustituir pista A por B | 4 | -31.83, 33.88, -32.78, -32.79 |

## Evidencia y cierre

Los scripts auxiliares `capture.swift` y `analyze.py`, buffers PCM, registros `audio.jsonl`/`video.jsonl`, análisis por escenario y `closure-results.json` se conservan fuera del proyecto, en `QA-partials-20261005/AudioVideoClosure`, dentro de la carpeta de visualizaciones del chat. El resumen medido también se conserva junto a este informe en [AUDIO_VIDEO_RESULTS_0.20.7.0_20261005.json](AUDIO_VIDEO_RESULTS_0.20.7.0_20261005.json). El SHA-256 del fixture es `19b73dcbc756623c1fbfcc15ae7f0b81fb28f4bb83611bf851c7be35a8dd885f`.

Los nueve originales de la ronda anterior conservan sus hashes. Preview se detiene y la app QA sale normalmente; no quedan procesos de esa sesión. Los dos espejos de checklist externos se sincronizan con la fuente canónica. Los 639 IDs y títulos permanecen intactos.

Resultado acumulado: **601 OK / 1 fallo / 3 parciales / 34 pendientes**. No queda ningún estado sin OK fuera del Descargador y de su autenticación remota: D-13, D-15/D-60, P-12 remoto y 33 pendientes D más P-11. Se mantienen sus estados, sin aprobar pruebas excluidas.

## Límites y verificaciones

Es una prueba de reproducción mediante salida digital capturada; no afirma escucha humana, calibración de altavoces ni compensación de latencia de dispositivos externos. El bucle medido cierra la falta anterior de captura de salida. No certifica otros formatos, todas las velocidades, lip-sync de cualquier contenido, distribución ni notarización; las aceptaciones previas y sus límites se conservan.

Se ejecutan los verificadores documentales, de enlaces, de manifests y la comprobación de diff/639 títulos. No se repiten builds ni suites de código: esta ronda no modifica producto y conserva la Release y verificaciones aprobadas de la entrega `d50a2a1`. Se vuelve a comprobar el remoto antes de publicar mediante commit normal.
