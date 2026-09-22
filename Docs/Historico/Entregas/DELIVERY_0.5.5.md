# Entrega — ZEUVE 0.5.5

Fecha: 3 de julio de 2026.

## Resumen

ZEUVE 0.5.5 corrige los tooltips de los gráficos del Analizador para que sigan la posición del cursor y permanezcan legibles dentro del área visible.

## Estado

Completado en el proyecto fuente.

- Versión anterior: 0.5.4, build 17.
- Versión nueva: 0.5.5, build 18.
- Analizador de chats: 0.1.4 → 0.1.5.

## Cambios funcionales

### Posicionamiento del tooltip

- El cuadro deja de estar asociado a una anotación superior de Swift Charts.
- La capa de hover conserva la coordenada local real del cursor además del dato seleccionado.
- El tooltip aparece junto al puntero con una separación suficiente para no tapar el punto o barra.
- Normalmente se coloca arriba y a la derecha.
- Cerca del borde derecho se desplaza a la izquierda.
- Cerca del borde superior se desplaza por debajo.
- Su centro se limita al ancho y alto disponibles para evitar recortes en el resto de bordes.

### Gráficos afectados

La corrección se aplica a:

- evolución temporal de Actividad;
- actividad por hora;
- actividad por día;
- mapa de calor;
- evolución mensual del participante;
- distribución de tiempos de respuesta;
- evolución temporal comparada;
- comparación por hora;
- comparación por día.

### Rendimiento

- La interacción continúa usando exclusivamente las series ya incluidas en las instantáneas de la pestaña.
- Mover el cursor solo actualiza estados efímeros de selección y posición.
- No se recalculan estadísticas, filtros, búsquedas, conversaciones ni respuestas.
- El tamaño del tooltip se mide dentro de la propia superposición para calcular una posición segura.

## Arquitectura

`InteractiveChartSupport.swift` incorpora:

- `CursorFollowingTooltip`;
- medición reutilizable del tamaño del cuadro;
- cálculo de posición con separación, inversión y límites;
- bindings de `cursorLocation` en los seguidores temporales y categóricos;
- modificador común `chartCursorTooltip`.

`ChatAnalyzerResultsView.swift` elimina las anotaciones superiores y conecta cada gráfico con su estado de posición. El mapa de calor convierte las coordenadas de la celda al espacio común del contenido.

## Archivos principales modificados

- `Sources/ZEUVEApp/Components/InteractiveChartSupport.swift`.
- `Sources/ZEUVEApp/ChatAnalyzer/ChatAnalyzerResultsView.swift`.
- `Tests/ScriptTests/test_chat_analyzer_ui_rules.py`.
- `Scripts/verify_project.sh`.
- `PROJECT_DECISIONS.md`.
- `CHANGELOG.md`.
- `README.md`.
- `VERSION`.
- manifiesto del Analizador, proyecto Xcode y script de generación.
- documentación de arquitectura, alcance, pruebas, compilación y Analizador.

## Pruebas

- 101 pruebas Swift superadas.
- 19 pruebas Python superadas.
- Compilación SwiftPM Release completada.
- Análisis sintáctico de los 17 archivos Swift de la aplicación completado.
- `Scripts/verify_project.sh` completado.
- Proyecto Xcode regenerado para 0.5.5, build 18.

Los detalles se encuentran en `Docs/TEST_RESULTS_0.5.5.md`.

## Dependencias, privacidad y alcance

- Sin dependencias nuevas.
- Sin Internet ni APIs nuevas.
- Sin cambios funcionales en Organizador o Descargador.
- Sin modificación de archivos originales del usuario.
- Sin chats reales dentro del proyecto o la entrega.
- Sin cambios en los resultados estadísticos.

## Limitaciones

No se ha compilado ni abierto la aplicación completa con Xcode porque el entorno disponible no es macOS Apple Silicon. Debe comprobarse manualmente en un Mac el movimiento visual del tooltip, su comportamiento en las cuatro esquinas, la fluidez, VoiceOver y los modos claro y oscuro.
