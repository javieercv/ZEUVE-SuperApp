# Resultados de pruebas — ZEUVE 0.13.2.0

Fecha: 8 de septiembre de 2026. Entorno: Mac Apple Silicon, macOS, Xcode 26.6 y Swift 6. Mediciones Release, tres pasadas por caso y mediana salvo donde se indica lo contrario.

## Fixtures reales

- `[FREE] mvrk x Lucho RK Type Beat ｜ 2soon ｜ prodby. avo.mp3`: MP3, 169,450688 s, 48 kHz, estéreo.
- `MZ_1972_Ep01.El nacimiento de un robot milagroso.Audio Jap,Es Tve1,Es Mex Sdi Media.mkv`: 1.502,615 s, cuatro pistas estéreo a 44,1 kHz. Streams 1–2 AAC y 3–4 MP3. El contenedor etiqueta las cuatro como `spa` y no incluye títulos; el usuario identifica la segunda pista mostrada como castellano, por lo que el informe usa índices y no inventa los otros idiomas.

FFprobe tardó 0,550 s en la primera apertura fría del MP3 y 0,017 s en el MKV. En el benchmark de servicio ya caliente registró 0,043 y 0,027 s. Los SHA-256 de ambos originales se comprobaron antes y después y no cambiaron.

## Comparación Release

| Archivo | Caso | Antes | Después | Mejora | FFT antes | FFT después | Pico antes | Pico después |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| MP3 | stream 0, mezcla | 0,499 s | 0,133 s | 3,74× | 7.942 | 7.942 | 92,4 MiB | 28,6 MiB |
| MKV | stream 1, AAC | 4,310 s | 0,709 s | 6,08× | 64.694 | 28.794 | 535,5 MiB | 28,6 MiB |
| MKV | stream 2, AAC, castellano según usuario | 4,320 s | 0,755 s | 5,72× | 64.600 | 28.752 | 534,7 MiB | 28,6 MiB |
| MKV | stream 3, MP3 | 4,193 s | 1,047 s | 4,01× | 64.708 | 28.800 | 535,6 MiB | 28,9 MiB |
| MKV | stream 4, MP3 | 4,209 s | 1,130 s | 3,72× | 64.712 | 28.800 | 535,7 MiB | 28,9 MiB |

El MP3 conserva análisis denso porque 3.971 ventanas temporales caben en el presupuesto; la mezcla estéreo produce 7.942 FFT. El MKV usa aproximadamente ocho ventanas por cada una de las 1.800 columnas y dos canales. El tiempo DSP del stream 1 baja de 3,960 a 0,433 s; FFT de 1,374 a 0,321 s y agregación de 0,525 a 0,012 s. Después del cambio, FFmpeg domina el tiempo total.

El raster de 1.200 × 420 medido fuera de SwiftUI tarda alrededor de 0,002 s. En la app Release, desde pulsar Generar hasta observar el MP3 visible se midieron 0,963 s, incluyendo actualización de UI y captura de accesibilidad.

## Caché, parámetros, progreso y cancelación

- Repetir una clave analítica real desde la caché tardó 0,0003–0,0004 s y ejecutó cero FFT.
- Rango dinámico, escala lineal/logarítmica y zoom se probaron en la app y reutilizaron el modelo; FFT y ventana invalidaron el resultado y exigieron una nueva generación.
- El MP3 se generó con FFT 4.096/Hann y 8.192/Hamming, escalas lineal/logarítmica, zoom y vuelta a vista completa.
- Las cinco operaciones reales emitieron progreso monótono, con 96 actualizaciones y valor final 1.
- La cancelación explícita, solicitada a unos 35 ms, concluyó entre 64 y 65 ms desde el inicio en los cinco casos. No quedó PID, grupo POSIX ni `OperationCoordinator` activo.
- Antes de limpiar la máscara heredada, una cancelación a 54 ms seguía recibiendo todo el PCM y concluía a 748 ms; después se detuvo a 85 ms y el recuento quedó en 366.592 muestras.

## Calidad y estrés multicanal

Se compararon PNG antes/después de MP3 y MKV en 4 y 8 ventanas por columna. Ocho ventanas preserva silencios, cambios de energía, transitorios y detalle de graves/agudos con aspecto equivalente para análisis, sin igualdad píxel a píxel. No se observaron bandas artificiales nuevas. Los tests de 440 Hz, 1 kHz, 10 kHz, Nyquist, amplitud baja, ventanas y sample rates siguen dentro de un bin o del margen original.

Un benchmark sintético de dos horas validó 5.1/7.1 y FFT 8.192/16.384. La mezcla 7.1 ejecutó como máximo 115.200 FFT; el canal individual, 14.400. Los picos se mantuvieron en 1 kHz. El peor pico registrado fue 97,4 MiB con 7.1/FFT 16.384; las columnas permanecieron en 1.800.

## Suite oficial

Comando ejecutado:

```bash
./Scripts/run_tests.sh
```

Resultado: PASS, exit code 0.

- XCTest: 215 tests, 0 fallos.
- Swift Testing: 96 tests, 0 fallos.
- Python ScriptTests: 83 tests, 0 fallos.
- Total contabilizado: 394 tests, 0 fallos.

La cobertura nueva incluye presupuesto estructural, orden y distribución de ventanas, archivos cortos, límites para FFT grandes, entradas inválidas, cancelación del acumulador, chunks f32le desalineados, mezcla 8 canales antífase, canal individual, rango/zoom sin FFT, normalización DC/Nyquist y máscara de señales del proceso hijo.

`./Scripts/verify_project.sh` terminó correctamente sobre el árbol final. A continuación, `./Scripts/build_macos.sh Release` terminó con `** BUILD SUCCEEDED **`, validó el paquete `ZEUVE.app`, comprobó la firma del paquete y verificó los seis ejecutables empaquetados (`yt-dlp`, `deno`, `ffmpeg`, `ffprobe`, `gallery-dl` e `instaloader-zeuve`).
