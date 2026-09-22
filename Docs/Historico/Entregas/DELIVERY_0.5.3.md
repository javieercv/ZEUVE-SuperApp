# Entrega — ZEUVE 0.5.3

Fecha: 3 de julio de 2026.

## Resumen

ZEUVE 0.5.3 optimiza el Analizador de chats para que los cambios de pestaña, filtros, búsqueda y ajustes no ejecuten repetidamente estadísticas pesadas en el hilo de la interfaz.

## Estado

Completado en el proyecto fuente.

- Versión anterior: 0.5.2, build 15.
- Versión nueva: 0.5.3, build 16.
- Analizador de chats: 0.1.2 → 0.1.3.

## Cambios funcionales

### Instantáneas y caché

Se añadieron instantáneas inmutables para:

- cronología efectiva, filtros y resumen;
- actividad temporal;
- participantes y perfiles;
- palabras, bigramas y emojis;
- conversaciones y tiempos de respuesta;
- comparación;
- índice y resultados de búsqueda.

Las vistas consumen estas instantáneas y ya no recorren el chat desde propiedades calculadas cada vez que SwiftUI actualiza el cuerpo.

### Segundo plano y cancelación

- Los cálculos pesados se ejecutan en tareas separadas del actor principal.
- Cada estado analítico recibe una revisión interna.
- Cambiar filtros, fusiones, granularidad, participantes, ajustes o consulta cancela el trabajo anterior.
- Un resultado solo se publica si su revisión todavía coincide con el estado actual.
- El último resultado completo permanece visible durante la actualización.
- La barra superior muestra indicadores discretos sin bloquear la navegación.

### Carga por pestaña

- Resumen utiliza la instantánea central.
- Actividad, Participantes, Palabras, Conversaciones, Respuestas y Comparación se calculan al abrirse.
- Volver a una pestaña reutiliza su caché si no han cambiado sus entradas.
- Conversaciones y Respuestas comparten una misma instantánea base.
- Comparación reutiliza conversaciones y respuestas cuando ya están disponibles.

### Búsqueda

- Espera de 200 ms tras la última modificación de la consulta.
- Cancelación inmediata de búsquedas anteriores.
- Expresiones regulares compiladas una vez por consulta.
- Índice ligero de coincidencias reutilizado al cambiar página, tamaño de página o mensajes de contexto.
- Salir de la pestaña cancela la tarea y retira el indicador.

### Pasadas y asignaciones reducidas

- Sin filtros se reutiliza la colección normalizada.
- El calendario solo se consulta cuando existe un filtro por día u hora.
- Actividad, horas, días y mapa de calor se calculan en una sola pasada.
- Palabras, bigramas, emojis y frecuencias por persona se calculan en una sola pasada.
- Las series temporales ya no construyen claves de texto para cada mensaje.
- Las expresiones regulares comunes se reutilizan.
- Los ajustes invalidan solo las secciones que dependen de ellos.

## Archivos principales modificados

- `Sources/ChatAnalyzerModule/Analysis/ChatAnalytics.swift`
- `Sources/ChatAnalyzerModule/Analysis/ChatAnalyticsCache.swift` — nuevo.
- `Sources/ChatAnalyzerModule/Import/ChatParsingUtilities.swift`
- `Sources/ZEUVEApp/ChatAnalyzer/ChatAnalyzerViewModel.swift`
- `Sources/ZEUVEApp/ChatAnalyzer/ChatAnalyzerResultsView.swift`
- `Tests/ChatAnalyzerModuleTests/ChatAnalyzerTests.swift`
- `Tests/ScriptTests/test_chat_analyzer_ui_rules.py`
- `PROJECT_DECISIONS.md`
- `CHANGELOG.md`
- `README.md`
- `VERSION`
- manifiesto del Analizador, proyecto Xcode, scripts de generación y verificación;
- documentación vigente de arquitectura, alcance, compilación, pruebas y Analizador.

## Dependencias, privacidad y alcance

- Sin dependencias nuevas.
- Sin Internet ni APIs nuevas.
- Sin cambios funcionales en Organizador o Descargador.
- Sin modificación de archivos originales del usuario.
- Sin chats reales dentro del proyecto o de la entrega.
- Sin cambio visual estructural; solo indicadores discretos de cálculo y búsqueda.

## Pruebas

- 101 pruebas Swift superadas.
- 18 pruebas Python superadas.
- Caso sintético de 35.000 mensajes superado.
- Equivalencia entre instantáneas optimizadas y cálculos directos verificada.
- Análisis sintáctico de vistas superado.
- Compilación SwiftPM Release completada.
- `Scripts/verify_project.sh` completado.
- Proyecto Xcode regenerado para 0.5.3, build 16.

Los detalles se encuentran en `Docs/TEST_RESULTS_0.5.3.md`.

## Limitaciones

No se ha compilado ni abierto la aplicación completa con Xcode porque el entorno disponible no es macOS Apple Silicon. La mejora arquitectónica y los resultados se han validado automáticamente, pero la fluidez visual final, el consumo de memoria y el comportamiento de Charts deben medirse manualmente en un Mac con el chat real.
