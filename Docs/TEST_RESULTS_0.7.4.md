# Resultados de pruebas — ZEUVE 0.7.4

Fecha: 30 de julio de 2026.
Entorno utilizado: Linux x86_64 con Swift 6. La plataforma objetivo continúa siendo macOS 14 o posterior sobre Apple Silicon ARM64.

## Pruebas ejecutadas

- `swift test --jobs 1`: 107 pruebas XCTest completadas sin fallos.
- Suite Swift Testing del Conversor: 37 pruebas completadas sin fallos.
- Equivalencia comprobada entre búsquedas directas y búsquedas mediante el índice compacto para palabras, frase exacta, mayúsculas y diacríticos.
- Comprobado el cambio a archivo temporal mapeado para un índice grande y su eliminación al limpiar la sesión.
- Comprobada la reutilización de una sentencia SQLite preparada para todas las filas del lote.
- Comprobada la migración que crea el índice global del historial por fecha.
- Comprobado que el agrupador conserva el último progreso pendiente y publica inmediatamente un estado final.
- Conservadas las pruebas de originales, conflictos, cancelación, temporales, ZIP, motores, privacidad y formatos de las versiones anteriores.

## Protección de originales

El ZIP original `ZEUVE_Swift_0.7.3.zip` se conservó sin cambios. Su SHA-256 antes del trabajo fue `3bbb99cae73c367331d26125211672e661ef1cab2f3d510e455147072c1c1063`. Las pruebas utilizaron datos sintéticos y directorios temporales.

## Validaciones adicionales

- `swift build -c release --jobs 4`: completado correctamente. El paralelismo se utilizó únicamente para terminar la validación dentro de los límites del entorno.
- `python3 -m unittest discover -s Tests/ScriptTests -p 'test_*.py' -v`: 21 pruebas completadas sin fallos.
- `bash -n Scripts/*.sh`: sintaxis Bash válida.
- `python3 -m py_compile Scripts/*.py`: sintaxis Python válida.
- `Scripts/verify_project.sh` con `ZEUVE_SWIFT_JOBS=4`: completado correctamente. Incluyó las pruebas Swift, compilación Release, políticas estáticas, documentación, manifiestos, regeneración de Xcode y pruebas Python.
- Regeneración de `ZEUVE.xcodeproj`: completada con versión 0.7.4 y build 25.

## Pruebas no realizables en este entorno

No se puede abrir `ZEUVE.app`, validar manualmente SwiftUI/AppKit, VoiceOver, hover, fluidez real, firma, Hardened Runtime, motores ARM64 ni empaquetado nativo. Estas comprobaciones requieren un Mac Apple Silicon.
