# Entrega — ZEUVE 0.15.3.0

Fecha: 19 de septiembre de 2026.

## Versiones

- ZEUVE: `0.15.3.0`.
- Build: `54`.
- Inspector multimedia: `0.3.3`.

## Estado de implementación

La carpeta activa `ZEUVE_Swift` se ha actualizado en su sitio. Pistas, Espectrograma, waveform y barra inferior continúan usando una única sesión de preview. El cambio de pista conserva posición y Play/Pausa; una sustitución en Pausa prepara la nueva fuente sin arrancar audio, y el seek de la waveform mantiene Pausa.

El botón del Espectrograma reutiliza la sesión compartida en lugar de reiniciar a `00:00`. Las selecciones rápidas reconocen una fuente todavía solicitada y siguen protegidas por el gate generacional de 0.15.2.0.

El gráfico del Espectrograma ya no impone 420 pt mínimos y puede reducir su altura para dejar visible el reproductor inferior. No se añadió scroll global ni se tocaron los layouts de las otras pestañas.

## QA disponible

- Inspector multimedia: **67 tests**, 0 fallos.
- Tests Python: **83 tests**, 0 fallos.
- Verificadores de integración, estructura, documentación, módulos, manifiestos y SwiftPM/Xcode: PASS.
- Build final macOS y validación manual de AVFoundation/SwiftUI: pendientes porque el entorno actual no es macOS Apple Silicon con Xcode.
- Las ejecuciones globales de Swift superaron el límite de tiempo del entorno y no se marcan como PASS.

## Límites preservados

Sin cambios en dependencias, motores, red, telemetría, privacidad, permisos, originales, publicación, edición estructural, DSP ni otros módulos.
