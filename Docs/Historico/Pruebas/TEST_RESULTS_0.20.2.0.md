# Resultados de pruebas — ZEUVE 0.20.2.0

## Automatización

- `ExternalProcessRunnerTests`: 6/6 PASS, incluida la nueva regresión de cancelación corta exclusiva de preview.
- La prueba equivalente con la gracia global conservada tarda aproximadamente 2,08 s cuando el proceso ignora SIGTERM; con la gracia opt-in de preview termina aproximadamente en 0,11 s, sin padre, hijos ni entradas del registro pendientes.
- Regresiones Swift dirigidas de preview: PASS para continuidad Play/Pausa, sustitución serializada, invalidación de sustitución pendiente, estado global de vídeo y mapeo/seek de streams.
- Regresiones Python específicas del Inspector: 17 PASS y 1 omitida porque requiere Combine/macOS.
- Suite Python completa: 112 PASS y 1 omitida porque requiere Combine/macOS.
- Verificadores de integración, estructura, motores, documentación, rendimiento, módulos, manifiestos, parseo de ZEUVEApp y coherencia SwiftPM/Xcode: PASS.
- Parseo sintáctico de `ZEUVEApp`: 80 archivos Swift, PASS.
- `swift test --jobs 1` compiló correctamente y no mostró fallos en las pruebas ejecutadas, pero la suite completa excedió el límite disponible antes de finalizar; no se declara PASS completo.
- `swift build -c release --jobs 1` avanzó sin errores de compilación, pero excedió el límite disponible antes de finalizar; no se declara build Release completado.

## Alcance de regresión

La cobertura nueva verifica que la optimización no modifique el default global de `ExternalProcessRunner`, que audio/vídeo opten explícitamente por la cancelación corta, que la salida de audio se corte antes de esperar el cleanup y que el monitor del ViewModel no siga publicando durante Pausa.

La validación final Xcode/macOS ARM64 y la interacción manual real del reproductor deben ejecutarse en macOS Apple Silicon.
