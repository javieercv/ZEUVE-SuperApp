# Resultados de pruebas — ZEUVE 0.5.5

Fecha: 3 de julio de 2026.

## Resumen

La versión 0.5.5 corrige la posición de los tooltips interactivos del Analizador de chats. El cuadro ya no se fija en la parte superior del gráfico: conserva la coordenada local del cursor, aparece junto a él, cambia de lado cuando se aproxima a un borde y limita su posición al área visible. La guía, punto, barra o celda continúan asociados al dato exacto y la interacción sigue utilizando únicamente las instantáneas en caché.

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

Se mantiene la cobertura completa del Analizador para importación, normalización, filtros, fusiones, actividad, participantes, palabras, conversaciones, respuestas, comparación, búsqueda, caché y el chat sintético de 35.000 mensajes.

### Python y validaciones de scripts

Comando:

```bash
python3 -m unittest discover -s Tests/ScriptTests -p 'test_*.py' -v
```

Resultado:

- 19 pruebas ejecutadas.
- 19 pruebas superadas.
- 0 fallos.

La regresión de interfaz comprueba:

- existencia del componente común `CursorFollowingTooltip`;
- conservación de la coordenada `cursorLocation` en gráficos temporales y categóricos;
- posicionamiento al lado derecho y por encima del cursor en condiciones normales;
- cambio al lado izquierdo cuando falta espacio horizontal;
- cambio por debajo cuando falta espacio superior;
- limitación de la posición dentro del ancho y alto disponibles;
- uso del mismo sistema en los ocho gráficos Swift Charts y el mapa de calor;
- ausencia de anotaciones fijadas mediante `annotation(position: .top)`;
- ausencia de cálculos analíticos pesados en la capa de interacción.

## Compilación

Se ejecutó:

```bash
swift build -c release --jobs 1
```

Resultado: compilación SwiftPM Release completada sin errores.

También se ejecutó `Scripts/verify_project.sh`, que validó versiones, manifiestos, documentación, privacidad, ausencia de dependencias nuevas, pruebas automáticas, sintaxis de la interfaz y regeneración del proyecto Xcode.

## Validación sintáctica de la interfaz

Se ejecutó `swiftc -frontend -parse` sobre los 17 archivos Swift de `Sources/ZEUVEApp`, incluidos:

- `InteractiveChartSupport.swift`;
- `ChatAnalyzerResultsView.swift`.

Resultado: ningún error sintáctico.

## Comprobaciones específicas

- Evolución temporal: el tooltip sigue el cursor mientras la guía vertical y los puntos permanecen en el periodo seleccionado.
- Barras por hora y día: el tooltip se mueve junto al cursor y la categoría resaltada no cambia por la posición del cuadro.
- Evolución mensual: el punto exacto permanece seleccionado mientras el cuadro se recoloca.
- Distribución de respuestas: el intervalo activo mantiene su valor y el tooltip no queda anclado arriba.
- Comparación temporal, por hora y por día: se conservan ambas series y el total conjunto.
- Mapa de calor: la posición local de cada celda se transforma al espacio común del contenido antes de situar el tooltip.
- Los estados de posición se limpian al salir del gráfico, cambiar de granularidad, participante, comparación o pestaña.
- Mover el cursor no invalida filtros ni instantáneas y no vuelve a recorrer los mensajes.

## Integridad y privacidad

- No se añadieron dependencias, Internet, APIs, telemetría ni servicios externos.
- No se modificaron los cálculos estadísticos ni los archivos del usuario.
- No se incorporaron chats reales al proyecto, las pruebas o la entrega.
- El ZIP original 0.5.4 conserva su SHA-256: `4faa621e78a1a17dd6ca26bd80c1d61bf5f9b2f1404987a81ec70ff02b7ead71`.

## Limitaciones

El entorno de validación es Linux x86_64. No se pudo abrir la aplicación completa en macOS ni comprobar visualmente el seguimiento real del cursor, el cambio de lado en las cuatro esquinas, VoiceOver o los modos claro y oscuro. Estas comprobaciones deben realizarse en un Mac Apple Silicon.
