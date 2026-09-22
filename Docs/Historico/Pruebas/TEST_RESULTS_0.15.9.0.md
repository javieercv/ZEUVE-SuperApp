# Resultados de pruebas — ZEUVE 0.15.9.0

Fecha: 20 de septiembre de 2026.  
Entorno: Linux x86_64 con Swift 6.2.1.

## PASS

- Inspector multimedia: **80/80** pruebas Swift Testing, 0 fallos.
- Suite Swift global: el runner emitió resumen completo de **135/135** pruebas Swift Testing, 0 fallos; las suites XCTest portables ejecutaron **215** pruebas, 0 fallos y 1 omitida intencionadamente por requerir macOS Apple Silicon.
- Python: **89/89** pruebas, 0 fallos.
- Verificador específico del Inspector: PASS.
- Verificadores de integración, estructura, motores/preparación, documentación, rendimiento, Conversor, Descargador, Analizador de chats, Comparador de seguidores y manifiestos: PASS en sus ejecuciones individuales.
- `python3 Scripts/verify/app_sources.py`: PASS; **70** fuentes Swift de ZEUVEApp parseadas.
- `python3 Scripts/verify/xcode_integration.py`: PASS; **10** productos SwiftPM/Xcode coherentes.
- `python3 Scripts/validate_module_docs.py`: PASS.
- `Scripts/generate_xcode_project.py`: Xcode regenerado para build 60 / marketing 0.15.9 / revision 0.

## Cobertura nueva

- silencio estéreo solo cuando todos los canales están bajo el umbral;
- conservación de frames interleaved entre chunks PCM;
- clipping únicamente tras el número mínimo de muestras consecutivas y agrupación de eventos cercanos;
- audio fuerte pero por debajo del umbral no se clasifica como clipping;
- límites de almacenamiento sin perder el recuento total;
- compatibilidad de preferencias antiguas con valores seguros;
- command builder con stream exacto, PCM `f32le` y sin forzar `-ar`/`-ac`;
- verificadores de orden automático espectrograma → señal → sonoridad y de cancelación de la fase nueva.

## Limitaciones del entorno

`./Scripts/run_tests.sh` alcanzó y registró los resúmenes completos de Swift sin fallos, pero el proceso `swift test` no devolvió el control al wrapper dentro del límite temporal del harness remoto; por ello Python se ejecutó y validó también de forma independiente.

`swift build -c release --jobs 1` inició correctamente y avanzó por varios targets, pero no completó dentro del límite temporal remoto; no se observó un error de compilación antes del corte. Por esta misma razón no se declara `./Scripts/verify_project.sh` como ejecución integral completada; todos sus verificadores Python se ejecutaron por separado.

`./Scripts/build_macos.sh Release` confirma que la compilación real requiere macOS Apple Silicon con Xcode, no disponible en este entorno.

## Validación manual recomendada en macOS

1. WAV/MP3 de una pista: comprobar espectrograma → señal → sonoridad automáticamente.
2. Vídeo con una pista: mismo flujo y marcadores alineados en waveform/espectrograma.
3. Contenedor con varias pistas: confirmar que **Señal** permanece manual por pista.
4. Audio estéreo con un canal audible y otro silencioso: no clasificar el tramo como silencio global.
5. Audio con silencios conocidos: comprobar umbral -60 dBFS, mínimo 0,5 s y zoom/pan.
6. Audio fuerte sin saturación: comprobar ausencia de falsos positivos evidentes.
7. Señal con saturación conocida: comprobar **Posible clipping**, tiempo/canal/pico y agrupación.
8. Cancelar durante el análisis y confirmar que se libera `OperationCoordinator` sin resultado parcial.
9. Repetir Play/Pausa/seek y cambio de pista para confirmar que no reaparecen regresiones 0.15.3–0.15.8.
