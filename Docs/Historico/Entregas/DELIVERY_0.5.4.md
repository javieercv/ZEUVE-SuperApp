# Entrega — ZEUVE 0.5.4

Fecha: 3 de julio de 2026.

## Resumen

ZEUVE 0.5.4 añade tooltips interactivos por hover a todos los gráficos del Analizador de chats, con resaltado del dato exacto y desglose completo en comparaciones.

## Estado

Completado en el proyecto fuente.

- Versión anterior: 0.5.3, build 16.
- Versión nueva: 0.5.4, build 17.
- Analizador de chats: 0.1.3 → 0.1.4.

## Cambios funcionales

### Gráficos temporales

- Al mover el cursor se selecciona el periodo representado más cercano.
- Se muestra una guía vertical y se resaltan los puntos de las series visibles.
- El tooltip presenta la fecha o intervalo exacto y los valores asociados.
- Actividad incluye Total, WhatsApp e Instagram cuando corresponda.
- Comparación incluye ambas personas y el total conjunto.

### Gráficos de barras

- La categoría activa permanece a opacidad completa y las demás se atenúan.
- El tooltip muestra hora, día o intervalo y su valor exacto.
- En Comparación aparecen las dos personas y el total conjunto.

### Mapa de calor

- La celda bajo el cursor queda delimitada visualmente.
- El tooltip muestra día, franja horaria y número de mensajes.

### Interacción y rendimiento

- El tooltip aparece solo mediante hover; no se fija con clic.
- La interacción usa las series ya almacenadas en las instantáneas de la pestaña.
- No se recalculan filtros, búsquedas, conversaciones ni estadísticas.
- Las fechas se localizan con búsqueda binaria.
- Los estados de hover se limpian al cambiar de pestaña, persona o granularidad.

## Arquitectura

Se añadió `Sources/ZEUVEApp/Components/InteractiveChartSupport.swift`, que contiene:

- `ChartTooltipCard`;
- filas de tooltip comunes;
- seguimiento de fechas con `ChartProxy`;
- seguimiento de categorías;
- formateadores españoles de fechas, periodos y horas.

`ChatAnalyzerResultsView.swift` integra esta capa en los ocho gráficos Swift Charts y en el mapa de calor personalizado.

## Archivos principales modificados

- `Sources/ZEUVEApp/Components/InteractiveChartSupport.swift` — nuevo.
- `Sources/ZEUVEApp/ChatAnalyzer/ChatAnalyzerResultsView.swift`.
- `Tests/ScriptTests/test_chat_analyzer_ui_rules.py`.
- `Scripts/verify_project.sh`.
- `PROJECT_DECISIONS.md`.
- `CHANGELOG.md`.
- `README.md`.
- `VERSION`.
- manifiesto del Analizador, proyecto Xcode y script de generación;
- documentación de arquitectura, alcance, pruebas, compilación y Analizador.

## Dependencias, privacidad y alcance

- Sin dependencias nuevas.
- Sin Internet ni APIs nuevas.
- Sin cambios funcionales en Organizador o Descargador.
- Sin modificación de archivos originales del usuario.
- Sin chats reales dentro del proyecto o de la entrega.
- Sin cambios en los cálculos estadísticos, salvo la generación lineal del histograma de respuestas equivalente al resultado anterior.

## Pruebas

- 101 pruebas Swift superadas.
- 19 pruebas Python superadas.
- Análisis sintáctico de todas las vistas superado.
- Compilación SwiftPM Release completada.
- `Scripts/verify_project.sh` completado.
- Proyecto Xcode regenerado para 0.5.4, build 17.

Los detalles se encuentran en `Docs/TEST_RESULTS_0.5.4.md`.

## Limitaciones

No se ha compilado ni abierto la aplicación completa con Xcode porque el entorno disponible no es macOS Apple Silicon. Debe comprobarse manualmente en un Mac la apariencia final, el posicionamiento de los tooltips en los extremos, la fluidez del cursor, VoiceOver y los modos claro y oscuro.
