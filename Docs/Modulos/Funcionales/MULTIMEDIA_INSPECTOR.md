# Inspector multimedia — ZEUVE 0.19.0.0

## Identidad y alcance

`MultimediaInspectorModule` es el sexto módulo oficial built-in de ZEUVE.

- Nombre visible: **Inspector multimedia**.
- Identificador: `com.zeuve.multimedia-inspector`.
- Versión del módulo: `0.7.0`.
- Versión mínima de ZEUVE: `0.13.0`.
- Icono: `waveform.path.ecg`.
- Atajo: `⌘6`.
- Red: **no utiliza ni solicita acceso a red**.

El módulo cubre inspección técnica, preview multimedia, análisis local, edición estructural segura, lotes y OCR revisable. No es un editor creativo, DAW ni conversor: montaje, recortes, transiciones, filtros, color grading y recodificación audiovisual permanecen fuera. El OCR bitmap local sí forma parte del módulo porque transforma una representación de subtítulos en un borrador textual revisable sin alterar la fuente.

## Estado consolidado 0.7.0

### Preview y transporte único

El preview no depende de `AVPlayer` como solución universal. ZEUVE conserva el reproductor de audio incremental existente y añade vídeo decodificado por FFmpeg. Ambos obedecen al mismo transporte/playhead: play, pause, seek, velocidad, cambio de audio/vídeo/subtítulo y saltos conservan la posición. En archivos con audio, el audio actúa como reloj principal; en vídeo sin audio, el timestamp de frames mantiene la sesión. Waveform, espectrograma, sonoridad, capítulos, silencios, clipping y anomalías consumen esa misma posición.

El vídeo aplica límites configurables de resolución, FPS y buffer dentro de hard caps no desactivables. Se procesa de forma incremental, se descartan frames obsoletos, las generaciones anteriores quedan invalidadas al cambiar de fuente y VideoToolbox se usa solo cuando resulta apropiado, con fallback a software. HDR puede previsualizarse como inspección, sin afirmar fidelidad de monitor de referencia.

Los subtítulos de texto se normalizan temporalmente para preview local y se dibujan sincronizados. ASS/SSA conserva texto y timing, pero los estilos avanzados no están garantizados porque el FFmpeg actual no incorpora libass. Los bitmap no sustituyen silenciosamente esta ruta: se identifican y pueden pasar al OCR revisable.

### Edición estructural de vídeo y carátulas

`MediaEditDraft` representa vídeo, audio y subtítulos. El usuario puede conservar, quitar, añadir y reordenar vídeo externo, editar metadata/dispositions compatibles y seleccionar la prioridad/default cuando el contenedor lo permita. Planner y validator rechazan cualquier operación audiovisual que necesite transcode. Las fuentes externas quedan fingerprintadas y el resultado se vuelve a inspeccionar con FFprobe antes de publicar.

`attached_pic` se modela como carátula, no como vídeo normal. Puede visualizarse/extraerse y, en contenedores/códecs compatibles por stream copy, añadirse, sustituirse o eliminarse. MKV conserva la semántica de attachments en vez de forzar `attached_pic`.

### Carpetas y edición estructural por lotes

El lote acepta archivos y carpetas. La enumeración de carpetas es ligera e incremental, permite subcarpetas, profundidad, ocultos, filtros y orden, deduplica de forma segura y nunca sigue symlinks. FFprobe se ejecuta después, cuando hace falta evaluar cada elemento.

Las reglas estructurales son semánticas: seleccionan streams por tipo, codec, idioma, título y dispositions, y aplican acciones como quitar, cambiar idioma/título/default/forced. No se basan en “pista 1/pista 2” ni emparejan automáticamente archivos externos por nombre. Antes de ejecutar se genera un preflight individual con `aplicable`, `aplicable con advertencias`, `incompatible` o `sin cambios`; tras confirmación, cada archivo se procesa secuencialmente mediante el mismo servicio seguro de edición.

### Análisis avanzado

El análisis de fuente calcula ancho de banda efectivo, energía relativa por bandas, persistencia temporal y patrones espectrales. Devuelve indicios graduados y evidencias legibles; no etiqueta un lossless como falso por un único cutoff. Las anomalías espectrales incluyen intervalo temporal, intensidad descriptiva y motivo, y pueden mostrarse sobre la timeline compartida. PCM y FFT intermedios no se persisten.

### OCR bitmap

PGS y otros formatos bitmap reconocidos pueden convertirse localmente en eventos/imágenes temporales y analizarse con Vision en macOS. El resultado es un `BitmapSubtitleOCRDraft`: texto, timing, confianza e inclusión son revisables antes de exportar SRT o añadir una nueva pista textual al borrador. La pista original nunca se sustituye automáticamente. VobSub/DVD queda condicionado a que el FFmpeg empaquetado pueda extraer correctamente sus eventos en el Mac objetivo.

### Favoritos, ajustes e informes

`favorites` se limita a presets de lote y conjuntos de reglas; no persiste rutas. Todas las preferencias persistentes nuevas viven en `MultimediaInspectorPreferences`/`SettingsRepository`: preview, subtítulos, análisis, OCR, carpetas, overlays e informes. Hard caps, protección del original, fingerprint, publicación, validación y privacidad no son configurables.

Los informes JSON usan schema `3`. Las nuevas secciones para vídeo, carátulas, análisis avanzado, resumen OCR y plan estructural son aditivas y pueden desactivarse desde Ajustes. Nunca incluyen rutas completas, fingerprints, IDs internos, PCM, frames ni texto OCR/subtítulos.

## Frontera con el Conversor universal

El Conversor universal sigue siendo responsable de cualquier transformación que cambie el contenido audiovisual: códec, resolución, FPS, bitrate, formato que requiera transcode o recodificación de audio/vídeo.

Inspector multimedia solo puede conservar vídeo y audio mediante **stream copy**. Si una combinación de pistas y contenedor exigiría recodificar vídeo o audio, el planner intenta otro contenedor editable compatible; si no existe una alternativa segura, la operación se bloquea y se remite al Conversor universal.

Los subtítulos son la única excepción aprobada: pueden convertirse de forma auxiliar cuando el contenedor lo exige, la política declara esa conversión como segura y el usuario la autoriza expresamente. En 0.13.0 se contempla, entre otros casos validados, `SRT/SubRip → mov_text` para MP4/MOV. No se realiza OCR ni conversión automática de PGS a texto.

## Flujo de seguridad y solo lectura

Todo archivo se abre siempre en modo inspección/solo lectura:

```text
archivo seleccionado o arrastrado
        ↓
FFprobe compartido
        ↓
modelo técnico
        ↓
Resumen / Pistas / Espectrograma / Metadatos
        ↓
[Editar] explícito
        ↓
MediaEditDraft
        ↓
revisión y Undo/Redo
        ↓
MediaEditValidator
        ↓
MediaEditPlanner
        ↓
MediaEditPlan inmutable
        ↓
FFmpegMediaEditCommandBuilder
        ↓
workspace temporal
        ↓
FFmpeg
        ↓
FFprobe + MultimediaResultValidator
        ↓
publicación segura de un archivo nuevo
```

Entrar en la pestaña Pistas no activa controles de modificación. Solo `Editar` crea un borrador. El original nunca se modifica durante la edición del draft.

## Undo / Redo

`MediaEditDraftHistory` conserva snapshots lógicos del borrador:

- `⌘Z`: deshacer;
- `⇧⌘Z`: rehacer;
- una acción nueva después de deshacer invalida la rama de redo;
- cambiar un `default` y desmarcar el anterior forma una única acción lógica;
- añadir, eliminar, reordenar, cambiar idioma/título y flags trabajan únicamente sobre el draft.

Undo/Redo no actúa nunca sobre archivos ya publicados.

Cancelar edición descarta el draft. Si contiene cambios se solicita confirmación. Abrir otro archivo con un borrador sucio también requiere confirmación y nunca persiste silenciosamente el borrador incompleto.

## FFprobe compartido en ZEUVEEngines

La inspección multimedia común reside en:

`Sources/ZEUVEEngines/MediaInspection/`

La capa contiene:

- `MediaInspectionService`;
- `MediaInspectionModels`;
- `MediaInspectionError`.

La secuencia es:

```text
archivo → FFprobe → JSON → parser Codable tolerante → MediaInspectionResult
```

No conoce SwiftUI, presets, publicación, historial ni decisiones de conversión.

El Conversor universal consume esta misma infraestructura. Su antiguo parser local de FFprobe se retiró únicamente después de migrar los consumidores y mantener las pruebas de regresión.

### Datos representados

El modelo común representa, cuando FFprobe los proporciona:

- contenedor, nombre largo, duración, tamaño, bitrate, inicio, tags, chapters y programs;
- streams de vídeo con códec, perfil, nivel, dimensiones, SAR/DAR, pixel format, bits, bitrate, FPS/racionales, time base, duración, frames declarados, field order, color, side data, rotación, HDR inferible, dispositions y tags;
- streams de audio con códec, perfil, bitrate, sample rate, sample format, bits, canales, layout, duración, idioma, título, dispositions y tags;
- subtítulos con códec, idioma, título, duración, default/forced, dispositions y tags;
- attached pictures, attachments, data streams y tipos desconocidos.

Los campos ausentes, `N/A`, racionales inválidos y metadata desconocida no provocan `fatalError`. Un resultado parcialmente informativo se conserva como parcial y la UI avisa sin inventar datos.

### Caché temporal

`MediaInspectionService` mantiene una caché exclusivamente en memoria durante la vida del servicio. La clave combina ruta canónica y `FileFingerprint` (tamaño y fecha de modificación). Si cambia el archivo cambia la clave. No se persiste metadata multimedia ni rutas en historial.

## Edición de pistas

### Vídeo

En 0.13.0 los streams de vídeo son solo lectura y deben preservarse. No se pueden añadir, eliminar, reordenar ni recodificar. Las attached pictures también se preservan y la validación final comprueba que no desaparezcan.

### Audio

En modo edición se permite:

- añadir una pista externa;
- eliminar;
- reordenar;
- idioma;
- título;
- flag `default`.

### Subtítulos

Se permite:

- añadir;
- eliminar;
- reordenar;
- idioma;
- título;
- `default`;
- `forced`;
- autorizar una conversión auxiliar compatible cuando el plan la necesite.

### Estructura editable y elementos protegidos

Los capítulos, attachments reales (`codec_type=attachment`) y el conjunto seguro de metadatos multimedia forman parte del mismo `MediaEditDraft` desde 0.17. Los capítulos se editan como marcadores de inicio; los attachments pueden añadirse, eliminarse, renombrarse/cambiar MIME y extraerse; los metadatos conocidos pueden modificarse sin convertir el Inspector en un editor arbitrario de tags.

Continúan protegidos y de solo lectura los streams de vídeo principales, `attached_pic`, data streams, programs y streams desconocidos. `FFmpegMediaEditCommandBuilder` parte de mappings explícitos, conserva vídeo/audio mediante `-c copy` y aplica únicamente las exclusiones, attachments, capítulos y metadatos que autoriza el plan. La validación final compara la estructura esperada con una nueva inspección FFprobe antes de publicar.

## Archivos externos y fingerprints

Al añadir audio o subtítulos se inspecciona el archivo externo con FFprobe. Los attachments externos se validan igualmente como archivos regulares y se fingerprintan antes de planificar. Si contiene una sola pista apropiada se utiliza; si contiene varias, la UI obliga a seleccionar una. No existe selección silenciosa en un caso ambiguo.

Cada entrada externa conserva un `FileFingerprint`. Antes de planificar/ejecutar se comprueba que el archivo sigue siendo regular, no es un symlink, existe y coincide con el fingerprint inspeccionado. El original se valida del mismo modo antes de la operación.

## Compatibilidad de contenedores

`MediaContainerCompatibilityRegistry` concentra las reglas; SwiftUI y el ViewModel no contienen tablas de compatibilidad.

Contenedores editables iniciales:

- MKV;
- MP4;
- MOV;
- WebM.

Otros formatos que FFprobe pueda inspeccionar se consideran **inspeccionables pero no editables** salvo ampliación aprobada.

La política devuelve una de estas decisiones por pista/contenedor:

- stream copy;
- conversión auxiliar de subtítulo;
- incompatible.

El planner intenta mantener el contenedor original. Si no cabe una pista de vídeo/audio por copia, busca otra alternativa compatible. Un cambio de contenedor aparece en la previsualización y el usuario lo confirma al ejecutar el plan revisado.

## Ejecución FFmpeg y protección del original

FFmpeg se ejecuta mediante `ExternalProcessRunner`, con ejecutable y argumentos separados. No se usa `/bin/sh`, comandos concatenados ni interpolación de shell.

El command builder aplica conceptualmente:

- mappings explícitos;
- `-c copy` global;
- únicamente un override `-c:s:N <codec>` para subtítulos cuya conversión haya sido autorizada;
- metadata de idioma/título y dispositions por stream;
- attachments del plan y metadata por stream/contenedor;
- capítulos del `MediaEditDraft` mediante FFmetadata temporal del workspace.

`Preservar metadatos` controla los tags no editados; los capítulos siguen siempre el draft y no desaparecen por desactivar esa preferencia.

El resultado se crea en `MultimediaWorkspace`, nunca sobre el original. Se rechaza un destino que, tras normalización y resolución de enlaces, represente al original o a otra entrada protegida. La publicación utiliza staging propio y nombres sin conflicto; nunca sobrescribe silenciosamente.

Antes del remux se comprueba espacio libre con margen conservador.

## Validación de resultado

`MultimediaResultValidator` no acepta simplemente `exitCode == 0`. Ejecuta FFprobe sobre el temporal y comprueba, entre otros puntos:

- archivo regular y no vacío;
- mismo número y códec de vídeos principales;
- preservación de attached pictures;
- número y orden de audios y subtítulos conforme al plan;
- códec esperado por cada pista;
- idioma, título, `default` y `forced` cuando corresponda;
- streams auxiliares y programs protegidos;
- capítulos conforme al plan;
- attachments conservados, eliminados o añadidos conforme al plan;
- metadatos editados y eliminados conforme al plan.

Solo un temporal validado puede pasar al publisher.

## Espectrograma

### Investigación técnica de Spek

Antes de implementar el motor se estudió la versión pública actual del repositorio oficial `alexkay/spek`, su README, manual y las piezas necesarias para comprender el pipeline. A fecha de diseño, el README publica **Spek 0.8.5 (2023-01-09)** y describe FFmpeg para decodificación y wxWidgets para GUI. El manual confirma controles para cambiar stream de audio, canal, función y tamaño de ventana DFT, límites de rango dinámico y guardado de imagen.

Se revisó el comportamiento conceptual del pipeline público para comprender:

- selección de stream y canal;
- decodificación incremental;
- normalización a muestras flotantes;
- tamaño DFT configurable;
- ventanas Hann, Hamming y Blackman–Harris;
- magnitud/potencia expresada en dB;
- procesamiento por bloques;
- separación entre lectura y trabajo;
- visualización y exportación.

**No se copió, tradujo ni portó código de Spek.** ZEUVE no enlaza Spek, wxWidgets ni componentes GPL. La implementación se escribió de forma independiente con las APIs ya aprobadas de ZEUVE y Accelerate/vDSP.

### Matriz de referencia clean-room

| Función observada en Spek | Equivalente de ZEUVE | Relación | Justificación |
| --- | --- | --- | --- |
| selección de audio stream | selector de pista dentro de audio/vídeo | adaptado | usa los índices obtenidos por el FFprobe compartido |
| selección de canal | mezcla o canal individual | mejorado | permite una vista de downmix además de canales concretos |
| DFT configurable | FFT sizes inyectados por `MultimediaInspectorPreferences` | adaptado | los valores no viven hardcodeados en SwiftUI |
| Hann/Hamming/Blackman–Harris | mismas funciones matemáticas estándar | equivalente conceptual | implementación propia, sin reutilizar expresión de código GPL |
| rango dinámico en dB | `SpectrogramDynamicRange` | adaptado | floor seguro, clipping explícito y rango configurable |
| decodificación incremental | FFmpeg → `pcm_f32le` → consumidor por chunks | adaptado | reutiliza `ExternalProcessRunner` y no enlaza libav directamente |
| imagen completa | columnas limitadas + compactación progresiva + Canvas nativo | mejorado para ZEUVE | evita PCM/FFT/bitmap completos en memoria para archivos largos |
| guardar espectrograma | exportación PNG segura e historial mínimo | adaptado | usa publisher y `OperationCoordinator` de ZEUVE |

### Pipeline propio

```text
archivo/pista
   ↓
FFmpeg seguro
   ↓
PCM float32 little-endian por stdout
   ↓
separación de canal o mezcla
   ↓
ventana
   ↓
Accelerate/vDSP DFT en macOS
   ↓
magnitud normalizada
   ↓
dB
   ↓
columnas espectrales acotadas
   ↓
Canvas nativo / exportador PNG
```

En plataformas de test donde Accelerate no existe se usa una DFT de referencia propia para poder validar matemáticamente el modelo; la aplicación objetivo macOS usa vDSP.

### Matemática y escalas

El límite superior de frecuencia se calcula siempre como:

`Nyquist = sampleRate / 2`

No existe un máximo fijo. Un archivo de 44,1 kHz llega a 22,05 kHz; 48 kHz a 24 kHz; 96 kHz a 48 kHz.

Las muestras se multiplican por la ventana, se transforman y la amplitud se normaliza por la ganancia coherente de la ventana. Los bins interiores usan el factor de espectro unilateral. Se aplica un floor lineal derivado del mínimo de dB para evitar `log(0)` y después `20·log10(amplitud)`, con clipping al rango dinámico seleccionado.

El hop de análisis es 50 % del FFT size. Los bloques incompletos finales se completan con ceros. Para evitar crecimiento sin límite, cuando el número de columnas supera dos veces el máximo configurado se compactan pares de columnas y se conserva una representación temporal acotada.

### Controles 0.13.0

- pista de audio;
- mezcla o canal individual;
- ventana;
- FFT size;
- mínimo del rango dinámico;
- escala de frecuencia lineal/logarítmica;
- zoom temporal;
- desplazamiento temporal;
- cursor con tiempo y frecuencia aproximada;
- Nyquist derivado de la pista;
- actualización/cancelación;
- exportación PNG.

El espectrograma no modifica el archivo ni intenta detectar “FLAC falso”, transcodificación o cortes automáticos.

## Metadatos

La pestaña Metadatos es de solo lectura. Presenta tags globales y por stream que FFprobe entregue: `title`, `artist`, `album`, `encoder`, `date`, `language`, comentarios y cualquier otro tag disponible.

No se incorpora ExifTool, MediaInfo ni un editor general de EXIF/IPTC/XMP/GPS.

## Preferencias futuras

`MultimediaInspectorPreferences` existe desde 0.13.0 y se inyecta en servicios/UI. Contiene únicamente defaults previsibles: ventana, FFT, rango dinámico, máximo de columnas, escala y canal inicial, sufijo de salida, contenedor preferido opcional, pestaña inicial, nivel de detalle y preservación de metadata.

0.13.0 no crea una sección visible en Ajustes. El descriptor built-in mantiene `settingsOrder: nil`. Cuando se apruebe una interfaz de ajustes deberá integrarse en `SettingsView`/`SettingsRepository`, nunca mediante `UserDefaults` desde una vista ni una pantalla de ajustes privada del módulo.

## OperationCoordinator, cancelación e historial

Remux, generación de espectrograma y exportación PNG reservan `OperationCoordinator`; solo una operación pesada principal puede estar activa.

Cancelar termina el proceso FFmpeg mediante el runner compartido, marca la operación y limpia únicamente temporales que pertenecen a esa operación. No se eliminan originales ni entradas externas y no se publica un resultado parcial.

No se crea historial por abrir, inspeccionar, cambiar pestaña o visualizar un espectrograma. Sí se registra de forma agregada un remux publicado o un PNG exportado. El payload no contiene rutas, nombres de archivo, títulos/idiomas de pistas, tags, PCM ni datos espectrales.

## Privacidad y dependencias

Todo el módulo es local. No usa APIs, telemetría, analytics, cloud, cookies, tokens ni actualizaciones. El manifiesto no solicita `networkAccess`.

No se añade ninguna dependencia externa. Se reutilizan:

- FFmpeg y FFprobe ya empaquetados por ZEUVE;
- Swift / SwiftUI / AppKit;
- Accelerate/vDSP;
- CoreGraphics/ImageIO cuando están disponibles para PNG;
- `ZEUVECore`, `ZEUVEStorage`, `ZEUVEOperations` y `ZEUVEEngines`.

## Fuera de alcance de 0.13.0

- ajustes visibles;
- comparación A/B;
- detector de corte o transcodificación;
- detector de “FLAC falso”;
- batch/presets;
- edición de chapters o attachments;
- edición de vídeo streams;
- editor general de metadatos;
- recodificación audiovisual;
- OCR de subtítulos bitmap.


## Saneamiento técnico 0.13.1.0

La primera fase de mantenimiento no añade funciones nuevas a la interfaz; corrige fidelidad y coste interno del espectrograma.

### Escala y exportación

`SpectrogramRenderMapping` define el eje de frecuencia para la vista, el cursor y la rasterización de PNG. La exportación recibe explícitamente la escala activa de la UI. Un PNG exportado en modo logarítmico ya no utiliza un eje lineal distinto al mostrado.

### FFT y memoria

`SpectrogramFFTAnalyzer` precalcula la ventana y conserva el setup DFT de Accelerate durante la petición. `SpectrogramAccumulator` mantiene buffers con índice de lectura y solo compacta cuando ha consumido un bloque significativo; no ejecuta `removeFirst` en cada hop. Con duración conocida, las columnas se agregan directamente en buckets temporales y nunca exceden el límite configurado.

### Mezcla multicanal

La opción `Mezcla` es una representación espectral, no un audio mezclado. Cada canal se analiza por separado y ZEUVE promedia potencia por bin. Esto evita que dos canales con señales opuestas desaparezcan por cancelación al promediar PCM. La selección de un canal individual conserva su comportamiento.

### Render y cancelación

La UI precalcula el mapa fila→bin para reducir el trabajo repetido del Canvas. El exportador crea un buffer RGBA acotado antes de ImageIO y sigue comprobando cancelación durante el rasterizado. Cancelar generación o exportación no se presenta como un error al usuario.

## Optimización medible 0.13.2.0

El cuello principal de 0.13.1.0 era ejecutar cada hop del 50 % y reducir después: el MKV real hacía unas 64.700 FFT por pista estéreo para mostrar solo 1.800 columnas. Además, cada bloque de PCM se reconstruía byte a byte y los objetos `Data` autoreleased podían acumularse durante toda la decodificación.

El planificador calcula primero un presupuesto. Si el análisis completo cabe, conserva todos los hops; si no, divide cada columna en ocho estratos y selecciona una ventana representativa de cada uno. El acumulador salta el PCM intermedio y agrega potencia de las ventanas y canales antes de convertirla a dB. La mezcla nunca promedia PCM.

La ventana, setup DFT, buffers complejos, buffer de potencia y buffers de canal se reutilizan. La conversión f32le copia bloques completos a almacenamiento Float alineado y solo guarda de cero a tres bytes residuales. En pistas con más de dos canales, un canal individual se extrae directamente con FFmpeg; para estéreo se conserva la salida interleaved porque medir `pan` no mostró una diferencia material.

Rango dinámico, escala de frecuencia y zoom reinterpretan el resultado. Cambiar pista, canal, FFT o ventana selecciona otra clave analítica. Una caché LRU de memoria, con cuatro entradas y 64 MiB como máximo, evita repetir trabajo idéntico y se invalida al cambiar el fingerprint.

El progreso determinado reserva el 95 % para decodificación/análisis y el final para publicar el modelo. Es monótono y no llega a 100 % antes de terminar. Cancelar marca el acumulador, termina el grupo FFmpeg y descarta columnas parciales.

Los benchmarks y las limitaciones están documentados en `Docs/Historico/Pruebas/TEST_RESULTS_0.13.2.0.md`.


## Experiencia técnica y previsualización 0.14.0.0

### Espectrograma

Los estados vacío y de generación comparten una región centrada. Los controles son responsive y separan análisis (pista, canal, ventana, FFT) de visualización (rango, escala, zoom). El resultado muestra ejes temporales/frecuenciales, leyenda dB y un crosshair que lee tiempo, frecuencia y dB aproximados sin recalcular el modelo. Un clic puede iniciar la escucha desde ese instante y el playhead avanza sobre el mismo eje temporal.

### Previsualización de audio

`MultimediaAudioPreviewService` es un actor auxiliar: FFmpeg decodifica el stream seleccionado a `f32le` y `AVAudioEngine`/`AVAudioPlayerNode` lo reproduce mediante una cola acotada. El pipeline soporta play/pause, seek, saltos y volumen. Pausar detiene FFmpeg para no seguir acumulando trabajo; reanudar abre el stream desde la posición retenida.

La reproducción puede usar una pista original o un audio externo ya incorporado al draft. Antes de reproducir una entrada externa se comprueba su fingerprint. No se modifica el archivo, no se crea historial y no se publica ningún temporal. Reproducción y análisis espectral pueden coexistir; el reproductor no reserva `OperationCoordinator`.

### Pistas, estructura y metadatos

La pestaña Pistas permite escuchar audio, reordenar por drag & drop además de flechas/teclado y soltar archivos externos sobre AUDIO/SUBTÍTULOS. El drop reutiliza la inspección FFprobe y el selector explícito cuando hay varios streams. Resumen muestra múltiples vídeos y estructura adicional (chapters, attachments/attached pictures, programs, data/unknown streams) en lectura. Metadatos incorpora búsqueda y copia local, sin edición.

### Límites

0.14.0.0 no añade reproductor universal de vídeo, timeline, edición temporal, efectos, mezcla creativa, edición de chapters/attachments ni ajustes visibles. El DSP adaptativo y la caché de 0.13.2.0 se conservan.

## Navegación y análisis de audio 0.15.0.0

### Sesiones reutilizables

La cabecera ofrece **Analizar otro archivo…** y **Cerrar análisis**. Ambas rutas pasan por un reset único de sesión que detiene preview, waveform, sonoridad y espectrograma, limpia borrador/resultados específicos y conserva las preferencias. Un borrador con cambios nunca se descarta sin confirmación.

### Waveform como scrubber

La barra temporal del reproductor es una waveform bipolar centrada. Cada bucket conserva máximo positivo, mínimo negativo y RMS. La mitad inferior no se genera espejando la superior. En `Mezcla`, cada frame conserva los extremos presentes entre canales y combina energía sin sumar PCM, evitando que señales antífase desaparezcan.

La waveform completa se resume a un máximo acotado de buckets; el render puede reducirla a Compacta, Equilibrada o Detallada sin volver a ejecutar FFmpeg. `Picos + energía` añade una representación RMS interior y la guía central es opcional.

Waveform y espectrograma usan la misma posición del reproductor. Cambiar de pista mantiene el tiempo actual cuando es válido, y un capítulo con `start_time` puede navegar a ese punto.

### Sonoridad

`AudioLoudnessAnalysisService` ejecuta FFmpeg con EBU R128. Publica Integrated Loudness (LUFS), LRA, True Peak y Sample Peak cuando la salida los contiene. Es una operación pesada, cancelable y coordinada por `OperationCoordinator`; los resultados permanecen en memoria de la sesión. Desde 0.15.7.0 el ViewModel la inicia automáticamente solo cuando FFprobe detecta exactamente una pista de audio y después de finalizar el espectrograma; con varias pistas continúa siendo una acción manual sobre la pista elegida.

### Timestamps

`AudioTimingAnalyzer` compara `start_time` y duración de cada audio con el vídeo principal, o con el contenedor si no hay vídeo. ZEUVE muestra diferencias numéricas y ausencia de datos; no etiqueta automáticamente una pista como desincronizada.

### Informe técnico

El usuario puede exportar TXT, Markdown o JSON. El exportador reconstruye un payload explícito y no incluye `format.filename`, ruta completa del origen, fingerprints ni IDs internos de preview. La publicación usa temporal propio y `MultimediaOutputPublisher`.

### Ajustes centralizados

`MultimediaInspectorSettingsStore` persiste `multimediaInspector.preferences` mediante `SettingsRepository`. La superficie central permite configurar waveform, volumen/salto, FFT, ventana, escala, rango, canal inicial, pestaña/detalle inicial, metadatos, sufijo y contenedor preferido. La restauración del módulo y la global conservan archivos, historial y resultados.

### Fuera de alcance

0.15.0.0 no añade preview universal de vídeo, timeline, edición temporal, mezcla creativa, efectos, batch ni edición de chapters/attachments/metadatos generales.

## Corrección de previsualización 0.15.1.0

### Sustitución real de pista

La previsualización usa una única generación de operación para start/stop/seek. Al solicitar otra pista, se cancela la petición anterior, se espera su cierre lógico y solo la generación vigente puede publicar snapshots. En pistas originales, la selección principal `selectedAudioStreamIndex` se sincroniza sin disparar un stop independiente que pueda competir con el nuevo start.

Cambiar A → B conserva la posición temporal y el command builder recibe el `streamIndex` exacto de B. Si el usuario solicita A → B → C rápidamente, una petición anterior no puede volver a publicar B ni detener C.

### Seek optimista de waveform

Al clicar o arrastrar la waveform, `previewPosition` adopta el destino de forma síncrona antes de liberar el estado local del gesto. El monitor anterior se cancela y los snapshots se validan contra la generación del seek. De este modo la barra no vuelve durante un frame a la posición anterior mientras FFmpeg/AVAudioEngine reinician desde el nuevo instante.

No cambia la representación bipolar, caché, sonoridad, edición estructural, privacidad ni política de motores.

## Sustitución atómica de audio 0.15.2.0

`MultimediaAudioPreviewService.replaceSource` retira la sesión anterior del estado compartido, cancela su cola y tarea, termina su grupo FFmpeg y detiene/desecha AVAudioPlayerNode y AVAudioEngine antes de crear la sesión siguiente. Un ticket generacional interno invalida cualquier reemplazo que haya quedado atrás mientras esperaba esa limpieza.

El ViewModel conserva el playhead aunque haya una petición pendiente, limita la posición a la duración nueva y separa `requestedPreviewSourceID` de la fuente ya confirmada. Así, durante el cambio solo la pista pedida muestra **Cargando…**; la anterior muestra **Escuchar** y la nueva pasa a **Pausar** al confirmarse. Waveform, espectrograma y monitor mantienen sus controles de generación para rechazar datos antiguos.

## Reproductor compartido y layout adaptable — 0.15.3.0

El Inspector mantiene una única sesión de `MultimediaAudioPreviewService` y un único estado observable en `MultimediaInspectorViewModel`. Los controles de Pistas, Espectrograma y el reproductor inferior son interfaces distintas sobre esa misma sesión; no existen reproductores, timers ni estados `isPlaying` por pestaña.

Al sustituir una pista se conserva la posición temporal y el estado anterior. Si estaba reproduciendo, la nueva pista continúa reproduciendo desde el instante retenido. Si estaba pausada, la nueva fuente queda preparada en Pausa en el instante retenido sin arrancar FFmpeg ni AVAudioEngine; la reanudación posterior desde cualquiera de los controles abre esa fuente desde el mismo punto. La posición se limita siempre a la duración declarada de la nueva pista.

El seek de la waveform conserva el estado Play/Pausa. Un clic explícito sobre el gráfico del espectrograma mantiene su semántica de «escuchar desde este instante» y sí inicia reproducción. El botón `Escuchar/Pausar` del Espectrograma, en cambio, reutiliza la sesión compartida y no fuerza `00:00`.

Durante sustituciones rápidas el ViewModel considera tanto la fuente confirmada como `requestedPreviewSourceID` y la fuente activa interna para no perder una selección posterior mientras la anterior sigue en `loading`. `PreviewSourceReplacementGate` continúa siendo la autoridad que invalida generaciones antiguas dentro del servicio.

La zona gráfica del Espectrograma es flexible en vertical. Eje de frecuencia, raster y leyenda dB ya no imponen 420 pt mínimos; absorben la reducción de altura disponible y dejan al reproductor inferior su tamaño intrínseco. No se añade scroll vertical global ni se modifica el layout de Resumen, Pistas o Metadatos.

## Controles de preview centralizados — 0.15.4.0

Pistas y Espectrograma no mantienen ya reglas propias para decidir si su botón representa la sesión activa. Ambos consultan `MultimediaInspectorViewModel.previewPlaybackState(for:)`, que asocia la identidad concreta con el estado global de preview.

Durante una sustitución se prioriza `requestedPreviewSourceID`; cuando no hay petición pendiente se usa `previewSourceID`, y `activePreviewSource` queda únicamente como respaldo transitorio. La misma resolución alimenta tanto la etiqueta visual como la decisión interna de `previewTrack(...)` y `previewSelectedSpectrogram(...)`. Así el control que acaba de iniciar la sesión puede pausarla inmediatamente igual que el control equivalente de la otra pestaña.

El clic sobre el raster del espectrograma conserva su semántica diferenciada de «escuchar desde este instante». El servicio de audio, la sustitución generacional y la política de continuidad temporal/Play-Pausa de 0.15.3.0 no cambian.


## Identidad estable del transporte — 0.15.5.0

La fuente solicitada y la fuente confirmada tienen funciones distintas. `requestedPreviewSourceID` solo identifica la fila que debe mostrar **Cargando…**. Una vez que el preview está en `.playing`, `.paused` o `.finished`, la única identidad válida para `Escuchar/Pausar` es `previewSourceID`, publicada por el snapshot del servicio.

`previewTrack(...)` y el botón equivalente del Espectrograma consultan `previewPlaybackState(for:)` antes de actuar. Si la fuente confirmada está reproduciéndose se pausa; si está pausada o finalizada se reanuda; si otra fuente está cargando no se duplica la orden; y si la fila no corresponde a la sesión se inicia/cambia la previsualización. El reproductor inferior continúa usando el mismo `togglePreviewPause()` global.


## Identidad estable de filas durante reproducción — 0.15.6.0

En modo de solo lectura, `audioTracks` y `subtitleTracks` usan snapshots almacenados por `MultimediaInspectorViewModel` en lugar de convertir de nuevo los streams de la inspección en cada lectura. Cada `MediaEditableTrack` conserva por tanto el mismo UUID durante toda la sesión de análisis.

Esto es relevante porque `previewPosition` se publica con frecuencia mientras se reproduce audio. Antes, cada recomposición podía crear nuevas identidades para las filas de Pistas y SwiftUI reemplazaba los botones en pleno gesto. La versión 0.15.6.0 elimina esa reconstrucción continua sin modificar el motor de preview ni la identidad de fuente usada por el transporte. Los snapshots se reconstruyen únicamente al abrir una inspección nueva o al publicar un resultado editado, y se limpian al cerrar o fallar la sesión.


## Análisis automático cuando existe una sola pista — 0.15.7.0

Después de la inspección FFprobe, `MultimediaAutomaticAudioAnalysisPolicy` decide únicamente por el número real de streams de audio:

- `0`: no se inicia ningún análisis de audio;
- `1`: se genera automáticamente el espectrograma y después se calcula la sonoridad EBU R128;
- `2+`: espectrograma y sonoridad permanecen manuales para no elegir una pista de forma silenciosa.

La extensión no interviene en la decisión, por lo que WAV/MP3/FLAC y contenedores de vídeo con un solo stream siguen la misma regla. El espectrograma se inicia con los parámetros de sesión ya centralizados; al finalizar y liberar `OperationCoordinator`, comienza la sonoridad sobre la misma pista. Los servicios no se ejecutan en paralelo.

La cadena automática es efímera y cancelable. `resetCurrentInspectionSession()` invalida su identidad y cancela la tarea coordinadora además de los servicios ya existentes; `cancelCurrentOperation()` hace lo mismo para una cancelación explícita. Si una fase falla, la inspección técnica permanece disponible y la siguiente fase puede intentarse; los controles manuales permanecen para regenerar o reanalizar.

No cambia `MultimediaAudioPreviewService`, la identidad estable de filas de 0.15.6.0, waveform, tiempo compartido, edición, exportación, privacidad, motores ni archivos originales.


## Viewport temporal compartido — 0.15.8.0

Waveform y espectrograma dejan de mantener ventanas temporales independientes. `MultimediaInspectorViewModel` posee un único `AudioTimelineViewport`, del que ambas vistas derivan el intervalo visible. Los controles de zoom, desplazamiento y **Vista completa** modifican ese mismo estado, y el playhead continúa procediendo exclusivamente del reproductor compartido.

La waveform conserva una envolvente bipolar resumida de hasta **65.536 intervalos** por análisis. Al ampliar una región, `MultimediaWaveformRenderSampler` recorta únicamente los buckets que corresponden al intervalo visible y los reduce al ancho de render actual. El zoom/pan no relanza FFmpeg, no recalcula PCM y no conserva el audio completo en memoria.

Cuando hay reproducción activa o una posición de preview válida, el zoom se centra alrededor de ese instante; en ausencia de una referencia válida utiliza el centro del intervalo actual. El pan se expresa como fracción de la ventana visible y siempre se clampa a la duración disponible. **Vista completa** vuelve al archivo entero.

Los capítulos válidos de la inspección se proyectan como `AudioTimelineChapterMarker` y se muestran sobre la waveform de la fuente original. Son estrictamente informativos: el hover indica título y tiempo y no habilita edición, reordenación ni escritura de capítulos. Para una fuente externa del draft se omiten, porque pertenecen al contenedor original.

Esta ampliación no modifica `MultimediaAudioPreviewService`, la selección de pistas, el análisis automático mono-pista de 0.15.7.0, la edición/remux ni los parámetros DSP. Silencios, clipping, mapa temporal de sonoridad y comparación A/B permanecen fuera de 0.15.8.0.

## Análisis de señal — 0.15.9.0

El Inspector añade un análisis independiente de la waveform visual. FFmpeg decodifica únicamente la pista elegida a PCM `float32` conservando sample rate y canales, y el acumulador procesa los bloques incrementalmente.

### Silencios

El silencio se decide por ventanas RMS de 10 ms y exige que **todos los canales** estén por debajo del umbral. El valor predeterminado es -60 dBFS y la duración mínima 0,5 s, ambos configurables desde Ajustes centralizados. Esto evita clasificar como silencio una mezcla cancelada por fase cuando un canal sigue conteniendo señal.

### Posible clipping

ZEUVE no presenta una muestra alta como diagnóstico absoluto. Marca **Posible clipping** cuando un canal contiene una secuencia mínima configurable de muestras próximas al límite digital (predeterminado -0,1 dBFS, tres muestras consecutivas). Eventos muy cercanos se agrupan y el número retenido se acota para proteger memoria y UI.

### Línea temporal y automatización

Los silencios se dibujan como intervalos y los posibles clippings como eventos sobre waveform y espectrograma, utilizando el mismo `AudioTimelineViewport`. Con una sola pista, la secuencia automática es espectrograma → señal → sonoridad; con varias pistas el usuario selecciona manualmente qué pista analizar. Cada fase sigue siendo cancelable y pesada bajo `OperationCoordinator`.

No se persiste PCM ni resultados privados, no se modifica el original y no se añaden red o dependencias. El mapa temporal de sonoridad y la comparación A/B permanecen para una fase posterior.

## Sonoridad temporal y comparación A/B — 0.16.0.0

### Evolución de sonoridad

`AudioLoudnessAnalysisService` continúa ejecutando una sola cadena FFmpeg con `ebur128=peak=true` y `astats`. Además del resumen final (Integrated, LRA, True Peak y Sample Peak), el collector extrae de las líneas periódicas `t`, Momentary, Short-term e Integrated. Los valores no finitos/`-inf` se tratan como ausencia de medida, no como un número inventado.

La serie se guarda en `AudioLoudnessTimeline`. `AudioLoudnessTimelineAccumulator` impone un máximo de muestras retenidas y compacta pares cuando lo supera, ponderando la media por el número de puntos representados y preservando mínimos/máximos. Hacer zoom o mover la ventana temporal solo filtra estos datos en memoria; no relanza FFmpeg.

La pestaña Espectrograma añade una franja **Sonoridad temporal · Short-term LUFS**. Utiliza el mismo `SpectrogramResult.startTime/endTime` derivado de `AudioTimelineViewport`; muestra el playhead global, permite hover M/S/I y un clic hace seek del reproductor compartido. Si la pista todavía no tiene sonoridad, se ofrece el análisis manual en vez de iniciarlo por entrar en la pestaña.

### Comparación A/B

Cuando existen dos o más pistas de audio, Pistas muestra **Comparar A/B**. A y B deben ser distintas. La selección de A/B es independiente de `selectedAudioStreamIndex`: alternar la escucha no cambia el espectrograma ni obliga a regenerarlo. Se reutiliza `MultimediaAudioPreviewService`; al sustituir A↔B se conserva el instante y el estado Play/Pausa conforme a la continuidad de preview existente. Una pista más corta limita el seek a su duración mediante la ruta de preview ya validada.

La tabla compara datos técnicos disponibles y, si existen, Integrated LUFS, LRA, True Peak, Sample Peak, silencios, tiempo total en silencio y Posible clipping. Los valores ausentes se muestran como `n/d`. La acción **Completar análisis A/B** calcula solamente signal/loudness que falten y lo hace pista por pista, nunca con `async let` ni dos operaciones pesadas simultáneas.

Los overlays quedan ligados a la fuente correcta: waveform sigue la fuente que realmente se previsualiza, mientras Espectrograma usa la pista seleccionada específicamente para el análisis espectral.

### Informes schema 2

`MultimediaTechnicalReportExporter` mantiene TXT, Markdown y JSON bajo acción explícita. TXT/Markdown añaden resúmenes útiles de evolución Short-term y de silencios/Posible clipping; no vuelcan miles de muestras. JSON schema 2 puede incluir los puntos temporales retenidos y los eventos de señal disponibles. Ningún formato exporta ruta completa, fingerprint, `sourceID` o PCM, y exportar no ejecuta análisis pendientes.

## Edición estructural — 0.17.0.0 / módulo 0.5.0

### Capítulos

En modo edición, los capítulos pasan al `MediaEditDraft`: pueden añadirse en la posición actual, eliminarse, renombrarse y cambiar su inicio. La waveform proyecta inmediatamente los marcadores del draft. Los finales se derivan del inicio siguiente o de la duración del archivo. Al ejecutar, ZEUVE genera FFmetadata temporal en el workspace y valida después cantidad, orden, tiempos y títulos mediante FFprobe.

### Attachments

Los streams `codec_type=attachment` se pueden conservar, eliminar, renombrar y complementar con archivos externos fingerprintados. Los attachments añadidos solo se planifican para un contenedor compatible; si es necesario proponer MKV, vídeo y audio deben seguir siendo stream copy. Las `attached_pic` continúan como streams de vídeo protegidos y de solo lectura. Los attachments originales pueden extraerse con FFmpeg a un temporal y publicarse después con conflicto seguro.

### Metadatos

Metadatos permite editar un conjunto multimedia seguro: título, artista, álbum, artista del álbum, compositor, género, fecha, comentario y copyright, además de título/idioma de streams donde corresponda. Audio y subtítulos reutilizan el mismo estado del draft que Pistas. Los tags desconocidos permanecen visibles y preservables, pero no se editan arbitrariamente. `Preservar metadatos` ya no controla capítulos: éstos siguen siempre el draft.

### Undo/Redo y validación

Capítulos, attachments y metadata forman parte de los snapshots de `MediaEditDraftHistory`, por lo que `⌘Z`/`⇧⌘Z` los revierte igual que la edición de pistas. La salida no se publica solo por un código 0 de FFmpeg: se vuelve a inspeccionar y `MultimediaResultValidator` comprueba streams, capítulos, attachments y metadata antes de publicar.


## Lotes, presets y cierre de personalización — 0.18.0.0 / módulo 0.6.0

### Lotes

El Inspector acepta una selección múltiple mediante `NSOpenPanel` y drag & drop. Un solo archivo conserva el flujo individual; varios archivos abren `MultimediaBatchView`. `MultimediaBatchViewModel` prepara la cola, deduplica entradas, conserva fingerprints y lanza `MultimediaBatchProcessor` de forma secuencial. Un fallo de un elemento no detiene los siguientes cuando es seguro continuar.

El lote puede combinar inspección FFprobe, análisis de señal, sonoridad EBU R128, espectrograma PNG e informe TXT/Markdown/JSON. No genera waveform, preview ni A/B porque son superficies interactivas. Con varias pistas de audio se omiten los análisis dependientes de pista y se muestra un aviso; ZEUVE nunca selecciona una pista silenciosamente.

Cancelar termina la operación actual y marca pendientes como cancelados, pero conserva las salidas publicadas correctamente de elementos anteriores. `Reintentar fallidos` reconstruye una cola únicamente con los fallidos y mantiene la configuración actual. La pantalla final ofrece resumen agregado y apertura de la carpeta de resultados cuando exista.

### Presets de lote

`MultimediaInspectorBatchPresetStore` usa `multimediaInspector.batchPresets.v1`. Los cuatro presets incluidos son **Inspección rápida**, **Informe técnico**, **Análisis de audio completo** y **Espectrogramas**. Tienen UUID estables y schema versionado. Guardan operaciones y parámetros de análisis/exportación, nunca rutas, carpetas ni archivos.

Crear, editar, duplicar, renombrar, eliminar y restaurar presets se realiza desde **Ajustes → Inspector multimedia → Lotes y presets**. El módulo solo selecciona el preset/configuración para la ejecución actual; modificar temporalmente un lote no cambia el preset guardado.

### Personalización centralizada

0.18 completa una auditoría de valores razonablemente personalizables. Ajustes permite configurar automatización de espectrograma/señal/sonoridad mono-pista, volumen y saltos de preview, continuidad temporal y Play/Pausa al cambiar de pista, paso de zoom y pan, estilo/representación/guías/overlays de waveform, thresholds de señal, ventana/FFT/rango/columnas/escala/canal y tamaño de exportación del espectrograma, formato/secciones de informes, preservación de metadata, sufijo/contenedor de salida y preset predeterminado.

Estos valores son preferencias; las garantías de seguridad no lo son. El usuario no puede desactivar fingerprints, comprobación de symlinks, stream copy de vídeo/audio, validación FFprobe final, publicación segura, protección del original, privacidad ni la coordinación de operaciones pesadas.

## Ayuda contextual y accesibilidad — 0.18.1.0 / módulo 0.6.1

La cobertura de ayuda contextual forma parte del contrato de UX del Inspector. Las vistas **Resumen**, **Pistas**, **Espectrograma**, **Metadatos** y **Lote** incluyen una explicación general accesible desde el componente compartido `ContextualHelpButton`. Los conceptos técnicos o ambiguos —LUFS, LRA, True Peak, Sample Peak, Short-term, sincronización declarada, señal/clipping, FFT, ventana, Nyquist, canales, capítulos, attachments/MIME, metadatos, informes y estados de lote— disponen de ayuda específica junto al valor o control correspondiente.

**Ajustes → Inspector multimedia** reutiliza `HelpLabel`, `HelpPickerRow`, `HelpToggleRow`, `HelpStepperRow` y `ContextualHelpButton` para explicar automatización, reproducción, cambio de pista, zoom/pan, waveform, análisis de señal, espectrograma/exportación, informes, edición/salida y presets de lote. No se crean popovers o iconos `info.circle` paralelos dentro del módulo.

Abrir o cerrar una ayuda solo modifica el estado visual del popover: no lanza FFmpeg/FFprobe, no recalcula waveform/espectrograma/sonoridad/señal, no invalida cachés y no persiste datos multimedia. La ayuda es navegable por teclado y VoiceOver a través del componente común de ZEUVE. Los botones y acciones evidentes no reciben iconos innecesarios para evitar ruido visual.
