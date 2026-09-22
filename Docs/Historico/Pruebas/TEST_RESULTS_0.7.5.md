# Resultados de pruebas — ZEUVE 0.7.5

Fecha: 30 de julio de 2026.
Entorno utilizado: Linux x86_64 con Swift 6. La plataforma objetivo continúa siendo macOS 14 o posterior sobre Apple Silicon ARM64.

## Pruebas automáticas

- `swift test --jobs 4`: 107 pruebas XCTest y 45 pruebas Swift Testing, sin fallos.
- Ocho pruebas Swift Testing nuevas cubren recodificación MP4 real, restricción del remux al modo avanzado, valores predeterminados, CSV generado desde `showinfo`, publicación visible, conservación parcial, retirada de un último fotograma dañado y recuperación de una operación abandonada.
- Se conservan las pruebas anteriores de originales, conflictos, cancelación, temporales, ZIP, motores, privacidad, formatos y rendimiento.

## Pruebas funcionales multimedia

Se generó un vídeo sintético de tres segundos, 640 × 360, 30 fps y audio AAC:

- Extracción: 90 fotogramas PNG válidos, 90 líneas `showinfo` y progreso emitido por FFmpeg.
- Conversión MP4 → MP4: salida H.264 con 90 fotogramas, resolución y FPS conservados.
- La salida recodificada obtuvo un SHA-256 distinto del original y FFprobe confirmó la pista H.264.

## Medición comparativa de fotogramas

Prueba sintética Linux con 150 fotogramas 1920 × 1080:

- Flujo anterior simulado: 4,04 s de extracción PNG nivel 6, 1,02 s de segunda pasada de tiempos y 0,09 s de copia; total 5,15 s.
- Flujo nuevo: 2,99 s para extracción PNG nivel 3, predictor Up y tiempos en la misma pasada.
- Mejora observada en este entorno: aproximadamente 41,9 %.
- Pico aproximado del resultado: 109.400.700 bytes en el flujo anterior por duplicación frente a 54.288.019 bytes en el nuevo.

Estas cifras son orientativas y no sustituyen una medición en Apple Silicon con vídeos reales del usuario.

## Protección de originales

El ZIP original `ZEUVE_Swift_0.7.4.zip` se mantuvo sin cambios con SHA-256 `0e64412ec5c0b8c6702d3a49c1abe1f11a7062df4d3c23c84e94707e4c2c99f7`. Las pruebas utilizaron vídeos sintéticos y directorios temporales.

## Validaciones adicionales

- `swift build -c release --jobs 4`: compilación completada correctamente en 70,17 s una vez disponible la caché de compilación.
- Pruebas Python: 21 superadas.
- Sintaxis Bash de todos los scripts: válida.
- Compilación sintáctica de todos los scripts Python: válida.
- Validaciones estáticas de versiones, manifiestos, documentación, políticas de motores y regresiones: superadas.
- Proyecto Xcode regenerado con versión 0.7.5 y build 26.
- La ejecución única de `Scripts/verify_project.sh` alcanzó el límite temporal del entorno durante su compilación Release. Todas sus fases se ejecutaron y superaron después por separado, sin omitir pruebas ni comprobaciones.
- Integridad y limpieza del ZIP: se registrarán después del empaquetado final.

## Pruebas pendientes de macOS

No se puede abrir `ZEUVE.app`, validar manualmente SwiftUI/AppKit, Finder durante la extracción, VoiceOver, fluidez real, firma, Hardened Runtime, Gatekeeper ni los motores ARM64 en este entorno. Estas comprobaciones requieren un Mac Apple Silicon.
