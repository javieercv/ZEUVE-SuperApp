# Analizador de chats 0.1.6 — ZEUVE 0.20.3.0

## Identidad

- Nombre visible: `Analizador de chats`.
- Identificador: `com.zeuve.chat-analyzer`.
- Versión del módulo: `0.1.6`.
- ZEUVE mínimo declarado: `0.5.0`.
- Tecnología: Swift 6 y SwiftUI.
- Modo: módulo oficial `builtIn`.
- Plataforma: macOS 14 o posterior, Apple Silicon ARM64.
- Permiso declarado: lectura de archivos seleccionados por el usuario.
- Red: no declarada y no utilizada.

## Objetivo

El módulo analiza localmente conversaciones exportadas de WhatsApp e Instagram. Los archivos originales se abren en lectura, los adjuntos no se decodifican y los mensajes no se guardan de forma permanente. Un análisis puede combinar un chat lógico de WhatsApp y una conversación de Instagram.

## Entradas

### Modo simple

- WhatsApp: ZIP original o TXT exportado directamente.
- Instagram: ZIP completo descargado desde Meta o ZIP que contiene directamente una sola conversación.
- Ambas plataformas: cualquiera de los ZIP anteriores y TXT de WhatsApp.

### Modo avanzado

- Las mismas entradas del modo simple.
- Uno o varios `message_N.html` de una conversación de Instagram.
- Carpeta descomprimida de una exportación de Instagram.

El cuadro de arrastrar y soltar, su explicación y el selector nativo de macOS cambian según se elija WhatsApp, Instagram o Ambas plataformas. Los elementos duplicados se rechazan por su URL normalizada. La selección muestra nombre, tamaño, tipo y plataforma estimada.

## WhatsApp

El lector enumera las entradas del ZIP mediante `libarchive` sin extraerlo por completo. Localiza los TXT candidatos por contenido, no únicamente por el nombre `_chat.txt`. Para detectarlos lee solo un prefijo real de hasta 256 KB; ese tamaño no limita el archivo completo. Si hay varios candidatos válidos, la interfaz solicita uno y, si solo existe uno, queda seleccionado automáticamente.

El parser admite:

- años de dos o cuatro cifras;
- día y mes de una o dos cifras;
- reloj de 12 o 24 horas;
- segundos opcionales;
- cabeceras con y sin corchetes;
- guiones y separadores habituales;
- BOM y caracteres invisibles necesarios para reconocer la cabecera;
- mensajes multilínea;
- nombres con espacios y texto con dos puntos;
- mensajes del sistema;
- marcadores de multimedia, llamadas, ubicaciones, contactos, eliminados y enlaces.

Las referencias a adjuntos se contrastan con el catálogo del ZIP. Se registran adjuntos existentes, faltantes y no referenciados sin abrir imágenes, vídeos, audios o documentos. Si se aporta únicamente el TXT, los adjuntos se indican como **no comprobados**, porque no es posible saber si existen; no se presentan como faltantes. Los nombres de sticker exportados por WhatsApp se reconocen antes de aplicar la clasificación general de imágenes WEBP.

El TXT se procesa progresivamente por bloques y líneas. Por defecto no existe un tamaño máximo para el archivo de conversación. El usuario puede establecer uno desde Ajustes; si se supera, se rechaza el archivo completo sin producir un análisis parcial.

## Instagram

La importación se divide en dos fases.

### Catalogación

En una exportación completa se buscan índices y rutas de mensajes bajo estructuras equivalentes a:

- `messages/inbox/`;
- `messages/message_requests/`;
- `messages/broadcast/`;
- conversaciones secretas cuando existan.

También se admite un ZIP cuya raíz contiene directamente la carpeta de una o varias conversaciones con `message_1.html`. Se ignoran `__MACOSX`, `.DS_Store`, archivos `._*` y las demás secciones personales de Meta. Si no hay índices, el catálogo se construye exclusivamente desde carpetas que contienen páginas `message_N.html` válidas.

Cada conversación se identifica mediante categoría y ruta normalizada. El nombre visible no es una clave única. El selector muestra nombre, categoría, páginas y una indicación adicional cuando existen nombres duplicados. Si el catálogo contiene una sola conversación, se selecciona automáticamente; el análisis no comienza hasta que el usuario lo inicia.

### Análisis

Tras seleccionar una conversación se procesan únicamente sus páginas `message_N.html`. En los ZIP individuales, las rutas que todavía apuntan a la estructura completa de Meta se reubican de forma segura hacia la carpeta realmente presente, de modo que fotos, vídeos y audios existentes puedan verificarse. El parser HTML propio construye un árbol tolerante y combina estructura, clases conocidas, jerarquía y validación de campos. Si no reconoce mensajes en un HTML no vacío, genera una advertencia comprensible.

Las páginas se ordenan inicialmente por número y los mensajes se ordenan finalmente por fecha, página y posición estable de origen.

## Fechas y zona horaria

Instagram admite meses españoles e ingleses, formatos numéricos, 12 o 24 horas y segundos opcionales. Las fechas numéricas ambiguas se marcan y se interpretan según el orden elegido.

Estrategias disponibles:

- California → España;
- UTC → España;
- ya está en horario de España;
- no convertir la hora.

Se utilizan zonas del sistema (`America/Los_Angeles` y `Europe/Madrid`) para respetar horario de verano e invierno.

## Modelo normalizado

Ambos importadores producen `NormalizedMessage`, con:

- identificador estable;
- conversación;
- fecha normalizada y texto original de fecha;
- estrategia horaria;
- autor visible y autor original;
- texto;
- plataforma y tipo de contenido;
- archivo, página y posición de origen;
- categoría;
- indicadores de sistema y fecha dudosa;
- referencia relativa mínima de adjunto.

La deduplicación es conservadora. Dos mensajes idénticos enviados en el mismo segundo se conservan cuando sus posiciones de origen son distintas.

## Resultados

La navegación interna incluye:

1. Resumen.
2. Actividad.
3. Participantes y perfiles.
4. Palabras y emojis.
5. Búsqueda.
6. Conversaciones.
7. Tiempos de respuesta.
8. Comparación.
9. Fusiones.

Los filtros globales incluyen fechas, participantes, plataforma, tipo, día de la semana y horario. Los intervalos horarios pueden atravesar la medianoche.

Los gráficos nativos muestran evolución, distribución horaria, días de la semana, participantes, plataformas y mapa de calor. Las vistas incluyen una descripción textual accesible de los datos principales.

Todos los gráficos son interactivos mediante hover. Las líneas muestran una guía vertical, resaltan los puntos del periodo más cercano y presentan la fecha o intervalo exacto. Las barras resaltan la categoría activa. El mapa de calor resalta su celda y muestra día, hora y número de mensajes. En Comparación se muestran las dos personas y el total conjunto. El tooltip sigue la posición del cursor con una separación visual, se mueve al lado opuesto cuando se acerca a un borde y se limita al área visible para evitar recortes. Desaparece al salir del gráfico y no se puede fijar con clic en esta versión.

La capa de interacción usa solo las series ya incluidas en la instantánea de la pestaña. Mover el cursor no ejecuta filtros, búsquedas, conversaciones ni estadísticas sobre la colección de mensajes. La fecha más cercana se localiza mediante búsqueda binaria y los estados de hover son locales y temporales.

Cada una de las nueve pestañas muestra un icono `info.circle` junto a su título. Las métricas, gráficos, opciones y columnas no evidentes disponen además de ayuda específica que explica qué mide el dato, cómo se calcula, qué incluye, qué excluye, cómo le afectan los filtros y qué limitaciones de interpretación existen. El mismo componente se utiliza en modo claro y oscuro y expone etiquetas para teclado y VoiceOver.

Desde cualquier resultado existen dos acciones diferenciadas:

- `Analizar otro chat`: cierra la sesión y sus temporales, limpia las fuentes y muestra inmediatamente la pantalla inicial vacía.
- `Cerrar análisis`: cierra la sesión y sus temporales, conserva las fuentes seleccionadas y muestra inmediatamente la pantalla inicial preparada para repetir el análisis.

La vista que alterna entre importación y resultados observa directamente el estado del Analizador, por lo que no es necesario cambiar de módulo para actualizarla.

## Arquitectura de rendimiento

El almacenamiento temporal SQLite es la fuente principal de los mensajes durante la sesión:

- WhatsApp entrega mensajes por lotes e Instagram procesa las páginas de la conversación de forma incremental.
- `TemporaryChatStore` inserta con deduplicación conservadora global y materializa una cronología estable indexada sin construir primero una colección completa equivalente en memoria.
- `ChatStoreCoreAnalyticsSnapshot` conserva únicamente conteos, participantes, fechas y resumen necesarios para la interfaz.
- Actividad, participantes, palabras, conversaciones, respuestas, comparación y búsqueda recorren SQLite por bloques mediante `ChatStoreAnalytics` y publican agregados o páginas compactas.
- Los cálculos se ejecutan mediante tareas separadas del actor principal. Cada cambio relevante incrementa una revisión; un resultado antiguo se descarta si ya no corresponde al estado actual.
- La cancelación se propaga a la tarea de trabajo y se comprueba tanto en los recorridos del store como durante la lectura prolongada de libarchive.
- El resultado válido anterior permanece visible mientras se calcula el siguiente. La barra superior puede mostrar `Actualizando estadísticas…` o `Buscando…` sin bloquear la navegación.

Los filtros esperan 120 ms para agrupar cambios rápidos y la búsqueda espera 200 ms desde la última edición. Las analíticas usan bases SQLite auxiliares temporales cuando una frecuencia, conversación o distribución podría crecer de forma proporcional al chat. La API `allMessages()` se conserva únicamente como compatibilidad controlada para pruebas y utilidades pequeñas; la ruta normal de sesión y el ViewModel no la utilizan.

## Búsqueda

La búsqueda admite frase exacta, todas las palabras o cualquiera de ellas, mayúsculas, palabras completas, tildes, contexto de 1, 3 o 5 mensajes y paginación de 25, 50 o 100 resultados. El contexto se toma de la cronología original y no atraviesa pausas superiores a seis horas. Las consultas nunca se guardan en historial o registros.

## Conversaciones y respuestas

Una conversación es una agrupación temporal. Una pausa exactamente igual al umbral conserva el mismo grupo; una pausa superior inicia otro.

Los mensajes consecutivos del mismo participante forman un turno. El tiempo de respuesta se mide entre el final de un turno y el inicio del siguiente turno de otra persona. Puede limitarse a 1, 6, 12 o 24 horas, o no aplicar límite adicional dentro de la conversación.

Estas cifras son estimaciones temporales y no demuestran una respuesta directa, especialmente en grupos.

## Fusiones

Las fusiones de identidades:

- son temporales;
- conservan siempre el autor original;
- recalculan estadísticas, filtros, conversaciones, respuestas y comparaciones;
- pueden deshacerse o restablecerse;
- rechazan nombres vacíos, una sola persona y colisiones con participantes no fusionados.

No se guardan para futuros análisis.

## Almacenamiento y ciclo de vida

Cada operación crea una carpeta privada bajo el directorio temporal del sistema con un marcador de propiedad. Los mensajes normalizados se escriben incrementalmente en una base SQLite temporal que actúa como fuente principal de la sesión, con índices por fecha, autor, plataforma y tipo y una cronología estable. El resultado expuesto a la interfaz conserva metadatos y estadísticas compactas, no una copia completa obligatoria de los mensajes. La sesión elimina base, archivos auxiliares y carpeta al cerrar, cancelar o sustituir el análisis.

La limpieza solo elimina carpetas que contienen el marcador esperado. Los restos abandonados con más de 24 horas pueden limpiarse al iniciar el módulo.

## Historial y registros

El historial guarda únicamente:

- fuentes y plataformas;
- archivos y páginas procesados;
- número de mensajes y participantes;
- duración, estado y advertencias.

Nunca guarda mensajes, nombres, búsquedas, extractos, nombres de conversación, adjuntos o rutas completas.

Los registros locales contienen fases, conteos y códigos técnicos sanitizados. No se envían a Internet.

## Seguridad ZIP

El lector rechaza:

- rutas absolutas y escapes `..`;
- enlaces simbólicos;
- archivos cifrados;
- entradas duplicadas;
- ZIP malformados o truncados;
- número de entradas, tamaño total del ZIP, tamaños declarados o relaciones de compresión superiores a los límites estructurales absolutos.

Los límites blandos del contenedor muestran advertencias y las protecciones estructurales absolutas no se pueden desactivar desde una operación. Son independientes del límite opcional del archivo de conversación, que por defecto está desactivado.

## Progreso y cancelación

`OperationCoordinator` mantiene una única operación pesada. Las fases publicadas incluyen validación, inspección, importación, normalización, deduplicación, almacenamiento y finalización. La cancelación es cooperativa, cierra recursos, elimina temporales propios, libera el coordinador y no presenta resultados parciales como completos.

## Ajustes

Los valores persistentes solo se administran desde `Ajustes > Analizador de chats`:

- zona horaria;
- orden de fechas numéricas;
- multimedia y categorías configurables;
- palabras vacías;
- granularidad;
- umbral de conversación;
- ventana de respuesta;
- relación entre filtros y conversaciones;
- resultados por página;
- límite opcional por archivo de conversación, desactivado por defecto;
- límites de seguridad visibles del contenedor ZIP.

Los valores se copian a una operación nueva. Cambiar los predeterminados no modifica una operación ya preparada o un análisis cargado.

## Límites conocidos

- Los formatos de exportación pueden cambiar y requerir adaptar los parsers.
- La zona horaria original de Meta no siempre puede deducirse automáticamente.
- Los tiempos de respuesta son estimaciones.
- La interfaz macOS, VoiceOver y el objetivo Xcode deben comprobarse en un Mac Apple Silicon.
- La arquitectura evita conservar de forma obligatoria una segunda colección completa de mensajes en memoria, pero la interfaz real con cientos de miles o millones de mensajes todavía debe medirse en un Mac Apple Silicon para cuantificar memoria, latencia, I/O y experiencia visual bajo carga extrema.

## Búsqueda paginada respaldada por SQLite — 0.12.4

La búsqueda conserva las opciones aprobadas de frase, palabras, mayúsculas, diacríticos, palabra completa, contexto y tamaño de página, pero ya no necesita una representación textual global de toda la sesión. Recorre `TemporaryChatStore` por lotes, conserva únicamente las coincidencias de la página solicitada y obtiene el contexto desde la cronología paginada. Las consultas y extractos siguen excluidos de historial y registros.

## Fallo exclusivo de historial

El análisis completado no se invalida si falla únicamente su registro en el historial local. La sesión y los resultados permanecen disponibles, se muestra un aviso y el registro técnico del fallo se limita al tipo de error, sin mensajes, participantes, consultas, rutas ni contenido de las conversaciones. `OperationCoordinator` se libera igualmente.

## Organización interna de fuentes — Fase 4

La interfaz de resultados se organiza en `Sources/ZEUVEApp/ChatAnalyzer/Results`: el archivo `ChatAnalyzerResultsView.swift` conserva la coordinación de pestañas y cada sección visual vive en una fuente propia. Esta separación no cambia filtros, textos, gráficos, layouts ni temas de ayuda.

La API pública continúa expuesta mediante `ChatAnalytics`. Su implementación se distribuye en fuentes de modelos, núcleo, actividad, participantes, palabras, conversaciones, búsqueda, snapshots, soporte y tokenización. Las firmas públicas, algoritmos, caches, invalidación selectiva, ordenación y resultados permanecen iguales; la reorganización no añade recorridos ni cambia la política de cancelación.

`ChatAnalyzerViewModel` se revisó durante esta fase y se mantiene como coordinador único porque su estado privado, tareas y cancelación forman un ciclo cohesionado. No se fragmenta únicamente para reducir líneas.
