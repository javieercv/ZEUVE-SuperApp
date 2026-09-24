# Historial de cambios de ZEUVE

## 0.20.4.0 — 2026-09-24

- Limpiador 0.1.2: asociación de residuos por Bundle ID exacto, instaladores sin duplicados entre raíces solapadas y análisis de desinstalación de apps sin identificador limitado al nombre correspondiente.
- «Conservar» se aplica al plan actual y se revalida al ejecutar. El movimiento a Papelera y su registro de Deshacer se tratan por separado; si falla el registro se intenta restaurar el elemento a su ubicación original y se informa del resultado real. Un fallo del historial global no convierte una limpieza ya realizada en error aparente.
- Deshacer parcial mantiene disponibles los elementos pendientes. Espacio explica cuando el tamaño mínimo filtra todos los resultados.
- Se añaden pruebas de regresión de esas rutas. Sin cambios de red, dependencias, permisos, motores o esquema SQLite. ZEUVE marketing 0.20.4, build 70.

## 0.20.3.0 — 2026-09-24

- Limpiador pasa a 0.1.1: inventario cancelable, medición de tamaños más rápida y búsqueda de Spotlight acotada a 30 segundos.
- Si Spotlight no completa, el análisis muestra cobertura parcial y conserva la clasificación histórica de aplicaciones sin inferir desinstalaciones.
- Limpieza muestra también preferencias y datos persistentes sin preseleccionarlos. En desinstalaciones, la app y sus asociados mantienen una selección coherente.
- La confirmación enumera rutas, cantidad, tamaño y modo. El resultado detalla eliminados, omitidos y fallidos; una limpieza sin movimientos no crea un nuevo Deshacer y el plan se actualiza sin reutilizar selecciones antiguas.
- Sin dependencias, red, motores, permisos ni migración de almacenamiento. ZEUVE marketing 0.20.3, build 69.
- Auditoría documental: Fundamentos, documentación funcional, motores, contexto de agentes e índice se sincronizan con el estado real 0.20.3.0; se añade documentación dedicada del Organizador y se separa con más claridad documentación viva e histórica. No cambia comportamiento de producto.
- Las instrucciones para chats de desarrollo adoptan la misma ruta documental canónica: `AGENTS.md` → `Docs/INDEX.md` → conjunto mínimo de documentación viva relevante; `Docs/Historico/` queda reservado a regresiones, comparación de versiones y evidencia pasada. El verificador documental exige esta política.

## 0.20.2.0 — 2026-09-24

- Inspector multimedia pasa a 0.7.2 y optimiza la respuesta de Play/Pausa, seek y sustituciones sin cambiar identidades, generaciones, resolver de controles ni semántica de pausa.
- La salida de audio se detiene inmediatamente antes de la limpieza asíncrona de FFmpeg/AVAudioEngine, conservando el playhead capturado.
- Los FFmpeg efímeros de preview usan una gracia de cancelación opt-in de 50 ms; el valor global de `ExternalProcessRunner` continúa en 2 s para el resto de operaciones.
- El monitor del preview deja de sondear durante Pausa y evita republicar estado/frame sin cambios, reduciendo recomposiciones SwiftUI innecesarias.
- Sin cambios de red, dependencias, motores, privacidad, edición, archivos originales ni opciones visibles. ZEUVE marketing 0.20.2, build 68.

## 0.20.1.0 — 2026-09-23

- Inspector multimedia 0.7.1 unifica el transporte por identidad, conserva fuente/frame al pausar vídeo y usa la ventana propietaria para fullscreen.
- Cancelar edición conserva pausadas solo las sesiones íntegramente originales; las externas, mixtas o no resolubles se detienen.
- El análisis separa rolloff 99,5 %, banda efectiva y caída persistente, mide cobertura y declara el truncado de anomalías.
- Informe JSON schema 3 aditivo; ZEUVE marketing 0.20.1, build 67, sin red, motores ni dependencias nuevas.

## 0.20.0.0 — 2026-09-22

- Añadida personalización global de orden de módulos y atajos de teclado, compartida por Sidebar, Inicio y comandos, con recorder nativo, validación, `Sin atajo` y restauración.
- Nuevo **Limpiador 0.1.0**: inventario de apps, residuos, limpieza regenerable, Xcode, instaladores, LaunchItems, espacio, análisis de desinstalación, Papelera/permanente y Undo.
- Nueva migración SQLite 3 para inventario, raíces asociadas, decisiones `Conservar`, metadata de scan y Undo.
- Nuevos permisos de manifiesto `scanLocalStorage` y `removeLocalItems`, sin relajar las protecciones de otros módulos.
- El Limpiador no añade red, motores, dependencias externas, shell, `sudo` ni helper root.
- ZEUVE pasa a marketing 0.20.0 y build 66.

## 0.19.0.0 — 2026-09-21

- Corregido el cierre del Inspector al abrir/cerrar un archivo: restaurar la velocidad de reproducción ya no provoca recursión infinita en su observador `@Published`. Se conservan los límites de 0,5×–2× y una sola actualización de audio/vídeo por asignación.
- Inspector multimedia pasa a módulo `0.7.0`; ZEUVE usa marketing `0.19.0` y build `65`.
- Preview de vídeo local con FFmpeg, superficie nativa, transporte A/V compartido, seek, cambio de streams, velocidad, volumen, fullscreen y límites configurables de resolución/FPS/buffer; VideoToolbox puede usarse cuando sea viable y existe fallback a software.
- Preview sincronizado de subtítulos textuales; ASS/SSA conserva texto/timing sin garantizar estilos avanzados al no incorporar libass. Los subtítulos bitmap se derivan al flujo OCR revisable.
- Edición estructural de vídeo por stream copy y gestión diferenciada de carátulas/`attached_pic`; cualquier transformación que requiera transcode continúa bloqueada y pertenece al Conversor universal.
- Lote ampliado con carpetas, recursión/profundidad, ocultos, filtros, orden, deduplicación segura, reglas semánticas, preflight por archivo y ejecución secuencial validada.
- Análisis avanzado de audio con indicios explicables de fuente previamente comprimida con pérdida y anomalías espectrales temporales; no se emiten afirmaciones absolutas basadas solo en un cutoff.
- OCR local de subtítulos bitmap con Vision, borrador revisable y exportación SRT; nunca sustituye automáticamente la pista original y no se registra el texto reconocido.
- Favoritos para presets y conjuntos de reglas reutilizables sin rutas de archivos.
- Informes JSON pasan a schema `3` con vídeo, carátulas, análisis avanzado, resumen OCR y edición estructural, manteniendo sanitización de rutas, fingerprints, identificadores internos y contenido OCR.
- Ajustes centralizados y ayuda contextual cubren las nuevas preferencias; las invariantes de seguridad, hard caps anti-OOM, protección del original, publicación segura y validación FFprobe siguen sin ser desactivables.
- No se añaden dependencias externas, motores, APIs, telemetría ni permisos de red.

## 0.18.1.0 — 2026-09-21

- Inspector multimedia pasa a módulo 0.6.1 y completa la ayuda contextual exigida por las reglas UX del proyecto.
- Ajustes → Inspector multimedia explica mediante los componentes compartidos `HelpLabel`, `HelpPickerRow`, `HelpToggleRow`, `HelpStepperRow` y `ContextualHelpButton` las opciones técnicas de automatización, reproducción, timeline, waveform, señal, espectrograma/exportación, informes, edición/salida y presets de lote.
- Resumen, Pistas, Espectrograma, Metadatos y Lote incorporan ayuda general; LUFS/LRA/True Peak/Sample Peak, señal/clipping, sincronización, FFT/Nyquist/canales, capítulos, attachments/MIME, metadatos e informes disponen de ayuda específica cuando el concepto puede resultar ambiguo.
- La ayuda contextual es puramente de UI: abrir/cerrar un popover no ejecuta motores, no recalcula análisis, no invalida cachés y no cambia preferencias ni archivos.
- Se consolida `Docs/Modulos/Funcionales/MULTIMEDIA_INSPECTOR.md` para reflejar correctamente la edición estructural ya disponible y se eliminan contradicciones con secciones históricas.
- Se añade regresión automática para impedir nuevas superficies técnicas del Inspector sin la ayuda contextual aprobada o iconos de información paralelos.
- Sin cambios de red, motores, dependencias, privacidad, publicación, `OperationCoordinator` ni protección del original.

## 0.18.0.0 — 2026-09-21

- Inspector multimedia pasa a módulo 0.6.0 e incorpora un modo de lote para analizar varias selecciones o múltiples archivos arrastrados sin sustituir el flujo individual existente.
- La cola procesa los archivos estrictamente en secuencia: FFprobe y, según configuración, análisis de señal, sonoridad EBU R128, espectrograma PNG e informe TXT/Markdown/JSON. `OperationCoordinator` sigue siendo la única autoridad de operaciones pesadas.
- Los archivos con varias pistas de audio nunca reciben una selección silenciosa: se conserva la inspección técnica y los análisis dependientes de una pista se omiten con un aviso. Un fallo aislado no detiene el resto del lote.
- Se añaden presets de lote versionados y persistidos mediante `SettingsRepository`, con cuatro presets incluidos, gestión centralizada en Ajustes y ausencia expresa de rutas, carpetas o listas privadas.
- Ajustes del Inspector amplía la personalización de automatización, reproductor, cambio de pista, zoom/pan, waveform/overlays, señal, espectrograma y exportación, informes, salida y preset de lote predeterminado. Las garantías de seguridad y validación no son configurables.
- El lote protege simultáneamente todos los originales, vuelve a verificar fingerprints, rechaza symlinks, publica con resolución segura de conflictos, libera resultados pesados por elemento y conserva únicamente resúmenes compactos.
- Cancelar conserva los resultados ya publicados correctamente; existe reintento de fallidos, apertura de la carpeta de resultados y una única entrada agregada de historial sin nombres ni rutas de archivos.
- No se añaden dependencias, red, APIs, motores ni telemetría; no se incorpora edición estructural masiva por lotes.

## 0.17.0.0 — 2026-09-21

- Inspector multimedia pasa a módulo 0.5.0 y completa la edición estructural de capítulos, attachments reales y metadatos multimedia seguros dentro del mismo borrador Undo/Redo.
- Los capítulos pueden crearse, eliminarse, renombrarse y recolocarse por inicio; la waveform refleja el draft al instante y FFmpeg recibe una fuente FFmetadata temporal propiedad del workspace.
- Los streams `codec_type=attachment` pueden añadirse, eliminarse, renombrarse/cambiar MIME y extraerse de forma segura. Las `attached_pic` permanecen protegidas y de solo lectura.
- Los attachments externos se validan como archivos regulares, se fingerprintan y pueden forzar una propuesta MKV solo cuando vídeo/audio permanecen en stream copy.
- Metadatos permite editar un conjunto seguro de tags globales y por stream; los tags desconocidos continúan visibles y preservables pero no se editan arbitrariamente.
- `Preservar metadatos` deja de controlar los capítulos: los capítulos siempre siguen el `MediaEditDraft`.
- Planner, command builder, cálculo de espacio, ejecución, historial agregado y validación FFprobe se amplían para comprobar la estructura final antes de publicar.
- No se añaden dependencias, red, APIs, motores ni telemetría; el original permanece protegido.

## 0.16.0.0 — 2026-09-20

- Inspector multimedia pasa a módulo 0.4.0 e incorpora evolución temporal EBU R128 sin añadir otra pasada FFmpeg: la misma sonoridad global conserva Momentary, Short-term e Integrated LUFS en una serie acotada.
- Espectrograma muestra una franja de Short-term LUFS sincronizada con `AudioTimelineViewport`, playhead y seek; el hover expone M/S/I sin relanzar análisis al hacer zoom.
- Pistas incorpora comparación A/B con un único reproductor: A↔B conserva timestamp y estado Play/Pausa y no cambia la pista seleccionada para el espectrograma.
- La comparación técnica combina codec/bitrate/sample rate/canales/duración con sonoridad, silencios y Posible clipping ya disponibles; **Completar análisis A/B** ejecuta únicamente signal/loudness faltantes y siempre de forma secuencial.
- Waveform y Espectrograma separan explícitamente la fuente de overlays para que una escucha A/B no proyecte eventos de otra pista sobre el espectrograma seleccionado.
- Los informes técnicos pasan a JSON schema 2 e incorporan sonoridad temporal y análisis de señal disponibles; TXT/Markdown ofrecen resumen acotado y todos los formatos siguen omitiendo rutas completas, fingerprints e IDs internos.
- No se añaden dependencias, red, APIs, motores, telemetría ni cambios sobre los originales.

## 0.15.9.0 — 2026-09-20

- Inspector multimedia pasa a módulo 0.3.9 e incorpora un análisis local de señal PCM a resolución completa para silencios y **Posible clipping**.
- El silencio se calcula por ventanas RMS y solo se considera como tal cuando todos los canales quedan bajo el umbral; valores predeterminados: -60 dBFS durante al menos 0,5 s.
- El posible clipping usa un criterio conservador configurable cerca de 0 dBFS y exige varias muestras consecutivas; los eventos cercanos se agrupan y se limita la cantidad retenida en memoria.
- Waveform y espectrograma proyectan los silencios y posibles clippings sobre el mismo `AudioTimelineViewport`; hover/cursor muestran tiempo, duración, canal y pico cuando corresponda.
- Con exactamente una pista, el flujo automático es ahora espectrograma → análisis de señal → sonoridad. Con varias pistas, el usuario sigue eligiendo manualmente la pista.
- El análisis conserva sample rate y canales originales, procesa PCM `float32` por streaming, es cancelable, verifica fingerprint y respeta `OperationCoordinator`. No añade red, dependencias ni escrituras sobre el original.


## 0.15.8.0 — 2026-09-20

- Inspector multimedia pasa a módulo 0.3.8 e introduce una única ventana temporal compartida entre waveform y espectrograma.
- Zoom, desplazamiento lateral y **Vista completa** actúan sobre el mismo intervalo; cuando existe una posición de reproducción válida el zoom se centra en el playhead y todas las superficies siguen usando el mismo reproductor compartido.
- La waveform aumenta su envolvente base hasta un máximo acotado de 65.536 intervalos y recorta/reduce únicamente la zona visible en memoria. Navegar o hacer zoom no relanza FFmpeg ni conserva PCM completo.
- Los capítulos válidos de la fuente original aparecen como marcadores de solo lectura sobre la waveform, con título y tiempo exacto en el hover; no se habilita edición de capítulos.
- Corrección posterior de compilación: la proyección de capítulos del Inspector declara explícitamente el resultado opcional de `compactMap`, evitando el error Swift que rechazaba `nil` al filtrar capítulos sin tiempo válido.
- Se mantienen sin cambios el análisis automático mono-pista de 0.15.7.0, `MultimediaAudioPreviewService`, la edición/remux, `OperationCoordinator`, privacidad, red, motores, dependencias y protección de archivos originales.

## 0.15.7.0 — 2026-09-20

- Inspector multimedia pasa a módulo 0.3.7 y automatiza el análisis complementario cuando FFprobe detecta exactamente una pista de audio.
- Tras la inspección técnica, una sesión con una sola pista genera primero el espectrograma y, después de liberar `OperationCoordinator`, calcula la sonoridad EBU R128; WAV, MP3, FLAC y vídeos de una sola pista reciben la misma política porque la decisión depende de los streams reales, no de la extensión.
- Con cero pistas no se inicia ningún análisis de audio y con dos o más pistas se conserva el flujo manual actual para que ZEUVE no elija silenciosamente qué audio analizar.
- La cadena automática es secuencial y cancelable: cerrar/sustituir la sesión o cancelar el espectrograma impide que una fase posterior se inicie con datos obsoletos. Un fallo del espectrograma no invalida la inspección técnica ni impide intentar la sonoridad.
- Se mantienen los botones manuales de generación/reanálisis, los ajustes centralizados y todo el reproductor compartido de 0.15.6.0. No se añaden motores, dependencias, red, telemetría ni escrituras sobre el original.

## 0.15.6.0 — 2026-09-20

- Inspector multimedia pasa a módulo 0.3.6 y corrige la identidad efímera de las filas de Pistas durante la reproducción.
- En modo solo lectura, audio y subtítulos ya no se reconstruyen mediante `MediaEditableTrack.from(...)` cada vez que SwiftUI evalúa la vista; el ViewModel materializa las pistas una sola vez por inspección y conserva sus UUID hasta cerrar o sustituir esa sesión.
- Las actualizaciones frecuentes de `previewPosition` dejan de provocar que SwiftUI destruya y recree los botones `Escuchar/Pausar`, evitando clics perdidos al pausar desde Pistas después de iniciar allí o desde el reproductor inferior.
- La caché de identidad se limpia al cerrar/fallar una inspección y se reconstruye al abrir un archivo nuevo o tras publicar un resultado editado.
- No cambian `MultimediaAudioPreviewService`, el transporte compartido, waveform, espectrograma, motores, dependencias, red, privacidad ni archivos originales.

## 0.15.5.0 — 2026-09-20

- Inspector multimedia pasa a módulo 0.3.5 y corrige el botón `Escuchar/Pausar` de Pistas cuando la reproducción se inició desde esa misma fila o desde el reproductor inferior.
- `requestedPreviewSourceID` se usa únicamente para identificar la fuente durante `.loading`; en `.playing`, `.paused` y `.finished` la identidad activa procede exclusivamente de `previewSourceID`, que es la fuente confirmada por el reproductor.
- `previewTrack(...)` y `previewSelectedSpectrogram(...)` ejecutan iniciar/cambiar/pausar/reanudar a partir de la misma proyección `previewPlaybackState(for:)`; se elimina la segunda decisión interna `shouldTogglePreviewControl`.
- Se conserva íntegramente lo corregido en 0.15.3.0 y 0.15.4.0: un único reproductor, tiempo compartido, continuidad Play/Pausa al cambiar de pista, seek pausado y layout adaptable del Espectrograma.
- No cambian `MultimediaAudioPreviewService`, motores, dependencias, red, privacidad, permisos, archivos originales, DSP ni otros módulos.

## 0.15.4.0 — 2026-09-19

- Inspector multimedia pasa a módulo 0.3.4 y centraliza en `MultimediaInspectorViewModel` la identidad y el estado de los botones `Escuchar/Pausar` de Pistas y Espectrograma.
- Durante una transición de preview se prioriza la fuente solicitada, después la fuente confirmada y solo como respaldo la fuente activa interna, evitando que el botón que inició la reproducción vuelva a entrar por una ruta de arranque en vez de pausar.
- Pistas y Espectrograma obtienen su presentación `Cargando…`/`Pausar`/`Escuchar` desde la misma resolución de estado; Espectrograma deja de decidir localmente entre `togglePreviewPause()` y `previewSelectedSpectrogram(...)`.
- Se conserva íntegramente lo corregido en 0.15.3.0: posición compartida, continuidad Play/Pausa al cambiar de pista, seek pausado, sustitución A→B→C y layout vertical flexible del Espectrograma.
- No cambian servicio de audio, dependencias, motores, red, privacidad, permisos, originales, DSP, edición estructural ni otros módulos.

## 0.15.3.0 — 2026-09-19

- Inspector multimedia pasa a módulo 0.3.3 y mantiene un único estado de reproducción visible entre Pistas, Espectrograma, waveform y barra inferior.
- Cambiar de pista conserva el instante y también Play/Pausa. Si la sesión estaba pausada, la nueva fuente queda preparada en pausa sin arrancar FFmpeg ni AVAudioEngine hasta la reanudación.
- El seek desde la waveform conserva Pausa; reiniciar desde `finished` sigue reproduciendo desde el inicio como antes.
- El botón `Escuchar` de Espectrograma deja de forzar `00:00` y reutiliza la sesión/posición compartida; los clics intencionados sobre el gráfico siguen reproduciendo desde el instante elegido.
- Los cambios rápidos de pista reconocen tanto la fuente confirmada como una sustitución todavía pendiente, evitando perder la última selección durante `loading`.
- El Espectrograma elimina su mínimo rígido de 420 pt: gráfico, eje y leyenda se adaptan a la altura disponible para mantener accesible el reproductor inferior sin añadir scroll global.
- No cambian dependencias, motores, red, privacidad, permisos, archivos originales, DSP, edición estructural ni otros módulos.

## 0.15.2.0 — 2026-09-09

- Hace atómica la sustitución del preview multiaudio: la sesión anterior captura y cierra su FFmpeg, scheduler, player y AVAudioEngine antes de autorizar el arranque siguiente.
- Añade una generación interna al servicio de audio; en cambios rápidos A→B→C solo la petición más reciente puede crear o publicar la nueva sesión y un cierre antiguo nunca toca recursos posteriores.
- Conserva la posición también mientras existe una sustitución pendiente, limita el instante a la duración de una pista más corta y mantiene el mismo ciclo para pistas originales y externas o al cambiar desde pausa.
- La fila solicitada muestra **Cargando…**; la anterior vuelve inmediatamente a **Escuchar** y solo la fuente confirmada muestra **Pausar**.
- Waveform, espectrograma y snapshots conservan sus generaciones de invalidación para descartar resultados antiguos. El selector FFT sigue usando `defaultPreferences.allowedFFTSizes`.
- Añade regresiones de ciclo de vida y validación real en macOS con el MKV multiaudio indicado. No cambia DSP, formatos, motores, red, privacidad, dependencias ni edición de archivos.

## 0.15.1.0 — 2026-09-09

- Corrige la previsualización multiaudio del Inspector: pulsar **Escuchar** en otra pista sustituye realmente el stream activo y sincroniza la pista seleccionada del Inspector, en lugar de mantener o reactivar la fuente anterior.
- Serializa start/stop/seek del preview mediante una generación de operación; una petición antigua no puede sobrescribir el estado ni detener una reproducción más reciente.
- El cambio de pista conserva la posición temporal cuando es válida y FFmpeg recibe el `-map 0:<streamIndex>` correspondiente a la nueva pista.
- Corrige el seek de la waveform con actualización optimista: el playhead adopta inmediatamente el punto pulsado/arrastrado y los snapshots anteriores quedan invalidados, evitando el rebote visual a la posición previa.
- Añade regresión para cambio A→B de stream manteniendo el mismo seek y refuerza el verificador estructural del Inspector.
- No modifica DSP, sonoridad, edición estructural, privacidad, red, dependencias ni motores.

## 0.15.0.0 — 2026-09-08

- Inspector multimedia pasa a módulo 0.3.0 y permite **Analizar otro archivo…** o **Cerrar análisis** sin salir de ZEUVE; un reset central de sesión detiene preview/análisis auxiliares y limpia solo el estado del archivo actual, preservando preferencias.
- El reproductor sustituye el slider temporal por una waveform bipolar centrada que actúa como scrubber. Conserva máximos positivos y mínimos negativos reales por intervalo; en multicanal preserva picos/energía sin downmix PCM susceptible a cancelación de fase.
- La waveform dispone de estilos Compacta/Equilibrada/Detallada, Picos o Picos + energía y guía central opcional. Son preferencias centralizadas y no requieren volver a decodificar para cambiar la densidad visual.
- Cambiar de pista de audio conserva la posición temporal. Waveform y espectrograma comparten playhead/seek, y los capítulos con timestamp válido pueden navegar directamente a la previsualización.
- Añade análisis de sonoridad bajo demanda con FFmpeg/EBU R128: Integrated LUFS, LRA, True Peak y Sample Peak cuando están disponibles. Es local, cancelable y reserva `OperationCoordinator` por recorrer la pista completa.
- Añade lectura técnica de `start_time` y diferencias de duración de las pistas respecto al vídeo principal o contenedor, sin convertir esos offsets en un diagnóstico automático de desincronización.
- Añade exportación explícita de informe técnico TXT/Markdown/JSON mediante publicación segura; no exporta rutas completas del origen, fingerprints ni IDs internos de preview.
- Inspector obtiene Ajustes centralizados persistidos por `SettingsRepository`: waveform, volumen/salto del reproductor, FFT/ventana/escala/rango/canal inicial, pestaña/detalle, preservación de metadatos, sufijo y contenedor preferido, con restauración propia y global.
- Corrige el flujo de limpieza tras remux, elimina la llamada duplicada de `stopPreview()` de la base 0.14 y actualiza la documentación vigente del módulo.
- No añade red, dependencias, telemetría ni reproductor universal de vídeo; esta última ampliación sigue fuera de alcance.

## 0.14.0.0 — 2026-09-08

- Inspector multimedia pasa a módulo 0.2.0 y mejora la pestaña Espectrograma con estados centrados, controles responsive, ejes temporales/frecuenciales, leyenda dB, crosshair y playhead sincronizado.
- Añade previsualización de audio local: FFmpeg decodifica el stream exacto a PCM float32 y AVAudioEngine/AVAudioPlayerNode reproduce con cola acotada, pause/reanudación, seek, saltos y volumen. Puede escuchar pistas originales y audios externos del borrador sin modificar ni publicar archivos.
- El reproductor es auxiliar de inspección: no reserva OperationCoordinator, no genera historial, no persiste PCM, no usa red y no introduce timeline, mezcla creativa, efectos ni exportación.
- La selección de canales muestra nombres L/R/C/LFE/SL/SR cuando el channel layout permite determinarlo con seguridad y conserva `Canal N` en layouts ambiguos.
- Resumen y estructura técnica muestran múltiples streams de vídeo, capítulos, attachments/attached pictures, programs y streams de datos/desconocidos; se añaden acciones locales de copiar.
- Pistas admite reproducción por fila, reordenación drag & drop con flechas como alternativa accesible y drop directo de audio/subtítulos externos pasando por la misma inspección y selección explícita existente.
- Metadatos añade búsqueda/filtro y copia por valor o grupo, manteniendo la pestaña en solo lectura.
- Se conserva intacto el planificador adaptativo, caché y DSP optimizado de 0.13.2.0. No se añaden dependencias, motores, permisos de red, telemetría ni ajustes visibles.

## 0.13.2.0 — 2026-09-08

- Inspector multimedia pasa a módulo 0.1.2. El espectrograma limita el análisis largo a ocho ventanas estratificadas por columna y conserva todos los hops al 50 % cuando el archivo cabe en ese presupuesto.
- La mezcla continúa siendo espectral por potencia. Accelerate reutiliza ventana, setup DFT, buffers reales/imaginarios y potencia; la conversión PCM usa copia alineada por bloques y conserva como máximo tres bytes residuales.
- El lector de procesos libera cada bloque de salida mediante `autoreleasepool`, evitando retener cientos de MiB de objetos `Data` al decodificar una pista larga.
- La cancelación de procesos deja de heredar `SIGTERM`/`SIGINT` bloqueadas desde workers de Swift. FFmpeg se detiene realmente, el grupo POSIX se recoge y el coordinador queda libre.
- Rango dinámico, escala lineal/logarítmica y zoom reinterpretan el modelo existente. Una caché LRU en memoria, limitada a cuatro entradas y 64 MiB, evita repetir FFmpeg/FFT para una configuración analítica idéntica e invalida por fingerprint.
- SwiftUI rasteriza el modelo fuera del actor principal y dibuja una única imagen en Canvas. El progreso determinado avanza de forma monótona durante decodificación/análisis.
- En benchmarks Release reales, el MP3 de 169,45 s mejora de 0,499 a 0,133 s; las cuatro pistas del MKV de 1.502,62 s mejoran de 4,19–4,32 s a 0,71–1,13 s. El pico del proceso de benchmark baja de unos 535 MiB a unos 29 MiB.
- Añade tests estructurales del planificador, límites de memoria, PCM desalineado, 5.1/7.1, FFT 8192/16384, cancelación y máscara de señales. No añade dependencias, motores, red, telemetría ni permisos.

## 0.13.1.0 — 2026-09-08

- Adopta para ZEUVE el versionado canónico `MAJOR.MINOR.PATCH.REVISION`. La app muestra cuatro componentes, mientras `MARKETING_VERSION` mantiene los tres exigidos por Apple y la revisión se guarda en metadata propia del bundle.
- Inspector multimedia pasa a módulo 0.1.1. La Fase 1 corrige la fidelidad de exportación del espectrograma: pantalla y PNG reutilizan exactamente el mismo mapeo lineal/logarítmico de frecuencia.
- El acumulador de PCM deja de eliminar el prefijo del array en cada hop. Mantiene índices de lectura y compacta por bloques, reduciendo movimientos de memoria durante archivos largos.
- La mezcla multicanal de visualización deja de promediar PCM y combina potencia espectral por canal, evitando que señales en oposición de fase desaparezcan artificialmente del espectrograma.
- La ventana FFT y el setup de Accelerate se preparan una sola vez por análisis en vez de reconstruirse por columna; las columnas con duración conocida se agregan directamente en un máximo acotado.
- El render SwiftUI precalcula los índices de bins por fila y reduce el cálculo repetido por píxel; la exportación rasteriza RGBA en memoria acotada antes de crear el PNG.
- Cancelar generación o exportación de espectrograma deja de presentarse como error al usuario.
- Añade regresiones para escala lineal/logarítmica, rasterización, mezcla antífasa y límite de columnas. No se añaden dependencias, red, motores ni cambios de privacidad.

## 0.13.0.1 — 2026-09-08

- El nuevo esquema clasifica como revisión técnica 0.13.0.1 la corrección mínima de Swift 6 aplicada sobre la base 0.13.0: `MultimediaInspectorTab` deja de estar aislado por `@MainActor`, mientras `MultimediaInspectorViewModel` conserva el aislamiento principal.
- El ZIP recibido con esa corrección todavía mantenía metadatos 0.13.0/build 47; la clasificación 0.13.0.1 se documenta al adoptar el nuevo sistema y no altera retroactivamente el bundle ya generado.
- No hubo cambio funcional, de privacidad, motores, archivos, red ni comportamiento visible.

## 0.13.0 — 2026-09-07

- Incorpora `Inspector multimedia` 0.1.0 como sexto módulo built-in, con icono `waveform.path.ecg`, atajo ⌘6 y sin sección visible de Ajustes. Historial pasa a ⌘7.
- Todo archivo abre en solo lectura; `Editar` crea un draft con Undo/Redo para audio/subtítulos, idioma, título, default/forced, adición, eliminación y reordenación.
- Añade remultiplexado seguro de MKV/MP4/MOV/WebM mediante plan inmutable, política de compatibilidad central, stream copy obligatorio de vídeo/audio, conversión auxiliar explícita de subtítulos, fingerprints, espacio libre, temporales, validación FFprobe y publicación sin sobrescribir originales.
- Extrae FFprobe a `ZEUVEEngines/MediaInspection` y migra el Conversor universal a la infraestructura común sin cambiar su UI, planner, códecs, formatos, defaults, historial ni comportamiento probado.
- Añade espectrograma propio: FFmpeg → PCM float32 incremental → Accelerate/vDSP → dB, con pista/canal, Hann/Hamming/Blackman–Harris, FFT size, rango dinámico, Nyquist, escala lineal/logarítmica, zoom/pan, cursor, cancelación y PNG.
- Spek 0.8.5 se estudia únicamente como referencia pública clean-room; ZEUVE no copia, porta ni incorpora Spek, wxWidgets ni código GPL.
- Añade `MultimediaInspectorPreferences` para futura integración centralizada de ajustes sin mostrar opciones persistentes en 0.13.0.
- Amplía tests y verificadores para FFprobe compartido, regresión del Conversor, draft/Undo, compatibilidad, command builder, seguridad y DSP. No se añaden dependencias, motores, APIs ni red.

## 0.12.4 — 2026-09-07

- Corrige la liberación asíncrona del `OperationCoordinator`: la UI no vuelve a estado disponible hasta que la operación pesada ha quedado realmente finalizada.
- Separa la tarea principal del Descargador de la importación de sesión de Instagram y unifica la descarga normal y el reemplazo confirmado en un único ejecutor, con progreso y cancelación coherentes.
- `ExternalProcessRunner` enlaza la cancelación de la `Task` Swift con la terminación del grupo POSIX asociado, conservando la cancelación explícita y el cierre de descendientes.
- El Analizador usa SQLite temporal como fuente principal: importa por lotes/páginas, deduplica y ordena en el store y calcula analíticas/búsquedas mediante recorridos compactos y paginados.
- La lectura ZIP del Analizador comprueba cancelación entre entradas y bloques y rechaza rutas normalizadas duplicadas, alineando implementación y documentación de seguridad.
- El Organizador deja de incluir rutas completas de usuario en logs. `LocalLogger` aplica retención de 30 días, tope global de 50 MiB y permisos 0700/0600 cuando la plataforma lo permite.
- La consulta manual de Wayback utiliza una `URLSession` efímera dedicada, sin caché ni cookies persistentes y con timeouts acotados.
- Los bookmarks de salida del Descargador y Conversor ya no se eliminan por un fallo no concluyente de resolución.
- Los fallos no críticos de inicialización del logger o del registro compartido de motores dejan una advertencia de arranque segura en lugar de quedar silenciados.
- Se amplían las regresiones de procesos, logs, bookmarks, ZIP, almacenamiento/analíticas SQLite y verificadores estructurales. No se añaden dependencias, motores, servicios, permisos ni opciones visibles.

## 0.12.3 — 2026-09-03

### Saneamiento interno de mantenibilidad — 2026-09-07

- La carga y validación común de `manifest.json` se centraliza en `ZEUVECore.ModuleManifestLoader`; cada módulo conserva su resolución de bundle y su error específico cuando falta el recurso.
- Las claves persistentes del Organizador se agrupan en `OrganizerStorageKeys`, manteniendo exactamente `organizer.defaultOptions`, `organizer.lastFolder`, `organizer.recentFolders` y la clave legacy `organizer.options`. La clave de apariencia también se centraliza sin cambiar `appearance.theme`.
- La ayuda contextual de la aplicación mantiene los mismos componentes y textos, pero los temas se distribuyen por General, Organizador, Descargador universal y Analizador de chats; el Conversor conserva su archivo específico existente.
- `UniversalDownloadService` deja de etiquetar como YouTube los logs de coordinación universal y usa las categorías `universal-downloader` y `universal-downloader-performance`. No cambian los datos registrados, la red, los motores ni el comportamiento de descarga.
- Se regeneran el proyecto Xcode y las regresiones estructurales afectadas sin añadir dependencias ni modificar IDs, ajustes persistidos o formatos.

### Infraestructura compartida y política de historial — Fase 2 — 2026-09-07

- `ZEUVECore` incorpora la mecánica común de bookmarks de carpetas y acceso `security-scoped`; Descargador y Conversor conservan sus stores, claves persistentes y validadores propios, pero dejan de duplicar el codec y el ciclo de acceso del sistema.
- Se establece una política común de persistencia secundaria: si una operación principal termina correctamente y falla únicamente el guardado del historial, el resultado sigue siendo correcto y ZEUVE muestra un aviso específico en vez de convertir toda la operación en fallida.
- Organizador, Descargador universal, Conversor universal, Analizador de chats y Comparador de seguidores aplican la misma política. Los logs del fallo de historial guardan únicamente el tipo técnico del error, sin rutas, contenidos, URLs, credenciales ni datos privados.
- En el Organizador, un historial no persistido implica únicamente que esa ejecución no puede ofrecer «Deshacer» mediante un registro inexistente; los archivos ya organizados no se revierten ni se consideran fallidos.
- `OperationCoordinator` mantiene los flujos existentes, pero se documenta una regla única para nuevos módulos: debe existir un solo propietario del ciclo de cada operación y este debe garantizar liberación/cancelación aunque fallen tareas secundarias como historial o logging.
- Se añaden regresiones para el codec compartido y la política de historial sin nuevas dependencias, migraciones ni cambios de esquema SQLite.

### Integración central de módulos built-in — Fase 3 — 2026-09-07

- `ZEUVEApp` incorpora `BuiltInModuleCatalog` como fuente única para la identidad de los cinco módulos oficiales, aliases legacy, orden de navegación existente, presencia en Ajustes, comandos/atajos y presenters de historial.
- `AppModel` registra los manifiestos recorriendo el catálogo; `RootView`, `DashboardView`, `SettingsView` y el menú de comandos dejan de mantener listas paralelas de módulos.
- `AppDestination` representa las herramientas mediante `module(BuiltInModuleID)` y dos routers exhaustivos concentran la creación de la vista principal y del contenido de Ajustes. Los ViewModels concretos permanecen tipados y propiedad de `AppModel`.
- La aplicación raíz deja de inyectar globalmente cinco ViewModels y el historial; cada herramienta recibe su modelo desde el router y el historial recibe el suyo únicamente cuando se abre.
- La compatibilidad de historial con `com.zeuve.youtube-downloader` pasa a los aliases del catálogo y `GlobalHistoryViewModel` combina identificadores de forma genérica, sin un caso especial de YouTube.
- Si un manifiesto built-in no puede cargarse o registrarse, ZEUVE conserva el aviso de arranque pero no ofrece ese módulo en Inicio, barra lateral, Ajustes ni comandos.
- Se preservan los órdenes visibles ya existentes en cada superficie y los atajos ⌘1–⌘5; no se añade personalización, ocultación manual ni reordenación de módulos.
- `Package.swift` y la lista de productos enlazados del generador Xcode siguen siendo explícitos porque representan dependencias reales de compilación; los Swift nuevos de `ZEUVEApp` sí se descubren automáticamente.

### Saneamiento por responsabilidades — Fase 4 — 2026-09-07

- `ChatAnalyzerResultsView.swift` queda como coordinador de resultados y las secciones de filtros, resumen, actividad, participantes, palabras, búsqueda, conversaciones, respuestas, comparación y fusiones se distribuyen en `ZEUVEApp/ChatAnalyzer/Results` sin modificar textos, cálculos ni composición visible.
- `UniversalConverterModels.swift` se sustituye por archivos de modelos agrupados por formatos, operaciones, ajustes, opciones, presets, entradas, planificación, resultados y progreso. Se conservan los mismos tipos públicos, claves `Codable`, migraciones y formatos persistidos.
- `ChatAnalytics` conserva su API pública y sus algoritmos, pero la implementación se separa por modelos, núcleo, actividad, participantes, palabras, conversaciones, búsqueda, snapshots, soporte y tokenización. No cambian caches, invalidaciones, resultados ni cancelación.
- El soporte privado de diagnóstico/progreso de FFmpeg se extrae de `UniversalConverterExecutionService` sin alterar ejecución, argumentos, publicación, validación ni cancelación.
- La tarjeta de ajustes del Descargador se extrae de `UniversalDownloaderView.swift` a una vista propia, conservando exactamente opciones, textos, bindings y comportamiento.
- Los ViewModels grandes de Descargador, Analizador y Conversor se revisan expresamente y se mantienen íntegros: no se fragmentan solo por número de líneas cuando ello obligaría a ampliar estado privado o dispersar el ciclo de tareas/cancelación.
- Los verificadores estructurales pasan a agregar las nuevas fuentes por responsabilidad y se añaden regresiones para impedir que reaparezcan los monolitos eliminados. No se añaden funciones visibles, dependencias, red, motores, migraciones ni cambios de versión.

### Saneamiento de QA y verificadores — Fase 5 — 2026-09-07

- `Scripts/verify_project.sh` pasa de un verificador monolítico de 946 líneas a un orquestador de 45 líneas; conserva el mismo comando público y delega las comprobaciones en verificadores Python por aplicación, estructura, motores, documentación, rendimiento y módulo.
- Los 23 bloques Python embebidos de la Fase 4 se conservan íntegramente en los nuevos verificadores; no se elimina ninguna protección existente al reorganizarlos.
- Se añade una comprobación automática de coherencia entre los productos de biblioteca declarados en `Package.swift`, la lista enlazada por `Scripts/generate_xcode_project.py` y las dependencias de paquete presentes en `ZEUVE.xcodeproj`.
- `Scripts/verify_app_macos.sh` concentra la validación real de la app en macOS Apple Silicon: motores, regeneración Xcode, coherencia SwiftPM/Xcode y `xcodebuild` ARM64 completo. Fuera de esa plataforma informa de la omisión sin simular una validación.
- El parseo de `Sources/ZEUVEApp` se convierte en una etapa explícita reutilizable que recorre automáticamente todos sus Swift, evitando listas de archivos manuales.
- La comprobación de sintaxis Python se amplía desde una lista fija a todos los scripts y tests Python mediante `compileall`. Se añaden cinco regresiones del propio sistema de verificación, incluida la detección de un producto SwiftPM olvidado en Xcode.
- Se revisan los tests Swift grandes y se mantienen agrupados cuando compartir fixtures/helpers privados hace que dividirlos sea una separación artificial. No cambia ningún Swift de producción, manifiesto, motor, dependencia, persistencia ni comportamiento visible.

### Restablecimiento global de ajustes — 2026-09-07

- Ajustes > General incorpora una acción confirmada para restaurar los valores de fábrica de toda la aplicación sin borrar historial, preajustes, favoritas, perfiles personalizados, carpetas recientes, motores ni archivos del usuario.
- El restablecimiento global devuelve el tema a Sistema y restaura los valores predeterminados del Organizador, Descargador universal, Analizador de chats y Conversor universal.
- El Descargador conserva los perfiles personalizados y los presets, pero restablece los perfiles incorporados, elimina la sesión de Instagram recordada del Llavero y olvida la carpeta de salida persistida, incluida la clave legacy de `youtubeDownloader`.
- El Conversor conserva preajustes y favoritas, pero olvida la carpeta de salida recordada. El botón queda desactivado mientras existe una operación activa.
- Los fallos de persistencia se acumulan por área: un error aislado no impide restaurar los demás ajustes y se comunica al usuario al finalizar.

### Correcciones prioritarias

- El arranque de `AppModel` es idempotente: registrar módulos, cargar estados y crear el observador de operaciones solo ocurre una vez, evitando duplicados si SwiftUI vuelve a ejecutar la tarea inicial.
- Los errores de almacenamiento y registro de módulos se acumulan en lugar de sobrescribirse, de modo que el diagnóstico inicial conserva todas las causas relevantes.
- El historial global consulta SQLite, decodifica y ordena fuera de `MainActor`; la interfaz solo publica el resultado vigente y mantiene cancelación, filtros y compatibilidad con el historial legacy de YouTube.
- Los fallos al guardar el tema y los valores persistentes principales del Organizador dejan de silenciarse y se comunican en la interfaz.
- Los módulos Descargador universal, Analizador de chats y Comparador de seguidores devuelven errores específicos de manifiesto cuando falta `manifest.json`.
- Se elimina el caso muerto `activeOrUpcomingLive` y su texto obsoleto de la versión 0.6.0.

### Descargador universal 0.7.3

- Todos los perfiles incorporados, incluido YouTube, parten de `Original`, máxima calidad disponible y contenedor automático; el usuario conserva las opciones manuales de vídeo, audio y conversión.
- El esquema de perfiles sube a 2 y migra únicamente el antiguo perfil de fábrica de YouTube MP3 320 kb/s; cualquier configuración personalizada se conserva.
- El fallback de navegador opcional se retira temporalmente de la interfaz y del routing porque no tenía un contrato ejecutable completo. La clave legacy se sigue decodificando, se normaliza a `false` y no se añade Playwright ni ningún motor nuevo.
- La versión y el identificador HTTP de ZEUVE se obtienen desde información centralizada del producto, eliminando literales de User-Agent obsoletos.

### Saneamiento y validación

- `Scripts/clean_project.py` queda documentado como herramienta oficial de limpieza manual, siempre en simulación salvo `--apply`, sin tocar `Resources/Engines`.
- Se añaden pruebas del script, migraciones de perfiles/preferencias y routing sin navegador.
- ZEUVE se eleva a 0.12.3, build interno 45; Descargador universal a 0.7.3.

## 0.12.2 — 2026-09-02

### Saneamiento interno del Descargador universal

- El target y producto Swift pasan de `YouTubeDownloaderModule` a `UniversalDownloaderModule`; aplicación y tests utilizan también la nomenclatura universal.
- Los tipos que coordinan todo el módulo adoptan nombres universales, mientras los componentes propios de yt-dlp se identifican como `YTDLP*` y la lógica genuina de YouTube permanece bajo `Platforms/YouTube`.
- El módulo se reorganiza por análisis, descarga, modelos, motores, plataformas, publicación, archivos, almacenamiento, validación y descubrimiento, sin crear nuevos targets ni dependencias.
- El ViewModel delega persistencia/migración, construcción del plan y sesión de Instagram; análisis y descarga extraen adaptadores/políticas concretos conservando el orden de routing y fallback.
- La vista y los ajustes se separan en archivos mantenibles sin cambios visuales ni nuevas opciones.

### Compatibilidad y seguridad

- Se conservan exactamente las claves legacy `youtube.*`/`youtubeDownloader.*`, el identificador histórico `com.zeuve.youtube-downloader`, la clave Codable `videoID` y la ruta temporal histórica necesaria.
- No cambian motores, argumentos, red, cookies/sesiones, privacidad, DRM/CAPTCHA/paywalls, publicación segura, `OperationCoordinator`, formatos, presets ni historial.
- No se añaden dependencias externas.

### Versión y pruebas

- ZEUVE se eleva a 0.12.2, build interno 44; Descargador universal a 0.7.2.
- Se añaden regresiones de claves legacy, migración de defaults/modo avanzado y compatibilidad Codable del catálogo.
- Se corrige el script opcional `run_youtube_integration_tests_macos.sh` para usar su workspace temporal real al configurar la caché de yt-dlp, evitando el aborto por variable no definida bajo `set -u`.
- La regresión de diagnóstico ejecutable de yt-dlp se limita explícitamente a macOS Apple Silicon, evitando un falso fallo de la suite en plataformas donde ese diagnóstico está diseñado para devolver `unsupportedPlatform`.

## 0.12.1 — 2026-09-01

### Corrección de «Mejor calidad compatible»

- El preset incluido pasa a usar «Original sin convertir» para conservar fotos, vídeos y audio en el formato servido por cada origen.
- Los presets específicos «Vídeo 1080p», «Vídeo 720p» y «Vídeo con subtítulos en español» mantienen expresamente el modo Vídeo.
- El esquema de presets sube a 3 y migra únicamente la configuración incluida antigua de «Mejor calidad compatible» cuando todavía conserva su firma de vídeo genérico.
- Los identificadores, favoritos y presets personales se conservan; una configuración personalizada con resolución concreta no se sobrescribe.

### Versión y pruebas

- ZEUVE se eleva a 0.12.1, build interno 43; Descargador universal a 0.7.1.
- Se añaden regresiones de valores incluidos, migración persistente y protección de presets personalizados.

## 0.12.0 — 2026-09-01

### Perfiles de descarga controlados por el usuario

- «Por defecto de la plataforma» deja de depender de valores fijados únicamente en código: cada plataforma incorporada dispone de un perfil editable y restaurable desde Ajustes > Descargador universal > Plataformas.
- Los valores de fábrica se conservan solo como punto de restauración: YouTube empieza en MP3 a 320 kb/s y el resto de plataformas en contenido original de máxima calidad.
- Se añade el modo manual «Original», que prevalece expresamente sobre cualquier perfil automático.
- Las operaciones guardan una instantánea de los ajustes resueltos por elemento, por lo que un lote mixto respeta perfiles diferentes y no cambia si el usuario edita Ajustes mientras descarga.

### Plataformas personalizadas y privacidad

- El usuario puede crear una regla desde un enlace de ejemplo o un dominio, asignarle un nombre, incluir o excluir subdominios, desactivarla, editar sus ajustes o eliminarla.
- Solo se persiste el dominio normalizado: rutas, consultas, fragmentos, tokens y URLs multimedia firmadas se descartan.
- Las reglas se comparan contra el origen estable de la página y gana el dominio específico más largo. La prioridad final es: elección manual, regla personalizada, perfil incorporado, perfil de página y valores de fábrica.
- Credenciales, cookies, proxy, carpeta de salida y selecciones exactas de pistas continúan siendo decisiones temporales de cada operación.

### Versión y pruebas

- ZEUVE se eleva a 0.12.0, build interno 42; Descargador universal a 0.7.0.
- Se añaden regresiones de restauración, migración, persistencia, normalización privada de URLs, subdominios, precedencia y resolución por elemento.

## 0.11.5 — 2026-09-01

### Instagram como ruta específica del descargador universal

- Las URLs directas `/p/`, `/reel/` y `/reels/` priorizan `instaloader-zeuve 4.15.3-zeuve.2` sin sesión; `gallery-dl`, `yt-dlp` y el descubrimiento genérico permanecen como respaldos aislados.
- El adaptador enumera todos los nodos de un sidecar y conserva fotos y vídeos en su formato real. La extensión se obtiene de la URL del CDN y el descargador confirma el tipo entregado mediante `Content-Type`.
- Una sesión solo se intenta después de agotar las rutas públicas razonables y únicamente cuando Instagram confirma contenido privado; los errores ambiguos de login, límite o HTTP 403 no fuerzan autenticación.
- La validación real cubre una foto, un vídeo, un Reel, un carrusel de 5 fotos y un carrusel mixto de 19 elementos (17 fotos y 2 vídeos): 27 archivos descargados, 0 pérdidas y 0 conversiones.

### Automático por plataforma

- El modo predeterminado pasa a ser «Automático por plataforma» y se resuelve individualmente en lotes mixtos.
- YouTube selecciona audio MP3 a 320 kb/s por defecto; cualquier otra plataforma o página conserva el contenido original de máxima calidad.
- Las opciones manuales «Vídeo» y «Solo audio» siguen disponibles y prevalecen cuando el usuario las elige.

### Versión y pruebas

- ZEUVE se eleva a 0.11.5, build interno 41; Descargador universal a 0.6.9.
- Se añaden regresiones del enrutado, sidecars mixtos, política automática por elemento y formato real entregado por CDN.

## 0.11.4 — 2026-08-27

### Instagram público sin sesión

- Los enlaces concretos públicos de Instagram se analizan primero con `yt-dlp` y después con `gallery-dl`, siempre sin cookies ni sesión.
- Una sesión configurada solo se aplica al elemento cuando el análisis confirma contenido privado o autenticación necesaria; los errores ambiguos de rate limit o redirección a login ya no fuerzan el inicio de sesión.
- Se actualiza la distribución oficial incluida de yt-dlp a 2026.08.19 y se registran de nuevo el hash del ejecutable y la integridad del árbol completo.
- El reel público `DcWzMFPuXtg` se descargó realmente sin cookies y se validó con FFprobe.

### Versión, entrega y pruebas

- ZEUVE se eleva a 0.11.4, build interno 40; Descargador universal a 0.6.8.
- Se añaden regresiones de enrutado, privacidad de sesión y clasificación de errores privados frente a fallos públicos ambiguos.
- El proyecto pasa a mantenerse siempre en una única carpeta activa; no se crea un ZIP ni otra carpeta con un nombre de versión salvo petición expresa.

## 0.11.3 — 2026-08-22

### Descarga fiable de TikTok

- Una ejecución de `gallery-dl` ya no se considera correcta por su código de salida: debe haber generado al menos un archivo candidato.
- Si `gallery-dl` falla o termina sin archivos en un enlace concreto de TikTok, ZEUVE limpia el espacio temporal y reintenta la URL pública estable con el `yt-dlp` incluido.
- El respaldo vuelve a comprobar tanto el proceso como la existencia de archivos antes de publicar, evitando falsos éxitos y restos parciales.
- Cuando ambos motores fallan, el resumen muestra explícitamente que no se guardó ningún archivo, conserva una referencia técnica saneada y ofrece abrir los registros.
- No se añaden dependencias, servicios, APIs, permisos ni cambios al binario fijado de `gallery-dl`.

### Versión y pruebas

- ZEUVE se eleva a 0.11.3, build interno 39; Descargador universal a 0.6.7.
- Se añaden regresiones con el enlace reportado `7675703483303071009` para la política de respaldo, la URL estable, el error de salida vacía y el estado de fallo total.

## 0.11.2 — 2026-08-22

### Descargador universal y TikTok

- TikTok usa `gallery-dl` como motor principal para enlaces concretos de vídeo y foto; yt-dlp queda como respaldo.
- Se corrigen las opciones vigentes `--config-ignore` y `--http-timeout`, y el parser adopta los mensajes Directory=2, URL=3 y Queue=6 de gallery-dl 1.32.9 sin perder compatibilidad heredada.
- La descarga conserva la URL pública estable y selecciona cada elemento con `--range`, permitiendo que gallery-dl renueve URLs temporales y pruebe fallbacks del CDN ante HTTP 403.
- gallery-dl e instaloader-zeuve pasan a ser motores obligatorios del paquete; Terminal y Xcode detienen la compilación si faltan o están obsoletos.
- Los binarios sociales firmados reciben una excepción de validación de bibliotecas limitada a sus procesos PyInstaller; la aplicación principal conserva Hardened Runtime sin esa excepción.
- Se mantienen en memoria las referencias multimedia efímeras y se evita guardar URLs firmadas, cookies, tokens o cabeceras privadas.

### Versión y pruebas

- ZEUVE se eleva a 0.11.2, build interno 38; Descargador universal a 0.6.6.
- El TikTok público `7661387983458700566` se analizó y descargó sin sesión; FFprobe confirmó MP4 H.264/AAC, 576×1024 y 15 segundos.
- Se añaden regresiones de clasificación, enrutado, protocolo gallery-dl, opciones de comando y política de motores sociales.

## 0.11.1 — 2026-08-21

### YouTube público sin sesión

- El análisis y la descarga anónimos de YouTube usan automáticamente los clientes públicos `web_embedded,web_safari` del yt-dlp incluido.
- La descarga vuelve a resolver el enlace estable de YouTube y deja de reutilizar la URL multimedia firmada obtenida durante el análisis, evitando el HTTP 403 observado en la transferencia completa.
- Los errores HTTP 403 y los avisos de PO token ya no indican por sí solos que el usuario tenga que activar una sesión del navegador.
- Las sesiones siguen disponibles como opción expresa para contenido realmente restringido; `cookies.txt` mantiene prioridad.
- Deno conserva su firma oficial y sus autorizaciones JIT al empaquetarse; la verificación ejecuta JavaScript real para impedir que una firma incompleta vuelva a inutilizar los desafíos de YouTube.
- La compilación por Terminal limpia el producto anterior y comprueba la firma profunda de la aplicación final.

### Versión y pruebas

- ZEUVE se eleva a 0.11.1, build interno 37; Descargador universal a 0.6.5.
- Se añaden regresiones para la cadena pública en análisis y descarga, su ausencia cuando existe una sesión explícita y la nueva clasificación de errores.
- La corrección se verifica con el enlace público `BM1evFP2fds` sin cookies ni sesión del navegador.

## 0.11.0 — 2026-08-06

### Correcciones locales del Descargador — 2026-08-21

- Se corrige el diagnóstico de `yt-dlp` universal para que las cabeceras ARM64 de `otool` no se interpreten como dependencias ausentes.
- Se añade una opción explícita y temporal para usar la sesión de Safari, Chrome, Firefox, Brave, Edge, Arc, Chromium, Opera o Vivaldi durante el análisis y la descarga.
- La sesión del navegador permanece desactivada por defecto, no se guarda en ajustes, presets, historial o registros y queda oculta en los argumentos técnicos.
- Los bloqueos `HTTP 403`, los requisitos de sesión de YouTube y los errores de permiso de cookies muestran ahora acciones concretas en lugar de indicar que el contenido es incompatible.
- `cookies.txt` seleccionado manualmente conserva prioridad sobre la sesión del navegador.

### Eliminación de Calibre y libros electrónicos

- Calibre se elimina del código, localizador, diagnóstico, registro de motores, preparación, firma, verificación, recursos y empaquetado.
- El Conversor deja de ofrecer EPUB, MOBI, AZW/AZW3 y FB2 como entrada o salida de conversión.
- Los ebooks siguen detectándose para mostrar un mensaje claro de formato no compatible.
- El Organizador conserva sus reglas de clasificación de libros electrónicos.
- Pandoc se mantiene para conversiones entre TXT, Markdown y HTML; deja de aceptar EPUB.

### Eliminación de Ghostscript y EPS

- Ghostscript, su licencia, recursos y constructor de comandos se eliminan completamente.
- EPS se mantiene como formato reconocible, pero se rechaza de forma explícita y ya no se ofrece como conversión.
- Los scripts de preparación, firma y verificación impiden reintroducir Calibre o Ghostscript por accidente.

### Limpieza, versión y pruebas

- Se retiran residuos `.DS_Store`, `._*` y `__MACOSX` del proyecto fuente.
- ZEUVE se eleva a 0.11.0, build interno 36; Conversor universal a 0.3.0.
- Se añaden regresiones para la matriz de compatibilidad, el escáner, Pandoc y el manifiesto de motores.
- Las referencias históricas de versiones anteriores se conservan en sus informes y entradas de changelog.

## 0.10.4 — 2026-08-06

### Corrección de perfiles públicos de Instagram

- Instaloader se actualiza de 4.15.2 a 4.15.3, versión oficial que corrige la resolución de perfiles públicos.
- El ayudante pasa a `instaloader-zeuve 4.15.3-zeuve.1` y la compilación rechaza cualquier revisión 4.15.2 anterior.
- Se retira del ZIP fuente el ejecutable ARM64 obsoleto para evitar que vuelva a empaquetarse; `build_macos.sh` y la fase previa de Xcode lo regeneran en macOS Apple Silicon.
- `gallery-dl` continúa como fallback público y no cambia el tratamiento de perfiles privados, Stories, Destacadas o sesiones.
- No se añaden servidores, proxies, APIs ni dependencias para el usuario final.

### Versionado y pruebas

- ZEUVE elevada a 0.10.4, build interno 35; Descargador universal elevado a 0.6.4.
- Se actualizan las regresiones de preparación para comprobar que `4.15.2-zeuve.3` se rechaza como obsoleto y que el manifiesto se actualiza a `4.15.3-zeuve.1`.
- La generación, firma, apertura y prueba real del motor ARM64 actualizado siguen requiriendo macOS Apple Silicon.

## 0.10.3 — 2026-08-05

### Perfiles públicos de Instagram

- Los perfiles públicos dejan de solicitar una sesión como requisito general.
- Publicaciones, reels y foto de perfil se analizan y descargan sin sesión cuando están disponibles públicamente.
- Stories y Destacadas se omiten sin sesión y aparecen como secciones no disponibles, sin bloquear el resto del catálogo.
- Una consulta anónima bloqueada, limitada o no concluyente ya no abre automáticamente la tarjeta de autenticación ni se interpreta como perfil privado.
- Si una sesión aportada no se valida, el ayudante repite la consulta de perfil con una sesión anónima limpia.
- El fallback público a `gallery-dl` se mantiene y marca Stories y Destacadas como restringidas cuando resuelve el perfil sin sesión.

### Motor, interfaz y pruebas

- El ayudante se eleva a `instaloader-zeuve 4.15.2-zeuve.3` para impedir reutilizar la lógica anterior.
- El modelo diferencia las secciones disponibles de las secciones restringidas por autenticación.
- La interfaz muestra un aviso informativo para Stories y Destacadas, sin campo de sesión obligatorio.
- Se añaden regresiones Swift y Python para perfiles públicos, sesiones inválidas, omisión de Stories/Destacadas y compatibilidad con errores anteriores.

### Versionado

- ZEUVE elevada a 0.10.3, build interno 34; Descargador universal elevado a 0.6.3.
- La generación, firma y prueba real del binario ARM64 actualizado sigue requiriendo macOS Apple Silicon.

## 0.10.2 — 2026-08-05

### Corrección funcional de Instagram

- Instaloader ya no convierte una consulta vacía o bloqueada en una afirmación de que el perfil no existe.
- Los perfiles no comprobables, las sesiones no validadas y los bloqueos temporales devuelven un estado de autenticación reutilizable por la interfaz.
- El flujo especial de perfiles ejecuta realmente `gallery-dl` como fallback y registra qué motor resolvió o rechazó la consulta.
- Stories y otros contenidos de Instagram que requieren autenticación muestran la tarjeta de sesión en lugar de terminar solo con un error genérico.
- Los registros añaden únicamente `sesion_aportada`, `sesion_validada`, motor, fallback y clasificación, sin guardar credenciales ni nombres de cuenta.

### Motor y compilación

- El ayudante se eleva a `instaloader-zeuve 4.15.2-zeuve.2`.
- Se elimina de la copia fuente el ejecutable 4.15.2-zeuve.1 para impedir que vuelva a empaquetarse por accidente.
- `build_macos.sh` y la fase previa de Xcode detectan motores ausentes u obsoletos y regeneran la revisión aprobada antes de copiar recursos.
- Se añaden regresiones Swift y Python para el registro real aportado, sesión rechazada, error ambiguo, fallback y protección de compilación.

### Versionado

- ZEUVE elevada a 0.10.2, build interno 33; Descargador universal elevado a 0.6.2.
- La generación, firma y prueba real del binario ARM64 actualizado sigue requiriendo macOS Apple Silicon.

## 0.10.1 — 2026-08-05

### Corrección de Instagram

- Corregida la detección de perfiles, publicaciones, reels y stories de Instagram cuando el usuario selecciona «Página web»; la plataforma y el tipo de contenido ya no se degradan a una página genérica.
- Los fallos del catálogo de perfiles se registran con el motor y el motivo real, incluso cuando `instaloader-zeuve` no está disponible.
- Los errores de autenticación de Instagram muestran una acción concreta para pegar una sesión temporal o seleccionar `cookies.txt`, sin registrar su contenido.
- El diagnóstico previo al análisis informa si `gallery-dl` y `instaloader-zeuve` están realmente disponibles.

### Preparación y empaquetado de motores

- `build_macos.sh` detecta los marcadores vacíos y prepara automáticamente `gallery-dl 1.32.9` e `instaloader-zeuve 4.15.2-zeuve.1` antes de verificar y compilar.
- La preparación limpia binarios sociales anteriores, valida sus versiones y actualiza en `engines.json` los tamaños, SHA-256 y rutas de licencia reales.
- El proyecto Xcode incorpora una fase previa que impide copiar una carpeta `Engines` incompleta; indica que debe usarse `build_macos.sh` o prepararse los motores expresamente.
- Se añaden regresiones para clasificación de Instagram en modo Página web, mensajes de sesión y política de preparación/registro de motores.

### Versionado

- ZEUVE elevada a 0.10.1, build interno 32; Descargador universal elevado a 0.6.1.
- La generación y validación final de los ejecutables ARM64 continúa requiriendo macOS Apple Silicon.

## 0.10.0 — 2026-08-05

### Descargador universal 0.6.0

- Arquitectura multimotor con enrutado específico por plataforma y extractor genérico de respaldo.
- Soporte específico inicial para YouTube, Instagram, TikTok, Pinterest, X/Twitter, Facebook, Reddit, Twitch, Vimeo, Dailymotion, SoundCloud, Tumblr, Threads, Snapchat público y EroMe mediante enlaces concretos cuando corresponda.
- Instagram admite nombres de usuario, perfiles, publicaciones, reels, stories, historias destacadas, carruseles y foto de perfil actual en la mayor resolución accesible.
- Catálogo progresivo de Instagram con cuadrícula o lista, secciones configurables, miniaturas ajustables, selección individual, carga incremental e historial de elementos descargados.
- Perfiles privados mediante sesión autorizada pegada, `cookies.txt` o importación expresa desde navegador; temporal por defecto y opcionalmente protegida por el Llavero de macOS.
- Descarga directa de fotografías y archivos multimedia sin recomprimirlos, con validación antes de publicar y estructura de carpetas configurable.
- Historial local opcional de fotos de perfil y búsqueda manual de imágenes anteriores mediante Wayback Machine, dejando claro que no se garantizan resultados.
- Control de contenido adulto desactivado por defecto, bloqueo previo a miniaturas y análisis, dominios adicionales configurables y acceso directo a Ajustes.
- EroMe se admite únicamente mediante enlaces concretos y exige activar previamente el contenido adulto.
- Los directos activos o programados permanecen excluidos en todas las plataformas.
- Motores adicionales `gallery-dl` e `instaloader-zeuve` preparados como binarios ARM64 opcionales; navegador automatizado preparado como componente externo opcional y último recurso.
- Gestión avanzada de motores externos en `Application Support`, con versiones estables o experimentales, advertencia obligatoria también para estables y restauración del motor incluido.
- Archivos JSON/TXT auxiliares opcionales con metadatos sanitizados; nunca incluyen cookies, sesiones, contraseñas o cabeceras privadas.

### Reglas, documentación y pruebas

- Nueva regla permanente: utilizar el motor más adecuado para cada fuente, con información y aprobación previa cuando implique una dependencia o cambio importante.
- ZEUVE elevada a 0.10.0, build interno 31; Descargador universal elevado a 0.6.0.
- 158 pruebas XCTest/Swift, 45 pruebas Swift Testing y 32 pruebas Python superadas en Linux x86_64.
- Pendientes la preparación de los nuevos motores ARM64, la compilación Xcode, la firma, la apertura y las pruebas reales de interfaz/red en macOS Apple Silicon.

## 0.9.2 — 2026-08-04

### Rendimiento del Descargador universal

- Los vídeos descubiertos dentro de una página conservan temporalmente en memoria la URL multimedia o el manifiesto resuelto durante el análisis y lo reutilizan al descargar, evitando volver a analizar la página cuando sigue siendo válido.
- Las URLs firmadas y sus cabeceras necesarias no se codifican, no se guardan en historial, ajustes o presets y no se escriben en los registros.
- Si la referencia resuelta ha caducado o falla, ZEUVE limpia únicamente el temporal propio y vuelve a resolver ese vídeo mediante su URL estable.
- Las descargas HLS/DASH comienzan con 16 fragmentos simultáneos y reducen automáticamente a 8, 4 o 1 solo cuando el servidor o la red indican limitación; el nivel estable se reutiliza durante la operación.
- Los archivos se publican mediante movimiento atómico cuando temporales y destino pertenecen al mismo volumen, evitando una segunda lectura y escritura completa; entre volúmenes se mantiene la copia segura verificada.
- La validación de procedencia y la validación multimedia se reutilizan para evitar dos ejecuciones consecutivas de FFprobe sobre el mismo archivo.
- Se añaden fases reales de conexión, descarga, procedencia, verificación y publicación, junto con tiempos, primer byte y bytes transferidos en logs locales minimizados.

### Versionado y pruebas

- ZEUVE elevada a 0.9.2, build interno 30; Descargador universal elevado a 0.5.2.
- Añadidas regresiones para referencias efímeras, privacidad, cabeceras, descarga directa, reducción adaptativa y publicación por movimiento en el mismo volumen.

## 0.9.1 — 2026-08-04

### Descargador universal

- Los vídeos encontrados al analizar una página se descargan en su mejor calidad original, sin recodificación, límite de resolución, extracción de audio, formato forzado, subtítulos ni archivos auxiliares.
- Las opciones completas continúan disponibles para enlaces directos y colecciones introducidas directamente; las operaciones mixtas aplican la política adecuada a cada elemento.
- Se eliminan IDs técnicos de los nombres de vídeos descubiertos en páginas.
- Cuando varios vídeos comparten el mismo título, se numeran todos consecutivamente desde `(1)`, incluido el primero.
- Se añade procedencia opcional dentro de los metadatos del archivo mediante copia directa de flujos, con URL saneada, dominio e ID de página.
- La fecha de descarga es opcional y el atributo «De dónde» de macOS puede activarse de forma independiente.
- Las opciones de procedencia están desactivadas por defecto y disponen de ayuda contextual.
- Red, proxy, reintentos, cookies y registros siguen accesibles aunque todos los elementos seleccionados procedan de una página.

### Versionado y pruebas

- ZEUVE elevada a 0.9.1, build interno 29; Descargador universal elevado a 0.5.1.
- Añadidas regresiones para política original, operaciones directas, nombres, procedencia, privacidad y compatibilidad de ajustes.

## 0.9.0 — 2026-08-04

### Descargador universal

- El antiguo Descargador de YouTube se amplía a Descargador universal 0.5.0.
- El identificador pasa a `com.zeuve.universal-downloader`, con lectura y migración de ajustes, presets, bookmark e historial del identificador anterior.
- Se admiten enlaces individuales, colecciones, archivos multimedia directos y páginas concretas con varios vídeos.
- La detección combina yt-dlp con inspección HTML de `video`, `source`, `iframe`, metadatos, JSON-LD, HLS y DASH.
- La inspección se limita a la URL introducida; no rastrea subpáginas ni añade un navegador automatizado.
- Los duplicados seguros del análisis actual se omiten antes de descargar. Las coincidencias dudosas se muestran como `Posible duplicado`.
- Los elementos reconocidos en el historial aparecen como `Ya descargado`, desmarcados inicialmente pero seleccionables.
- Los registros se crean desde el inicio del análisis y se escriben progresivamente con minimización de datos.
- Se valida el contenido de `cookies.txt` como formato Netscape.
- Se elimina la carga remota directa de miniaturas desde SwiftUI.
- Se añade una opción avanzada para permitir expresamente HTTP y direcciones de la red local; permanece desactivada por defecto.
- Se corrige el patrón `Lista, índice y título` para crear una carpeta de colección diferenciada.
- Los errores de análisis conservan una explicación útil en lugar de sustituirse siempre por un mensaje genérico.

### Versionado y documentación

- ZEUVE elevada a 0.9.0, build interno 28.
- Documentación, decisiones, manifiesto, proyecto Xcode y pruebas actualizados.

## 0.8.0 — 2026-08-03

### Añadido
- Nuevo módulo oficial `com.zeuve.instagram-followers` 0.1.0.
- Importación del ZIP completo de Instagram o de JSON separados, incluyendo varios `followers_<número>.json`.
- Catálogo previo, lectura ZIP selectiva y validaciones de rutas, enlaces, cifrado, duplicados, tamaño, profundidad y compresión.
- Parser flexible para las estructuras actuales y heredadas aprobadas de Meta.
- Comparación normalizada en cuentas que no siguen de vuelta, seguidores no seguidos y seguimiento mutuo.
- Resultados con búsqueda diferida, ordenación, apertura externa manual y exportación TXT/CSV.
- Historial global agregado sin nombres de usuario, búsquedas, rutas ni URLs.
- 21 pruebas XCTest específicas y cinco regresiones Python de integración y privacidad.

### Integración
- Registro en SwiftPM, proyecto Xcode, AppModel, sidebar, dashboard, comandos, cierre seguro e historial global.
- Nueva guía `Docs/Modulos/Funcionales/INSTAGRAM_FOLLOWERS_COMPARATOR.md`.
- ZEUVE elevada a 0.8.0, build interno 27.

### Corregido
- La versión mostrada en Ajustes se alinea con 0.8.0 (27); el archivo anterior aún indicaba 0.7.1 (22).
- La documentación de arquitectura vuelve a enumerar correctamente el Conversor universal dentro de Ajustes.

## 0.7.5 — 2026-07-30

### Conversión real de vídeo
- El modo simple recodifica siempre la pista de vídeo; MP4 con códec automático utiliza H.264 y ya no puede resolverse como copia exacta o remux silencioso.
- La copia rápida sin recodificación permanece como opción avanzada explícita y desactivada por defecto, con ayuda y vista previa que explican que no reduce tamaño ni cambia calidad.
- Los ajustes persistentes migran de esquema 3 a 4 y el preajuste oficial `Vídeo MP4 compatible` pasa a recodificación; los preajustes personalizados se conservan.
- FFprobe verifica el códec de las salidas recodificadas antes de publicarlas.

### Vídeo a fotogramas
- Los fotogramas se escriben directamente en una carpeta visible `Procesando` dentro del destino y se publica mediante renombrado en el mismo volumen, sin una segunda copia completa.
- La cancelación, los errores y los cierres inesperados conservan los fotogramas válidos en una carpeta `Incompleto`; el CSV parcial se identifica por separado y solo puede retirarse el último fotograma si está dañado.
- PNG utiliza compresión nivel 3 y predictor Up manteniendo codificación sin pérdida.
- `tiempos.csv` se crea durante la misma ejecución de FFmpeg con `showinfo=checksum=0`, eliminando la segunda pasada completa de FFprobe.
- El progreso muestra la fase y el número real de fotogramas generados; la validación recorre la carpeta progresivamente y conserva una muestra acotada.

### Pruebas y versión
- Añadidas ocho pruebas Swift Testing para recodificación real, remux avanzado, configuración predeterminada, CSV en una pasada, publicación visible, conservación incompleta, último fotograma dañado y recuperación de operaciones abandonadas.
- Realizadas pruebas funcionales con vídeo sintético y un benchmark comparativo del flujo de fotogramas.
- ZEUVE elevada a 0.7.5, build interno 26; Conversor universal elevado a 0.2.2.
- No se añaden dependencias, motores, Internet, APIs ni cambios en los originales.

## 0.7.4 — 2026-07-30

### Rendimiento
- Añadida una caché compacta y temporal para búsquedas del Analizador, creada bajo demanda y con almacenamiento mapeado para volúmenes excepcionalmente grandes.
- La inserción en SQLite temporal reutiliza una única sentencia preparada y se elimina un resumen completo cuyo resultado se descartaba.
- Descargador y Conversor comparten el registro y diagnóstico de motores, manteniendo invalidación automática y actualización manual.
- El progreso frecuente de yt-dlp y FFmpeg se agrupa mediante control de generación para evitar redibujados excesivos y resultados obsoletos.
- El Conversor reutiliza su escáner, precalcula las rutas originales protegidas y genera instantáneas de progreso en una sola pasada.
- Los rankings de conversaciones se preparan dentro de la instantánea analítica; la limpieza de temporales y el historial salen del hilo principal.
- Añadido un índice SQLite global por fecha para el historial.

### Seguridad y compatibilidad
- Los índices de búsqueda permanecen dentro del espacio temporal de la sesión y se eliminan al cerrar o sustituir el análisis.
- Si la caché no puede construirse, se conserva la búsqueda directa anterior.
- No se añaden dependencias, motores, formatos, Internet, APIs ni cambios en la protección de originales.

### Pruebas y versión
- Añadidas seis pruebas XCTest para caché, temporales, SQLite, historial y agrupación de progreso.
- ZEUVE elevada a 0.7.4, build interno 25.
- Descargador elevado a 0.4.1, Analizador a 0.1.6 y Conversor a 0.2.1.

## 0.7.3 — 2026-07-16

### Cambios
- Eliminado LibreOffice del registro de motores, localización, diagnóstico, ejecución, preparación, firma y empaquetado.
- Eliminados del Conversor los formatos DOC, DOCX, XLS, XLSX, PPT, PPTX, ODT, ODS, ODP y RTF.
- Los archivos ofimáticos se rechazan explícitamente y no se interpretan como ZIP genéricos.
- CSV permanece como formato genérico de datos y conserva el uso auxiliar de `tiempos.csv`.
- Retirada la ruta SVG a PDF que dependía de LibreOffice.
- Actualizadas pruebas, documentación, proyecto Xcode y versión a build 24.

## 0.7.2 — 2026-07-07

### Motores y distribución
- Corregida la instalación de x264 r3222: el script deja de invocar el objetivo inexistente `install-headers`.
- Se mantiene únicamente `make install-lib-static`, cuyo objetivo dependiente `install-lib-dev` instala las cabeceras `x264.h`, `x264_config.h` y el archivo `x264.pc` antes de instalar `libx264.a`.
- Añadida una regresión que exige el objetivo compatible y prohíbe recuperar `install-headers`.

### Versión
- ZEUVE elevada de 0.7.1 a 0.7.2, build interno 23.
- El módulo Conversor permanece en 0.2.0 porque la corrección afecta exclusivamente al script de preparación de motores.

## 0.7.1 — 2026-07-07

### Motores y distribución
- Corregida la URL de respaldo de la licencia de Calibre 9.11.0: el script descarga `LICENSE` desde el tag oficial en lugar del archivo inexistente `COPYING`.
- La licencia se guarda en `licenses/calibre/LICENSE` y esa ruta se registra en el manifiesto generado.
- Añadida una regresión estática que impide recuperar la URL que devolvía HTTP 404.

### Versión
- ZEUVE elevada de 0.7.0 a 0.7.1, build interno 22.
- El módulo Conversor se mantiene en 0.2.0 porque no cambia su contrato ni su comportamiento funcional.

## 0.7.0 — 2026-07-07

### Conversor universal 0.2.0
- Sustituida la detección basada en extensión por una detección combinada de firma, contenido, UTI, MIME, estructura interna y capacidades de los motores, con nivel de confianza y avisos de discrepancia.
- Separadas las categorías de documentos, hojas de cálculo, presentaciones, texto, marcado, vectoriales, animaciones y libros electrónicos para impedir conversiones incoherentes.
- Añadido un registro central de compatibilidad que relaciona entrada, salida, motor, recodificación, copia directa, pérdidas, opciones y disponibilidad real.
- Permitidos lotes con formatos distintos de una misma categoría cuando todos admiten la misma receta; los elementos incompatibles se identifican individualmente.
- Reforzada la protección absoluta de originales: cada salida se compara con todas las entradas del lote y nunca puede publicar sobre un original, ni siquiera con reemplazo autorizado.
- Resueltos antes de convertir la carpeta efectiva, nombres, colisiones, estructura ZIP y sobrescrituras para que la vista previa coincida con el resultado publicado.
- Añadidos los preajustes oficiales Bajo, Medio, Alto, Máxima calidad y Personalizado, con Máxima calidad como valor predeterminado y migración segura desde 0.6.0.
- Añadidas favoritas persistentes y exportables, bookmarks de carpeta, políticas de metadatos, subcarpeta de salida, nombres avanzados, límites ZIP, paralelismo y limpieza de temporales.
- Añadidas rutas seguras para Pandoc, Calibre y Ghostscript; soporte de H.264 por software con libx264, WebP mediante libwebp, secuencias, animaciones y validación específica por formato.
- Añadido soporte de contraseña para ZIP y PDF compatible con PDFKit, mantenida únicamente en memoria y nunca persistida.
- Ampliados progreso individual y global, cancelación, comprobación de espacio, validación de resultados, diagnóstico de motores y clasificación de errores.

### Motores y distribución
- Aprobados Pandoc 3.10, Calibre 9.11.0, Ghostscript 10.07.1, x264 r3222 y libwebp 1.6.0 para preparación local y offline en Apple Silicon.
- FFmpeg 8.1.2 se prepara con libx264 y libwebp; libx265 continúa excluido.
- Los scripts preservan las firmas oficiales de LibreOffice y Calibre y firman únicamente los ejecutables compilados o gestionados por ZEUVE.
- `engines.json` registra los motores opcionales como no proporcionados hasta que el script de macOS los prepare y sustituya por hashes y tamaños reales.
- Ghostscript se ejecuta con modo seguro y rutas de recursos internas; ningún motor se obtiene dinámicamente durante el uso de la aplicación.

### Pruebas y documentación
- Añadidas regresiones de detección, estructura OOXML/ODF/EPUB, ZIP anidado, matriz por motor, lotes mixtos, originales, favoritos, migraciones, argumentos seguros y limpieza de temporales.
- Actualizados README, arquitectura, seguridad, compilación, alcance, matriz de compatibilidad e informes de implementación, pruebas y entrega.
- Validación realizada en Linux x86_64; las pruebas nativas, firma, empaquetado y apertura de la aplicación siguen pendientes de un Mac Apple Silicon.

### Versión
- ZEUVE elevada de 0.6.0 a 0.7.0, build interno 21.
- `com.zeuve.universal-converter` elevado de 0.1.0 a 0.2.0.

## 0.6.0 — 2026-07-06

### Conversor universal
- Añadido el módulo oficial `com.zeuve.universal-converter` 0.1.0 para imágenes, audio, vídeo, documentos, PDF, texto, datos y entradas ZIP.
- Incorporadas detección por contenido, inspección progresiva de carpetas y lectura segura de ZIP sin extraer archivos pesados durante el catálogo.
- Añadidas vista previa, caché selectiva, revisión de planes para descartar resultados obsoletos, progreso, cancelación, historial y ajustes centralizados.
- Añadida extracción de todos los fotogramas a PNG o TIFF, con resolución original, frecuencia variable conservada y `tiempos.csv` opcional.
- Añadida creación de vídeo desde audio con fondo negro o imagen elegida, H.264 VideoToolbox y audio copiado cuando es compatible.
- Añadidas conversiones PDF por páginas, extracción de texto real y creación de PDF a partir de imágenes multipágina.
- Añadida conversión de documentos mediante LibreOffice 26.2.4 ARM64, ejecutado sin interfaz y con perfil temporal aislado.
- Las imágenes se convierten mediante ImageIO nativo para evitar dependencias adicionales y procesar todas las páginas o fotogramas.
- Los resultados se generan en temporales controlados, se validan y se publican atómicamente sin modificar los originales.
- Añadida opción para conservar la estructura de un ZIP y volver a comprimir únicamente los resultados.
- Añadido soporte para ZIP cifrados mediante contraseña temporal exclusivamente en memoria, sin persistencia ni registro.
- Añadidos preajustes del Conversor: creación, renombrado, duplicado, eliminación y restauración desde Ajustes, con selector rápido dentro del módulo.
- Añadidos controles avanzados de imagen, audio y vídeo, copia exacta cuando no existe transformación y conservación opcional de portadas integradas en MP3, M4A y FLAC.

### Motores, pruebas y documentación
- Los scripts de macOS preparan, verifican y empaquetan LibreOffice completo conservando su firma original.
- FFmpeg debe exponer `h264_videotoolbox`, `hevc_videotoolbox` y `prores_ks`; siguen prohibidos libx264 y libx265.
- Añadidas pruebas de rutas, caché, 600 archivos, ZIP con estructura y cifrado, conflictos, huellas, preajustes, copia exacta, portada integrada, opciones avanzadas, fotogramas y vídeo desde audio.
- Actualizados versión, proyecto Xcode, arquitectura, alcance, seguridad, compilación y documentación de entrega.


## 0.5.6 — 2026-07-06

### Reglas y políticas
- Incorporadas catorce reglas permanentes sobre interfaz responsiva, cálculos fuera del hilo principal, caché, invalidación selectiva, cálculo bajo demanda, cancelación de resultados obsoletos y separación del estado visual y analítico.
- Definido un estándar común para gráficos interactivos, tooltips siempre visibles, interacción ligera y coherencia entre todos los gráficos de un módulo.
- Añadidas reglas de regresión de rendimiento, pruebas con volúmenes representativos y validación final en el entorno macOS objetivo.
- La regla final se renumera como 78, manteniendo intacto su contenido y prioridad.

### Documentación
- `PROJECT_DECISIONS.md` consolidado para ZEUVE 0.5.6 sin duplicar decisiones ya registradas del Analizador.
- Actualizadas las referencias de versión, compilación, seguridad, alcance, arquitectura y pruebas.
- Añadidos los informes de pruebas y entrega de 0.5.6.

### Versión
- ZEUVE elevada a 0.5.6, build interno 19.
- El módulo `com.zeuve.chat-analyzer` permanece en 0.1.5 porque no se modifica su código ni su comportamiento.


## 0.5.5 — 2026-07-03

### Corregido
- Los tooltips de los gráficos dejan de estar anclados al borde superior y siguen ahora la posición real del cursor.
- El cuadro se desplaza automáticamente al lado opuesto cuando el puntero se acerca al borde superior o derecho.
- La posición final se limita al área visible del gráfico o mapa de calor para evitar recortes en cualquiera de sus bordes.
- El mapa de calor transforma la posición local de cada celda al espacio común de la tarjeta y utiliza el mismo posicionamiento dinámico.

### Interfaz y rendimiento
- La guía, el punto, la barra o la celda resaltada permanecen asociados al dato exacto mientras el tooltip se mueve junto al cursor.
- El movimiento solo actualiza coordenadas efímeras de interfaz y sigue utilizando las instantáneas en caché, sin recalcular estadísticas.
- Eliminadas las anotaciones `position: .top` de Swift Charts que provocaban que el contenido quedara oculto en la parte superior.

### Pruebas
- La regresión de interfaz exige posicionamiento junto al cursor, inversión en los bordes, límites dentro del contenedor y ausencia de tooltips fijados arriba.
- Se mantiene la cobertura de los ocho gráficos Swift Charts y del mapa de calor.

### Versión
- ZEUVE elevada a 0.5.5, build interno 18.
- Módulo `com.zeuve.chat-analyzer` elevado a 0.1.5.

## 0.5.4 — 2026-07-03

### Interfaz
- Todos los gráficos del Analizador muestran un tooltip al pasar el cursor, sin necesidad de hacer clic.
- Los gráficos temporales resaltan el punto y la fecha o periodo exacto mediante una guía vertical.
- Las barras resaltan la categoría activa y muestran su valor exacto; el mapa de calor resalta la celda con día, franja horaria y mensajes.
- Los gráficos comparativos muestran las dos series del instante o categoría seleccionada y su total conjunto.
- Las fechas, horas, cifras y duraciones se presentan en español y con formato legible.

### Rendimiento
- La interacción utiliza exclusivamente las instantáneas ya calculadas y no vuelve a recorrer los mensajes ni invalida la caché analítica.
- La localización del punto temporal más cercano usa búsqueda binaria sobre las fechas mostradas.
- El histograma de respuestas se calcula en una sola pasada sobre sus muestras.
- El estado de hover se descarta al cambiar de gráfico, participante, granularidad o pestaña.

### Arquitectura
- Añadido `InteractiveChartSupport.swift` con tooltip, seguimiento de fechas, seguimiento de categorías y formateadores comunes.
- La interacción se implementa con una capa `chartOverlay` independiente de la lógica analítica y se reutiliza en líneas, barras y comparaciones.

### Pruebas
- Añadida una regresión estática que exige hover ligero en todos los gráficos, tooltip común, uso de `ChartProxy` y ausencia de cálculos analíticos pesados en la capa de interacción.
- 101 pruebas Swift y 19 pruebas Python superadas sin fallos.
- Compilación SwiftPM Release, análisis sintáctico de las vistas y `Scripts/verify_project.sh` completados correctamente.

### Versión
- ZEUVE elevada a 0.5.4, build interno 17.
- Módulo `com.zeuve.chat-analyzer` elevado a 0.1.4.

## 0.5.3 — 2026-07-03

### Rendimiento
- El Analizador deja de recalcular estadísticas pesadas desde las propiedades de las vistas SwiftUI.
- Añadida una caché central de instantáneas para resumen, actividad, participantes, palabras, conversaciones, respuestas, comparación y búsqueda.
- Los cálculos analíticos se ejecutan en tareas separadas del hilo principal y los resultados se publican una sola vez al finalizar.
- Las pestañas pesadas se calculan de forma diferida al abrirlas y reutilizan sus resultados mientras el estado relevante no cambie.
- Los cálculos anteriores se cancelan cuando cambian filtros, fusiones, ajustes, participantes, granularidad o consulta; una revisión interna descarta resultados obsoletos.
- La búsqueda espera 200 ms después de la última edición y reutiliza su índice al cambiar de página, tamaño o contexto.
- Los filtros aplican una espera breve de 120 ms y mantienen visible el último resultado válido mientras se actualizan las estadísticas.
- Los cambios de ajustes analíticos invalidan únicamente las secciones relacionadas, sin reconstruir el núcleo completo del análisis.

### Optimizado
- La ausencia de filtros reutiliza directamente la colección normalizada y evita una copia completa innecesaria.
- Los componentes de calendario solo se calculan cuando existe un filtro por día u hora.
- Actividad, mapa de calor, horas y días se generan en una única pasada sobre los mensajes.
- Palabras, frases de dos palabras, emojis, frecuencias por participante y tipos de contenido se generan en una única pasada.
- Las series temporales ya no construyen claves de texto por cada mensaje.
- Las expresiones regulares compartidas de enlaces y tokenización se compilan una sola vez.
- Salir de Búsqueda cancela inmediatamente su tarea en segundo plano y evita indicadores bloqueados.

### Interfaz
- Añadidos indicadores discretos `Actualizando estadísticas…` y `Buscando…` sin bloquear la navegación.
- Los resultados anteriores permanecen visibles hasta que existe una instantánea completa y coherente del nuevo estado.

### Pruebas
- Añadidas regresiones para equivalencia entre instantáneas optimizadas y cálculos directos, reutilización del índice de búsqueda y un chat sintético de 35.000 mensajes.
- Añadidas comprobaciones estáticas de caché, segundo plano, cancelación, espera de búsqueda y ausencia de recálculos pesados en las vistas.
- 101 pruebas Swift y 18 pruebas Python superadas sin fallos.
- Compilación SwiftPM Release y `Scripts/verify_project.sh` completados correctamente.

### Versión
- ZEUVE elevada a 0.5.3, build interno 16.
- Módulo `com.zeuve.chat-analyzer` elevado a 0.1.3.

## 0.5.2 — 2026-07-03

### Corregido
- `Analizar otro chat` cierra la sesión temporal, limpia las fuentes y vuelve inmediatamente a la pantalla inicial del Analizador.
- `Cerrar análisis` cierra la sesión temporal, conserva las fuentes seleccionadas y vuelve inmediatamente a la pantalla inicial.
- La vista raíz del Analizador observa directamente su `ChatAnalyzerViewModel`, por lo que ya no es necesario cambiar de módulo para que aparezca la pantalla inicial.

### Añadido
- Ayuda contextual general en las nueve pestañas de resultados: Resumen, Actividad, Participantes, Palabras y emojis, Búsqueda, Conversaciones, Tiempos de respuesta, Comparación y Fusiones.
- Explicaciones específicas en tarjetas de métricas, gráficos, opciones, resúmenes y columnas de tablas no evidentes.
- Nuevos componentes reutilizables para títulos de sección, tarjetas, gráficos, grupos, filas y cabeceras con `info.circle`.
- Cuatro pruebas de regresión para la navegación, la diferencia entre cerrar y analizar otro chat, la cobertura de ayuda contextual y las nuevas reglas permanentes.

### Reglas del proyecto
- Incorporadas reglas generales sobre coherencia entre modos, regreso al estado inicial, selección automática, archivos grandes, estados no comprobables, uso temporal de archivos reales, ayuda en resultados e inspección eficiente de comprimidos.
- Actualizadas las decisiones aprobadas del Analizador con el comportamiento de los dos botones y la ayuda contextual de resultados.

### Versión
- ZEUVE elevada a 0.5.2, build interno 15.
- Módulo `com.zeuve.chat-analyzer` elevado a 0.1.2.

## 0.5.1 — 2026-07-03

### Corregido
- Los ZIP de WhatsApp ya no rechazan `_chat.txt` por superar los 256 KB usados únicamente como muestra de detección.
- La detección lee un prefijo real y la importación de WhatsApp procesa el TXT progresivamente, sin cargarlo completo en memoria.
- Al importar solo un TXT, los adjuntos citados se muestran como no comprobados en lugar de clasificarse erróneamente como faltantes.
- Los archivos WEBP cuyo nombre contiene el marcador de sticker de WhatsApp se contabilizan como stickers, sin cambiar la clasificación de los WEBP normales.
- El cuadro de importación, el diálogo de macOS y los formatos permitidos cambian ahora entre WhatsApp, Instagram y Ambas plataformas.
- Se aceptan ZIP de Instagram que contienen directamente una sola conversación, además de las exportaciones completas de Meta.
- Las rutas multimedia de esos ZIP individuales se adaptan a la estructura realmente incluida para no marcar como ausentes adjuntos presentes.
- Cuando una exportación de Instagram contiene un único chat, queda seleccionado automáticamente.

### Ajustes
- Añadido un límite opcional para cada archivo de conversación en `Ajustes > Analizador de chats`.
- El valor predeterminado es **sin límite**. Si el usuario activa un máximo, el archivo que lo supere se rechaza completo y nunca se analiza parcialmente.

### Seguridad y privacidad
- Se mantienen los límites estructurales del ZIP, la validación de rutas, cifrado, enlaces y relaciones de compresión; el nuevo ajuste no desactiva estas protecciones.
- Los archivos originales continúan abriéndose solo para lectura y no se incorporan conversaciones reales a las pruebas permanentes ni a la entrega.

### Pruebas
- 97 pruebas Swift superadas sin fallos, incluidas regresiones para TXT grandes, límite opcional, adjuntos no comprobados, stickers y ZIP individual de Instagram.
- 11 pruebas Python superadas sin fallos.
- Compilación SwiftPM Release y `Scripts/verify_project.sh` completados correctamente.
- Los dos ZIP reales aportados se utilizaron únicamente como prueba temporal de integración y sus huellas se conservaron sin cambios.

## 0.5.0 — 2026-07-03

### Añadido
- Nuevo módulo oficial `Analizador de chats` (`com.zeuve.chat-analyzer`) para WhatsApp e Instagram.
- Importación directa de ZIP, catálogo de conversaciones de Instagram y modo avanzado para TXT, HTML y carpetas descomprimidas.
- Modelo normalizado común, deduplicación conservadora y conversión horaria mediante zonas reales.
- Resumen, gráficos, filtros, perfiles, palabras, frases, emojis, búsqueda, conversaciones, respuestas, comparación y fusiones temporales.
- SQLite temporal, historial agregado privado, ayuda contextual y ajustes centralizados.
- Puente mínimo a `libarchive` del SDK/sistema para lectura progresiva y segura de ZIP.
- 22 pruebas sintéticas específicas del nuevo módulo.

### Seguridad y privacidad
- Procesamiento completamente local, sin permiso de red, APIs, WebKit, telemetría ni apertura de enlaces.
- Protección frente a traversal, rutas absolutas, enlaces simbólicos, cifrado, entradas duplicadas, ZIP malformados y límites desproporcionados.
- Adjuntos clasificados sin abrirse y temporales eliminados únicamente cuando existe un marcador verificable de propiedad.
- Historial y logs sin mensajes, participantes, búsquedas, nombres privados o rutas completas.

### Cambiado
- Versión de ZEUVE elevada a 0.5.0 y build interno 13.
- Ajustes añade la sección Analizador de chats.
- Inicio, navegación, atajos e historial global reconocen el tercer módulo oficial.
- Proyecto Xcode, scripts de validación, documentación y alcance actualizados.

### Pruebas
- 93 pruebas Swift superadas sin fallos.
- 11 pruebas Python superadas sin fallos.
- Compilación SwiftPM Release y `Scripts/verify_project.sh` completados correctamente.
- Interfaz analizada sintácticamente y proyecto Xcode regenerado.
## 0.4.0 — 2026-07-02

### Añadido
- Navegación centralizada de Ajustes con secciones General, Organizador de archivos y Descargador de YouTube.
- Valores predeterminados persistentes e independientes para nuevas operaciones de ambos módulos.
- Subsecciones Predeterminados, Presets y Diagnóstico dentro de los ajustes del Descargador.
- Restauración segura de valores predeterminados y opción para olvidar carpetas recientes del Organizador.
- Selector rápido de presets dentro del Descargador sin duplicar su gestión.
- Regla permanente que obliga a los módulos futuros a integrar su configuración en el apartado general Ajustes.

### Cambiado
- Eliminados los botones independientes Presets y Diagnóstico de la barra del Descargador.
- Las opciones de una operación ya no sobrescriben los valores predeterminados persistentes del Organizador.
- Presets, diagnóstico, preferencias recordadas y opciones avanzadas persistentes se administran desde Ajustes.
- Cambiar valores predeterminados no altera silenciosamente una operación ya preparada o en curso.
- Versión de ZEUVE elevada a 0.4.0 y build interno 12.
- Versión del módulo `com.zeuve.youtube-downloader` elevada a 0.4.0.

### Pruebas
- Validaciones estáticas de centralización, ausencia de ruedas o botones propios de ajustes y separación entre preferencias y operación actual.
- Compatibilidad del manifiesto y suite existente actualizadas para la versión 0.4.0.
- 71 pruebas Swift y 11 pruebas Python superadas sin fallos.
- Compilación SwiftPM Release completada correctamente.

## 0.3.0 — 2026-07-02

### Añadido
- Selector de formato de vídeo también en el modo simple, con MP4 como valor predeterminado.
- Selector de calidad MP3 de 128, 192, 256 y 320 kbps, visible únicamente cuando se elige MP3.
- Componente reutilizable de ayuda contextual mediante iconos de información en Descargador, Organizador y Ajustes.
- Explicaciones accesibles en español para opciones técnicas, con recomendaciones cuando corresponde.
- Pruebas de valores predeterminados, argumentos de bitrate y migración de presets.

### Cambiado
- MP3 pasa a ser el formato de audio predeterminado y 320 kbps su calidad inicial.
- El nombre predeterminado de los archivos pasa de Título e ID a Título.
- El esquema de presets del Descargador pasa a la versión 2 manteniendo compatibilidad con presets anteriores.
- Versión de ZEUVE elevada a 0.3.0 y build interno 11.
- Versión del módulo `com.zeuve.youtube-downloader` elevada a 0.3.0.

## 0.2.4 — 2026-07-02

### Rendimiento del Descargador de YouTube
- El diagnóstico de yt-dlp, Deno, FFmpeg y FFprobe se conserva durante la sesión y solo se repite si cambian los archivos o el usuario solicita una comprobación manual.
- yt-dlp utiliza una caché local privada en `~/Library/Caches/ZEUVE/yt-dlp`; no se sincroniza ni se envía a terceros.
- El ejecutable autónomo se sustituye por la distribución oficial descomprimida `yt-dlp_macos.zip` 2026.06.09 para reducir el coste de arranque de cada proceso.
- Se registran localmente los tiempos de resolución de motores, análisis, descarga/posprocesado, validación y publicación.
- Se mantiene una única descarga principal cada vez y la validación final con FFprobe.

### Proyecto
- Versión de ZEUVE elevada a 0.2.4 y build interno 10.
- Versión del módulo `com.zeuve.youtube-downloader` elevada a 0.2.4.
- Scripts, pruebas y documentación actualizados para el nuevo empaquetado de yt-dlp.

## 0.2.3 — 2026-07-02

### Corregido
- `yt-dlp` conserva ahora la firma original del ejecutable oficial dentro de `ZEUVE.app`; ya no se vuelve a firmar con Hardened Runtime.
- Deno, FFmpeg y FFprobe continúan firmándose explícitamente con la identidad de ZEUVE.
- Añadida una verificación del paquete que comprueba las cuatro firmas y ejecuta `yt-dlp --version`; la compilación se detiene si el ejecutable incluido no arranca.
- El diagnóstico de motores conserva ahora el código de salida, la señal de terminación, `stdout` y `stderr` cuando un motor falla.
- La ventana de diagnóstico permite desplegar y copiar los detalles técnicos sin sustituir el mensaje comprensible para el usuario.

### Modificado
- Versión de ZEUVE elevada a 0.2.3 y build interno 9.
- Versión del módulo `com.zeuve.youtube-downloader` elevada a 0.2.3; la API y la compatibilidad mínima no cambian.
- `Scripts/build_macos.sh` repite la verificación sobre la aplicación final después de `xcodebuild`.
- Proyecto Xcode, validaciones, decisiones y documentación actualizados.

### Pruebas
- 62 pruebas Swift superadas sin fallos.
- 11 pruebas Python superadas sin fallos, incluidas 3 pruebas nuevas de la política de firma.
- Compilación SwiftPM Debug comprobada durante las pruebas.
- Compilación SwiftPM Release y `Scripts/verify_project.sh` superados en el entorno disponible.
- La compilación y apertura real de `ZEUVE.app` quedan pendientes de un Mac Apple Silicon con Xcode.

## 0.2.2 — 2026-07-02

### Corregido
- Eliminada la comparación en tiempo de ejecución del tamaño y la huella SHA-256 de yt-dlp, Deno, FFmpeg y FFprobe.
- Evitado que la firma de macOS haga que los cuatro motores se marquen erróneamente como no disponibles.
- El diagnóstico sigue comprobando existencia, licencia, permiso de ejecución, arquitectura, dependencias dinámicas, lanzamiento y versión.

### Seguridad y empaquetado
- SHA-256 y tamaño continúan verificándose durante la preparación y antes de firmar mediante `verify_engines_macos.sh`.
- No se han añadido dependencias, servicios, APIs, telemetría ni descargas automáticas.

### Modificado
- Versión de ZEUVE elevada a 0.2.2 y build interno 8.
- Versión del módulo `com.zeuve.youtube-downloader` elevada a 0.2.2; la API y la compatibilidad mínima no cambian.
- Proyecto Xcode, validaciones y documentación actualizados.

### Pruebas
- La prueba de diagnóstico confirma que un cambio de tamaño o SHA-256 no produce `hashMismatch` en ejecución.
- Las comprobaciones finales se documentan en `Docs/Historico/Pruebas/TEST_RESULTS_0.2.2.md`.

## 0.2.1 — 2026-07-01

### Corregido
- Corregida la preparación de Opus, LAME y FFmpeg con el SDK de macOS y Clang seleccionados mediante `xcrun`.
- Corregido `Scripts/static_pkg_config.py` para responder a `--version`, `--atleast-pkgconfig-version`, `--variable`, requisitos de versión agrupados, flags de compilación y flags de enlace estáticos.
- Evitado que opciones como `--variable=includedir` se interpreten erróneamente como nombres de paquetes.
- Generado de forma explícita `libmp3lame.pc`, ya que LAME 3.100 no lo instala.
- Eliminada la ruta temporal fija ligada a la versión 0.2.0.
- Eliminados del proyecto entregado los motores parciales producidos por intentos de preparación fallidos.

### Seguridad y robustez
- La preparación se realiza en un directorio temporal del sistema sin depender del nombre de la carpeta del proyecto.
- Los motores se construyen y verifican en una zona provisional antes de sustituir `Resources/Engines`.
- Si la publicación o la verificación final fallan, se restauran los motores anteriores.
- Las descargas de desarrollo siguen fijadas por versión y SHA-256; no se añade Homebrew, una API, telemetría ni descarga automática durante el uso normal.

### Modificado
- Versión de ZEUVE elevada a 0.2.1 y build interno 7.
- Versión del módulo `com.zeuve.youtube-downloader` elevada a 0.2.1; su compatibilidad mínima permanece en ZEUVE 0.2.0 porque la API del módulo no ha cambiado.
- Proyecto Xcode, generador, ajustes, validaciones y documentación actualizados.
- `verify_engines_macos.sh` admite verificar una carpeta provisional antes de la publicación definitiva.

### Pruebas
- 60 pruebas Swift superadas sin fallos.
- 8 pruebas nuevas del `pkg-config` local superadas sin fallos.
- Compilación SwiftPM Release superada.
- Sintaxis de scripts shell y Python validada.
- Proyecto Xcode regenerado con versión 0.2.1 y build 7.
- `Scripts/verify_project.sh` superado en el entorno disponible.
- La compilación real de FFmpeg/FFprobe ARM64, la compilación con Xcode y la apertura de `ZEUVE.app` quedan pendientes de ejecución en un Mac Apple Silicon.

## 0.2.0 — 2026-07-01

### Añadido
- Módulo oficial `com.zeuve.youtube-downloader` integrado en navegación, dashboard y comandos.
- Entrada de una o varias URLs, pegado, arrastrar texto, validación, canonicalización y eliminación de duplicados.
- Análisis cancelable de vídeos y playlists mediante salida JSON de yt-dlp.
- Modos simple y avanzado con selección de resolución, contenedor, streams exactos, HDR/SDR, audio y subtítulos.
- Procesamiento secuencial de múltiples URLs y elementos de playlist dentro de una única operación global.
- Selección individual y por intervalo de playlists, carga incremental y lista virtualizada.
- Progreso real de descarga y postprocesado, resumen acumulado y continuación segura tras fallos aislados.
- Temporales por operación, validación con FFprobe, publicación segura y renombrado automático por defecto.
- Historial, presets versionados, favoritos, bookmarks de seguridad y diagnóstico en español.
- JSON informativo y de playlist generado por ZEUVE sin URLs, firmas, cookies, tokens, cabeceras ni credenciales.
- Target compartido `ZEUVEEngines` para manifiestos, SHA-256, arquitectura, diagnóstico y ejecución segura.
- Target C `CZEUVEProcess` para iniciar procesos con `posix_spawn` en grupos independientes.
- Terminación de grupos con SIGTERM, espera limitada, SIGKILL como último recurso y comprobación de descendientes.
- Historial global dirigido por datos y por `moduleID`, probado con un tercer módulo simulado.
- Scripts reproducibles para preparar yt-dlp 2026.06.09, Deno 2.9.0 y FFmpeg/FFprobe 8.1.2 ARM64.
- Verificación mediante `otool -L`, firma explícita de ejecutables anidados y registro `engines.json`.

### Modificado
- Versión de ZEUVE elevada a 0.2.0 y build interno 6.
- Proyecto Xcode, generador, scripts de compilación, verificación y empaquetado actualizados.
- Dashboard, navegación, ajustes e historial preparados para más de un módulo.
- El manifiesto del Organizador declara `openExternalApplications`, sin cambios en su lógica ni interfaz.
- Documentación de arquitectura, compilación, seguridad, pruebas, módulos y alcance funcional actualizada.

### Seguridad y privacidad
- No se utiliza shell, Python del sistema, Homebrew, argumentos libres, `--remote-components` ni actualización automática.
- Deno y FFmpeg se pasan a yt-dlp mediante rutas explícitas.
- Cookies y credenciales de proxy no se almacenan ni se muestran en argumentos redactados.
- Los JSON nativos de yt-dlp quedan desactivados; ZEUVE genera archivos sanitizados.
- Las rutas de motores, licencias, temporales y resultados se validan contra traversal y escapes por enlaces simbólicos.

### Pruebas realizadas en esta entrega
- 60 pruebas automáticas superadas sin fallos en el entorno disponible.
- Las 30 pruebas anteriores se mantienen y siguen superándose.
- Compilación Debug de los paquetes Swift comprobada durante `swift test`.
- Cancelación de padre e hijo verificada con un ejecutable auxiliar real.
- Pruebas de 5.000 elementos de playlist, lectura incremental y memoria acotada.
- Proyecto Xcode regenerado con versión 0.2.0 y build 6.
- La preparación de binarios ARM64, la compilación Xcode y la apertura de `ZEUVE.app` siguen pendientes de ejecución en un Mac Apple Silicon.

## 0.1.4 — 2026-07-01

### Añadido
- Guía humana completa en español para desarrollar e integrar módulos oficiales.
- Instrucciones obligatorias en inglés para otros chats de desarrollo.
- Checklist de implementación y entrega de módulos.
- Plantilla para definir los requisitos de cada módulo antes de encargarlo.
- Documento de patrones y ejemplos basado en el Organizador, Swift, motores externos y procesos aislados.
- Ejemplos JSON validados de manifiesto, petición y eventos del protocolo.
- Especificación ampliada de la API de módulos 1.0.
- Script `Scripts/validate_module_docs.py` para validar la documentación y los ejemplos JSON.
- Script `Scripts/package_release.py` para generar entregas completas y limpias.

### Mejorado
- Actualizados README, arquitectura, compilación, pruebas, seguridad, alcance funcional y decisiones del proyecto.
- Diferenciados claramente los módulos oficiales incorporados de los futuros módulos externos importables.
- Actualizado `Scripts/verify_project.sh` al patrón real de inicialización de `AppModel` basado en `initialState`.
- Añadidas comprobaciones de regresión para las llamadas a `LocalLogger`, la configuración SQLite, los manifiestos y la documentación modular.

### Corregido
- Eliminadas cinco advertencias `Result of 'try?' is unused` al descartar explícitamente el valor devuelto por `LocalLogger.write`.
- Eliminadas las sugerencias de instalar `pkg-config` o SQLite mediante Homebrew. `CSQLite` enlaza directamente la biblioteca `sqlite3` del SDK/sistema mediante `module.modulemap`.
- Eliminados `.DS_Store`, `__MACOSX`, datos locales de Xcode, cachés y compilaciones de la entrega.

### Pruebas
- 30 pruebas automáticas superadas sin fallos.
- Compilaciones Debug y Release de los paquetes Swift comprobadas.
- Fuentes SwiftUI/AppKit analizadas sintácticamente.
- Documentación y ejemplos JSON validados automáticamente.
- Proyecto Xcode regenerado con versión 0.1.4 y build 5.
- La compilación y apertura final de `ZEUVE.app` con Xcode en macOS deben confirmarse en un Mac Apple Silicon.

## 0.1.3 — 2026-07-01

### Corregido
- Reorganizado el inicializador de `AppModel` para calcular primero el almacenamiento, el tema, el mensaje de error y el `OrganizerViewModel` mediante variables locales.
- `storage` y el resto de propiedades constantes se inicializan ahora una sola vez.
- El flujo de recuperación ya no consulta propiedades de `self` antes de que todas las propiedades almacenadas estén inicializadas.
- `OperationCoordinator` y `ModuleRegistry` se crean localmente y se asignan junto con el resto del estado, evitando accesos prematuros a `self`.
- No cambia el comportamiento visible, la arquitectura, SQLite, las dependencias ni la gestión de archivos.

### Pruebas
- Revisados todos los inicializadores de `Sources/ZEUVEApp`; no se ha detectado el mismo patrón en `OrganizerViewModel` ni en `OrganizerCompletion`.
- Añadida una comprobación de regresión sobre la estructura segura del inicializador de `AppModel`.
- Suite automática y compilaciones Debug/Release de los paquetes Swift ejecutadas de nuevo.
- La compilación y apertura de la interfaz con Xcode en macOS siguen pendientes de confirmación por el usuario.

## 0.1.2 — 2026-07-01

### Corregido
- Añadida la importación explícita de `ZEUVECore` en `DashboardView.swift` para que `ModuleManifest` esté disponible en ese archivo.
- Añadida la importación explícita de `ZEUVECore` en `RootView.swift` para que `OperationSnapshot` esté disponible en ese archivo.
- No cambia el comportamiento visible, la arquitectura, la gestión de archivos ni las dependencias.

### Pruebas
- Añadida una comprobación de regresión al script de validación para verificar ambas importaciones.
- Suite automática y compilaciones Debug/Release de los paquetes Swift ejecutadas de nuevo.
- La compilación y apertura de la interfaz con Xcode en macOS siguen pendientes de confirmación por el usuario.

## 0.1.1 — 2026-07-01

### Corregido
- Compatibilidad de compilación con Swift 6 y Foundation de macOS: `OrganizerPlanner` y `OrganizerExecutor` ya no declaran una conformidad `Sendable` incompatible con su propiedad `FileManager`.
- Se mantiene la ejecución de planificación y organización en tareas separadas; no cambia el comportamiento visible, la gestión de archivos ni la API pública de sus operaciones.

### Pruebas
- Suite automática completa ejecutada de nuevo.
- Compilaciones Debug y Release de los paquetes Swift verificadas de nuevo.
- La compilación y apertura de la interfaz con Xcode en macOS siguen pendientes de comprobación por el usuario.

## 0.1.0 — 2026-07-01

### Añadido
- Nuevo proyecto nativo para macOS Apple Silicon escrito en Swift 6.
- Interfaz SwiftUI con integraciones AppKit.
- Arquitectura modular basada en manifiestos y API de módulos 1.0.
- Contratos preparados para futuros módulos aislados desarrollados con distintas tecnologías.
- Coordinador global de operaciones.
- Persistencia SQLite local para ajustes e historial.
- Registros técnicos locales en JSONL, sin telemetría ni servicios externos.
- Módulo Organizador de archivos.
- Modos de organización simple y detallado.
- Agrupación de archivos relacionados por nombre.
- Análisis opcional de subcarpetas.
- Protección de archivos ocultos, temporales, enlaces simbólicos y paquetes de macOS.
- Vista previa seleccionable antes de ejecutar, con búsqueda y selección por categoría o formato.
- Renombrado seguro u omisión ante conflictos.
- Cancelación con reversión de movimientos completados, comprobada también tras iniciar el lote.
- Historial y deshacer inmediato o posterior con comprobación de huellas.
- Exportación del plan a CSV.
- Carpetas recientes y tema claro, oscuro o del sistema.
- Proyecto Xcode y esquema compartido.
- Pruebas automáticas, scripts y documentación.

### Limitaciones conocidas
- La interfaz no ha sido compilada ni abierta en este entorno porque no dispone de macOS ni Xcode.
- App Sandbox, firma, notarización e icono definitivo están pendientes.
- La importación de módulos externos todavía no está disponible.
