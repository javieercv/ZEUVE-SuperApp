# Resultados de pruebas — ZEUVE 0.5.3

Fecha: 3 de julio de 2026.

## Resumen

La versión 0.5.3 optimiza el Analizador de chats para evitar recálculos repetidos en SwiftUI. Las estadísticas se publican mediante instantáneas en caché, se calculan fuera del hilo principal, se cargan por pestaña y cancelan resultados obsoletos. La búsqueda utiliza una espera de 200 ms y conserva un índice reutilizable para paginación y contexto.

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

Las 30 pruebas del Analizador incluyen ahora:

- equivalencia entre la instantánea central y los filtros, fusiones y resumen;
- equivalencia de actividad, series, horas, días y mapa de calor con los cálculos directos;
- equivalencia de palabras, bigramas, emojis y frecuencias por participante tras agruparlos en una sola pasada;
- reutilización del índice de búsqueda al cambiar de página;
- conversación y tiempos de respuesta compartidos;
- un conjunto sintético de 35.000 mensajes para núcleo, actividad, participantes y búsqueda.

### Python y validaciones de scripts

Comando:

```bash
python3 -m unittest discover -s Tests/ScriptTests -p 'test_*.py' -v
```

Resultado:

- 18 pruebas ejecutadas.
- 18 pruebas superadas.
- 0 fallos.

Las validaciones específicas comprueban:

- presencia de instantáneas publicadas y tareas separadas del actor principal;
- propagación de cancelación al trabajador;
- espera de 200 ms para búsquedas nuevas;
- consumo de instantáneas desde las vistas, sin llamadas directas a cálculos pesados;
- cancelación de la búsqueda al abandonar su pestaña;
- invalidación selectiva de ajustes analíticos;
- reutilización directa de la colección cuando no existen filtros;
- cálculo de calendario solo cuando hay filtros de día u hora;
- recorrido conjunto de actividad y recorrido conjunto de palabras y emojis;
- reutilización de expresiones regulares compiladas.

## Compilación

Se ejecutó:

```bash
swift build -c release --jobs 1
```

Resultado: compilación SwiftPM Release completada sin errores.

También se ejecutó `Scripts/verify_project.sh`, que volvió a lanzar las pruebas, validó manifiestos, versión, documentación, políticas de privacidad, ausencia de dependencias nuevas, sintaxis de vistas y regeneración del proyecto Xcode.

## Validación sintáctica de la interfaz

Se ejecutó `swiftc -frontend -parse` sobre todos los archivos Swift de `Sources/ZEUVEApp`.

Resultado: ningún error sintáctico.

## Comprobaciones de comportamiento interno

- Un cambio de filtros incrementa la revisión analítica, cancela las tareas anteriores y conserva la última instantánea válida hasta publicar la nueva.
- Actividad, Participantes, Palabras, Conversaciones, Respuestas y Comparación solo programan su cálculo al abrir la pestaña correspondiente.
- Las revisiones impiden que una tarea antigua sustituya datos pertenecientes a un estado más reciente.
- La búsqueda conserva el resultado anterior mientras procesa una consulta nueva y reutiliza el índice cuando solo cambian página, tamaño o contexto.
- Salir de Búsqueda cancela su tarea y apaga el indicador.
- Cambiar palabras vacías, multimedia, umbral de conversación o ventana de respuesta invalida únicamente los resultados relacionados.
- Sin filtros activos no se crea una segunda colección de mensajes filtrados.
- Actividad, horas, días y mapa de calor se generan en una única pasada.
- Palabras, bigramas, emojis, frecuencias por participante y tipos de contenido se generan en una única pasada.

## Integridad y privacidad

- No se utilizaron chats reales para las pruebas permanentes de rendimiento.
- El caso grande utiliza mensajes sintéticos generados en memoria.
- No se añadieron dependencias, Internet, APIs, telemetría ni servicios externos.
- No se modificaron los módulos Organizador o Descargador fuera de los archivos comunes de versión y documentación.
- El ZIP original 0.5.2 y los Markdown originales se comprobaron mediante SHA-256 antes y después del trabajo.

## Pruebas no realizadas

El entorno disponible es Linux x86_64. No fue posible:

- compilar el objetivo completo mediante Xcode;
- abrir `ZEUVE.app` en macOS;
- medir con Instruments el hilo principal, CPU y memoria;
- comprobar manualmente la fluidez real de pestañas, filtros, búsqueda y desplazamiento;
- verificar visualmente los indicadores de actualización;
- probar VoiceOver, modo claro/oscuro, Charts y popovers en macOS.

Estas comprobaciones deben realizarse en un Mac Apple Silicon con macOS 14 o posterior. Las pruebas realizadas demuestran equivalencia lógica y ausencia de recálculos pesados en las vistas, pero no sustituyen una medición manual del rendimiento de la aplicación empaquetada.
