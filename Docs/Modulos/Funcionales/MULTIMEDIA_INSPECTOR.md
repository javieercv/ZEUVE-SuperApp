# Inspector multimedia 0.7.2 — ZEUVE 0.20.4.0

## Identidad y alcance

- ID: `com.zeuve.multimedia-inspector`.
- Target: `MultimediaInspectorModule`.
- Versión: `0.7.2`.
- ZEUVE mínimo: `0.13.0`.
- Categoría: Multimedia.
- Atajo por defecto: ⌘6.
- Ajustes: orden 50.
- Red: no.

El Inspector combina **inspección técnica**, preview local, análisis de audio y **edición estructural segura**. No es un editor creativo ni temporal: no corta, mezcla ni aplica efectos y no recodifica audio/vídeo para ejecutar una edición estructural. Si una transformación exige transcode, corresponde al Conversor universal.

## Apertura e inspección

La apertura inicial es de lectura. FFprobe compartido inspecciona el contenedor y los streams antes de habilitar acciones dependientes de una pista. Se muestran, según el archivo:

- formato/contenedor y duración;
- vídeo, audio y subtítulos;
- capítulos;
- tags/metadata;
- attachments y `attached_pic`/carátulas;
- programs y streams de datos/desconocidos cuando existen.

Cambiar o cerrar archivo limpia los servicios propios de la sesión sin reiniciar ZEUVE. Si existe un borrador con cambios, su descarte requiere confirmación.

### Streams de audio incompletos

Si FFprobe no proporciona `sample_rate` y `channels` positivos, la pista puede seguir apareciendo como información técnica, pero el Inspector no inicia funciones PCM que dependen de esos datos: preview, waveform, espectrograma, sonoridad, señal o análisis avanzado. Esto evita divisiones por cero y decodificaciones inválidas.

Si un archivo no contiene audio y la pestaña persistida era Espectrograma, la sesión vuelve a Resumen y desactiva las acciones que requieren audio.

## Preview de audio y vídeo

Existe un transporte compartido con Play/Pausa, posición/seek, salto, velocidad y estado común para las superficies que representan tiempo.

### Audio

FFmpeg decodifica el stream elegido a PCM float32 incremental; `AVAudioEngine`/`AVAudioPlayerNode` realiza la salida. La cola está acotada y aplica back-pressure: no se carga el archivo completo en RAM. Pause/seek/sustitución conservan una posición coherente y descartan procesos obsoletos.

### Vídeo

`MultimediaVideoPreviewService` usa FFmpeg con argumentos separados y entrega frames BGRA acotados a la superficie de preview. La configuración limita resolución interna, FPS, buffer y estrategia de decoding. Puede usar VideoToolbox cuando es viable y caer a software sin cambiar silenciosamente el archivo.

La identidad de preview distingue fuente y stream completos; cambiar de stream no debe confundir dos fuentes que compartan el mismo índice. Las generaciones descartan frames/procesos antiguos.

Pausa conserva fuente/frame para responder de forma inmediata. Los procesos efímeros de preview usan una gracia de cancelación más corta que el valor global de `ExternalProcessRunner`; esa excepción no se extiende a operaciones pesadas.

La velocidad se normaliza al rango 0,5×–2×; valores no finitos vuelven a 1×. El ajuste no debe provocar recursión ni múltiples actualizaciones del mismo transporte.

### Fullscreen

La vista de vídeo obtiene de forma débil la ventana propietaria mediante AppKit para entrar/salir de pantalla completa sin depender de una ventana global equivocada.

## Subtítulos en preview

Los subtítulos textuales internos compatibles se sincronizan con la posición del preview y pueden activarse/cambiarse/desactivarse. SRT/ASS/SSA se manejan como texto/timing; sin libass no se garantiza reproducir todos los estilos avanzados de ASS/SSA.

Las pistas bitmap no se convierten silenciosamente a texto para preview. Cuando son compatibles con el flujo OCR se derivan a una extracción/revisión local independiente.

## Waveform y timeline

La waveform se genera incrementalmente a partir de PCM y conserva picos positivos/negativos y energía agregada por buckets. No persiste PCM completo. Puede actuar como scrubber y comparte posición con preview y espectrograma.

La timeline puede mostrar capítulos y overlays de análisis según las preferencias. Zoom/pan actúan sobre la representación temporal sin relanzar trabajo pesado innecesario.

## Espectrograma

El pipeline separa planificación, decode PCM, FFT/acumulación, rasterización y exportación. Los parámetros configurables incluyen FFT, ventana, escala, canal/downmix, rango dinámico, límite de columnas y dimensiones de exportación.

El análisis usa buffers/columnas acotados y es cancelable. Cambios puramente visuales que pueden reutilizar el resultado no deben volver a decodificar el archivo.

## Sonoridad, señal y comparación

El Inspector puede calcular localmente:

- Integrated Loudness (LUFS);
- Loudness Range (LRA);
- True Peak (dBTP);
- Sample Peak (dBFS);
- timeline de sonoridad cuando está disponible;
- silencios y posibles eventos de clipping según umbrales configurables;
- timing/offsets técnicos;
- comparación A/B entre dos pistas de audio.

Los offsets son datos técnicos y no se convierten automáticamente en un diagnóstico de desincronización.

## Análisis avanzado de fuente y anomalías

`AudioSourceQualityAnalysisService` busca **indicios**, no una prueba absoluta del origen de la señal. Se analizan energía/banda útil, rolloff, caída persistente, ocupación espectral, continuidad temporal y anomalías representativas.

La clasificación distingue niveles de evidencia y expone las métricas que la sustentan. El algoritmo descarta silencio para no sesgar el análisis, acumula información sobre toda la señal útil con memoria acotada y declara cobertura/truncado. Las anomalías contiguas se agrupan y se localizan temporalmente para su representación en timeline.

## OCR local de subtítulos bitmap

El flujo OCR:

1. extrae eventos bitmap a un workspace temporal propiedad de la operación;
2. usa Vision localmente en macOS cuando la pista/formato es viable;
3. conserva idioma/confianza y estructura revisable;
4. presenta un borrador que el usuario puede revisar;
5. permite exportar SRT como salida nueva.

El OCR no reemplaza automáticamente la pista original. El texto reconocido no debe entrar en logs ni en el historial global, y los informes solo contienen resúmenes no sensibles.

PGS es la ruta principal prevista; VobSub depende de la capacidad real del FFmpeg empaquetado y del material inspeccionado.

## Modo edición estructural

`MediaEditDraft` representa el estado editable sin tocar el original. Incluye vídeo, audio, subtítulos, capítulos, attachments, carátulas y metadata admitida.

El usuario dispone de Undo/Redo del **borrador**. Es distinto del Undo de movimientos de otros módulos: mientras no se ejecute, solo cambia el estado de sesión.

### Streams

Según compatibilidad del contenedor se puede:

- conservar/eliminar streams;
- añadir fuentes externas compatibles;
- reordenar vídeo/audio/subtítulos;
- editar título/idioma/dispositions soportadas;
- seleccionar el stream principal/default cuando el contenedor lo permite.

Los streams audiovisuales existentes se conservan mediante stream copy. Si el plan necesitaría recodificación, el Inspector lo rechaza o deriva conceptualmente al Conversor; no la realiza a escondidas.

### Capítulos

Los capítulos pueden añadirse, quitarse, renombrarse o recolocarse por inicio. Se materializan mediante metadata temporal de FFmpeg. En edición, los marcadores de timeline reflejan el draft antes de ejecutar.

### Metadata

Existe un conjunto seguro de tags editables globales/por stream. Tags desconocidos pueden mostrarse y preservarse, pero no se convierten automáticamente en campos arbitrarios editables. Títulos/idiomas de streams reutilizan el mismo estado del draft para evitar fuentes dobles de verdad.

### Attachments y carátulas

Los streams `codec_type=attachment` se gestionan como attachments reales: conservar, retirar, añadir externos compatibles y extraer de forma segura. `attached_pic` se trata como carátula/stream de vídeo especial, no como attachment genérico.

`MultimediaArtworkService` aplica la política apropiada por contenedor para visualizar, extraer, añadir, sustituir o eliminar carátulas cuando sea compatible. Los archivos externos se validan y fingerprintan.

## Ejecución de una edición

Flujo actual:

`MediaEditDraft → MediaEditPlanner → MediaEditValidator → FFmpegMediaEditCommandBuilder → MultimediaEditService → FFprobe → MultimediaResultValidator → publicación segura`

Invariantes:

- original protegido;
- argumentos FFmpeg separados, sin shell;
- workspace temporal propio;
- fingerprints y revalidación de fuentes externas/original cuando procede;
- comprobación de espacio;
- stream copy de vídeo/audio en edición estructural;
- inspección FFprobe del resultado;
- publicación solo si la estructura resultante coincide con el plan;
- resolución segura de conflictos.

La conversión limitada de subtítulos necesaria para una estructura compatible es una excepción específica; no autoriza transcode audiovisual.

## Lotes

El Inspector admite selección múltiple y carpetas. Un lote puede enumerar subcarpetas con profundidad/filtros/ocultos configurables, sin seguir symlinks y deduplicando entradas.

Hay dos familias de trabajo:

- análisis/exportación secuencial (inspección, señal, sonoridad, espectrograma, informe según preset);
- edición estructural por reglas condición → acción, con análisis, plan individual, preflight, revisión y ejecución segura.

Con múltiples pistas de audio el módulo no elige silenciosamente una para análisis dependiente de una sola pista. Un fallo aislado no debe invalidar resultados ya publicados de otros elementos; la cancelación conserva únicamente salidas publicadas correctamente y detiene pendientes.

Los resultados pesados de cada elemento se liberan al terminar para evitar crecimiento de memoria en lotes largos.

## Presets, reglas y favoritos

Los presets de lote y rule sets se persisten mediante `SettingsRepository`. Los favoritos guardan configuraciones reutilizables, no archivos/rutas privadas. Restaurar valores devuelve defaults sin borrar archivos o historial.

## Ajustes

`MultimediaInspectorPreferences` concentra las preferencias de UX/análisis/exportación que son razonablemente configurables: automatización mono-pista, preview, timeline, waveform, señal, espectrograma, sonoridad, análisis avanzado, OCR, informes, edición/salidas, lotes y límites de recursos.

No son configurables las invariantes de seguridad: fingerprints, publicación segura, validación final, rechazo de symlinks donde corresponda, privacidad, hard caps esenciales, stream copy y `OperationCoordinator`.

La UI reutiliza los componentes de ayuda contextual de ZEUVE para conceptos técnicos y métricas ambiguas. Abrir ayuda no ejecuta motores ni modifica estado operativo.

## Informes

`MultimediaTechnicalReportExporter` genera TXT, Markdown o JSON a petición del usuario. El JSON vigente usa schema 3 y puede incorporar información de vídeo/carátulas/análisis avanzado/OCR resumido/edición de forma aditiva.

Los informes excluyen rutas completas privadas, fingerprints, identificadores internos de preview y contenido OCR sensible.

## Historial y privacidad

El historial guarda estados y resúmenes agregados; no persiste PCM, frames, OCR completo, metadata privada arbitraria o rutas completas. Preview/análisis no necesita red. No se añaden APIs externas, telemetría ni motores adicionales: se reutilizan FFmpeg/FFprobe y frameworks del sistema como AVFoundation/AppKit/CoreVideo/Accelerate/Vision cuando procede.

## Compatibilidad deliberada

- MKV/MP4/MOV/WebM y codecs dependen de la capacidad real de FFmpeg/FFprobe empaquetados y de las reglas del contenedor.
- VFR se trata por timestamps, no suponiendo CFR como verdad universal.
- 4K/HDR/HEVC/AV1 pueden inspeccionarse si los motores los soportan; el preview aplica límites de recursos y HDR no equivale a monitor de referencia.
- ASS/SSA: timing/texto compatibles; estilos avanzados no garantizados sin libass.
- Batch estructural trabaja sobre streams existentes/reglas; no hace emparejamiento mágico de archivos externos.

## Código principal

- `Sources/MultimediaInspectorModule/Preview/`
- `Analysis/`, `Spectrogram/`, `Waveform/`, `OCR/`, `Batch/`
- `Models/`, `Planning/`, `Execution/`, `Publishing/`, `Reporting/`, `Presets/`, `Storage/`
- `Sources/ZEUVEApp/MultimediaInspector/`

La historia de cómo se llegó a estas capacidades pertenece a `Docs/Historico/`, no a este documento vivo.
