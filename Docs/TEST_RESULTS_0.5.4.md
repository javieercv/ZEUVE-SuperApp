# Resultados de pruebas — ZEUVE 0.5.4

Fecha: 3 de julio de 2026.

## Resumen

La versión 0.5.4 añade interacción por hover a todos los gráficos del Analizador de chats. La posición del cursor se transforma mediante `ChartProxy`, el elemento más cercano se resalta y se presenta un tooltip con el valor exacto y su fecha, periodo, hora o categoría. Los gráficos comparativos muestran ambas series y el total conjunto. La capa visual utiliza únicamente las instantáneas ya calculadas y no vuelve a recorrer los mensajes.

## Pruebas automáticas

### Swift

Comando:

```bash
swift test --jobs 1
```

Resultado:

- 101 pruebas ejecutadas.
- 101 pruebas superadas.
- 0 fallos.
- 0 fallos inesperados.

Las pruebas del Analizador mantienen la cobertura de importación, normalización, filtros, fusiones, actividad, participantes, palabras, conversaciones, respuestas, comparación, búsqueda, caché y un conjunto sintético de 35.000 mensajes.

### Python y validaciones de scripts

Comando:

```bash
python3 -m unittest discover -s Tests/ScriptTests -p 'test_*.py' -v
```

Resultado:

- 19 pruebas ejecutadas.
- 19 pruebas superadas.
- 0 fallos.

La nueva regresión comprueba:

- existencia de un tooltip común y reutilizable;
- uso de `chartOverlay`, `ChartProxy.plotFrame` y `onContinuousHover`;
- hover en los tres gráficos temporales o mensuales;
- hover en los cinco gráficos de categorías;
- interacción específica en el mapa de calor;
- total conjunto en los gráficos comparativos;
- ausencia de llamadas a cálculos analíticos pesados desde la capa de interacción.

## Compilación

Se ejecutó:

```bash
swift build -c release --jobs 1
```

Resultado: compilación SwiftPM Release completada sin errores.

También se ejecutó `Scripts/verify_project.sh`, que volvió a lanzar las pruebas, validó manifiestos, versión, documentación, políticas de privacidad, ausencia de dependencias nuevas, sintaxis de las vistas y regeneración del proyecto Xcode.

## Validación sintáctica de la interfaz

Se ejecutó `swiftc -frontend -parse` sobre todos los archivos Swift de `Sources/ZEUVEApp`, incluido `InteractiveChartSupport.swift`.

Resultado: ningún error sintáctico.

## Comprobaciones específicas de la interacción

- Evolución temporal de Actividad: guía vertical, puntos resaltados, periodo exacto, Total, WhatsApp e Instagram cuando están presentes.
- Actividad por hora: franja exacta y número de mensajes.
- Actividad por día: día de la semana y número de mensajes.
- Mapa de calor: celda resaltada, día, franja horaria y mensajes.
- Perfil de participante: mes exacto y mensajes.
- Distribución de respuestas: intervalo y número de respuestas.
- Comparación temporal: ambas personas y total conjunto.
- Comparación por hora y por día: ambas personas y total conjunto.
- El tooltip desaparece al salir del gráfico y el estado se limpia al cambiar de persona, granularidad o pestaña.
- La selección temporal más cercana se obtiene mediante búsqueda binaria sobre fechas ordenadas.
- El histograma de respuestas se genera en una sola pasada sobre las muestras.

## Integridad y privacidad

- No se añadieron dependencias, Internet, APIs, telemetría ni servicios externos.
- La interacción no lee archivos ni accede a la base temporal.
- No se incorporaron chats reales al proyecto, las pruebas o la entrega.
- El ZIP original 0.5.3 conserva su SHA-256: `94d9f5310ea04f892f794fa2668faffedf21068e7143444d10da421be342e6a5`.

## Pruebas no realizadas

El entorno disponible es Linux x86_64. No fue posible:

- compilar el objetivo completo mediante Xcode;
- abrir `ZEUVE.app` en macOS;
- verificar visualmente la posición y el ajuste automático de los tooltips en los bordes;
- comprobar manualmente la fluidez del hover con ratón o trackpad;
- probar VoiceOver, modo claro/oscuro y escalado de interfaz;
- medir la interacción mediante Instruments.

Estas comprobaciones deben realizarse en un Mac Apple Silicon con macOS 14 o posterior. La sintaxis, la estructura de interacción, la ausencia de recálculos analíticos y el resto del proyecto sí se validaron automáticamente.
