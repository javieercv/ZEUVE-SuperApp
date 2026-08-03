# Resultados de pruebas — ZEUVE 0.5.2

Fecha: 3 de julio de 2026.

## Resumen

La versión 0.5.2 corrige la transición entre la pantalla de resultados y la pantalla inicial del Analizador de chats, amplía la ayuda contextual de las nueve pestañas de resultados y actualiza las reglas permanentes y decisiones aprobadas del proyecto.

## Pruebas automáticas

### Swift

Comando:

```bash
swift test --jobs 1
```

Resultado:

- 97 pruebas ejecutadas.
- 97 pruebas superadas.
- 0 fallos.
- 0 fallos inesperados.

La suite cubre el núcleo, almacenamiento, coordinador de operaciones, Organizador, Descargador de YouTube y Analizador de chats. Las 26 pruebas específicas del Analizador continúan superándose sin cambios en sus resultados.

### Python y validaciones de scripts

Comando:

```bash
python3 -m unittest discover -s Tests/ScriptTests -p 'test_*.py' -v
```

Resultado:

- 15 pruebas ejecutadas.
- 15 pruebas superadas.
- 0 fallos.

Se añadieron cuatro regresiones nuevas:

1. La vista que alterna entre importación y resultados observa directamente `ChatAnalyzerViewModel`.
2. `Cerrar análisis` conserva las fuentes y `Analizar otro chat` las limpia.
3. Las nueve pestañas de resultados contienen ayuda contextual general y los componentes analíticos reutilizan cabeceras y tarjetas con ayuda.
4. Las ocho reglas permanentes nuevas están presentes y la regla final queda renumerada como 64.

## Validación sintáctica de la interfaz

Se ejecutó:

```bash
for file in $(find Sources/ZEUVEApp -name '*.swift' -print); do
  swiftc -frontend -parse "$file"
done
```

Resultado: todos los archivos SwiftUI/AppKit de la aplicación se analizaron sintácticamente sin errores.

## Compilación SwiftPM

Se ejecutaron las configuraciones Debug mediante `swift test` y Release mediante `swift build -c release --jobs 1` como parte de la validación final.

## Comprobaciones específicas de la corrección

- `ChatAnalyzerView` delega en `ChatAnalyzerObservedContent` con `@ObservedObject`.
- La condición de navegación utiliza `model.session == nil`.
- `closeAnalysis()` no llama a `clearInputs()`.
- `analyzeAnother()` llama a `closeAnalysis()` y después a `clearInputs()`.
- Resumen, Actividad, Participantes, Palabras y emojis, Búsqueda, Conversaciones, Tiempos de respuesta, Comparación y Fusiones incluyen ayuda contextual general.
- Las tarjetas de métricas, gráficos, grupos de resultados, filas de valor y cabeceras de tablas no evidentes admiten temas de ayuda.
- `ContextualHelpButton` sigue siendo el único componente visual de ayuda, con etiqueta de accesibilidad y popover común.

## Integridad y privacidad

- No se utilizaron ni incorporaron chats reales para esta corrección.
- No se modificaron los ZIP originales aportados anteriormente.
- No se añadieron dependencias, APIs, red, telemetría ni servicios externos.
- Los cambios se limitan a la navegación, ayuda contextual, documentación, reglas, versión y pruebas relacionadas.

## Pruebas no realizadas

El entorno de validación es Linux x86_64. No fue posible:

- compilar el objetivo completo de la aplicación con Xcode;
- abrir `ZEUVE.app` en macOS;
- comprobar visualmente los popovers, tamaños, foco y navegación real;
- probar VoiceOver, modo claro/oscuro y `NSOpenPanel` en macOS.

Estas comprobaciones deben realizarse en un Mac Apple Silicon con macOS 14 o posterior.
