# ZEUVE 0.20.3.0

ZEUVE es una aplicación nativa y modular para macOS 14+ en Apple Silicon. La versión 0.20.3.0 corrige el análisis, la selección y la revisión previa a la limpieza del **Limpiador 0.1.1**.

## Estado de esta entrega

El Limpiador permite cancelar el inventario durante las mediciones de tamaño y acota la búsqueda de Spotlight. Una búsqueda incompleta se señala como cobertura parcial y no convierte aplicaciones históricas en desaparecidas. El plan completo se muestra antes de limpiar y la confirmación enumera las rutas seleccionadas.

El proyecto incluye:

- Organizador;
- Descargador universal;
- Analizador de chats;
- Conversor universal;
- Comparador de seguidores de Instagram;
- **Inspector multimedia** 0.7.2;
- **Limpiador** 0.1.1.

### Limpiador 0.1.1

Analiza aplicaciones, residuos, cachés/logs, determinados datos regenerables de Xcode, instaladores antiguos y espacio local mediante un pipeline común y revisable. La selección automática se limita a elementos regenerables de riesgo bajo; datos persistentes, App Groups compartidos y asociaciones inciertas quedan protegidos. Papelera es el modo predeterminado y permite Undo verificable mientras macOS conserve el elemento. La selección de desinstalación mantiene la dependencia entre la `.app` y sus datos asociados; la revisión previa enumera las rutas, y los resultados distinguen eliminados, omitidos y fallidos.

La navegación global puede reordenarse desde Ajustes → General → Herramientas y atajos. Los defaults son `⌘1`…`⌘7` para los siete módulos y `⌘8` para Historial, pero todos los atajos de módulos e Historial pueden cambiarse o desactivarse.

### Inspector multimedia 0.7.2 — respuesta interactiva

El transporte conserva las identidades, generaciones, pausa de vídeo, seek optimista y sustitución atómica ya estabilizados. La salida de audio se corta de inmediato antes de limpiar FFmpeg/AVAudioEngine; los procesos efímeros de preview usan una gracia de cancelación de 50 ms sin cambiar los 2 s globales de otros motores; y el monitor deja de publicar snapshots redundantes cuando la sesión está pausada. Durante reproducción se mantiene la cadencia de 100 ms del playhead.

### Inspector multimedia 0.7.1 — corrección de transporte y análisis

Los controles de Pistas y reproductor comparten identidad solicitada/confirmada y estado global. El análisis distingue rolloff, banda efectiva y caída persistente, incorpora cobertura temporal y hace explícito el recorte de anomalías agrupadas.

### Inspector multimedia 0.7.0 — macro-bloque final

El Inspector mantiene la inspección inicial en solo lectura y amplía su sesión multimedia sin convertirse en editor creativo ni conversor. El preview de vídeo se decodifica incrementalmente mediante el FFmpeg 8.1.2 ya empaquetado, con resolución, FPS y buffer acotados, fallback a software cuando VideoToolbox no es viable y una única posición temporal compartida con audio, waveform, espectrograma, sonoridad, capítulos y overlays. Los subtítulos textuales pueden previsualizarse sincronizados; ASS/SSA conserva contenido y timing sin prometer fidelidad completa de estilos avanzados.

La edición estructural incorpora streams de vídeo y carátulas cuando pueden preservarse mediante stream copy. `attached_pic` se modela aparte del vídeo normal; los casos que exigirían recodificación se bloquean. El lote puede enumerar carpetas de forma incremental sin seguir symlinks, aplicar reglas semánticas sobre propiedades reales de los streams, mostrar un preflight por archivo y ejecutar secuencialmente con workspace, FFprobe final y publicación segura.

El análisis avanzado aporta indicios explicables de una posible fuente previamente comprimida con pérdida y anomalías espectrales temporales, sin afirmar que un archivo lossless sea "falso" por un único cutoff. El OCR bitmap usa Vision de macOS de forma local y genera un borrador revisable; nunca sustituye automáticamente la pista original. Favoritos se limita a presets y conjuntos de reglas reutilizables y no almacena rutas multimedia privadas. El informe JSON pasa a schema 3 con secciones aditivas y sanitizadas.

Inspector multimedia abre siempre los archivos en modo de solo lectura y permite después, mediante `Editar`, trabajar sobre un borrador reversible para añadir/eliminar/reordenar audio y subtítulos, cambiar idioma/título/default/forced y generar un archivo nuevo mediante remultiplexado seguro. Vídeo y audio permanecen en stream copy; cualquier transcode audiovisual sigue perteneciendo al Conversor universal.

La pestaña Espectrograma decodifica la pista elegida con FFmpeg a PCM float32 incremental, planifica hasta ocho ventanas representativas por columna, analiza con Accelerate/vDSP en macOS y ofrece selección de pista/canal, ventanas, FFT size, rango dinámico, escalas lineal/logarítmica, zoom/pan, cursor y exportación PNG. Rango, escala y zoom reutilizan el modelo ya calculado. La implementación es propia; Spek 0.8.5 se estudió únicamente como referencia técnica clean-room y no se incorpora código GPL ni wxWidgets.

En 0.14.0.0 el espectrograma añade ejes de tiempo/frecuencia, leyenda dB, crosshair y reproducción desde el punto inspeccionado. Un reproductor auxiliar local usa FFmpeg para decodificar el stream exacto a PCM y AVAudioEngine para la salida; permite escuchar pistas originales y audios externos del borrador con play/pause, seek, saltos y volumen, sin crear historial ni resultados permanentes.

En 0.15.0.0 el reproductor sustituye su slider temporal por una **waveform bipolar real**: cada intervalo conserva máximos positivos, mínimos negativos y, opcionalmente, energía RMS; la mezcla multicanal conserva picos sin realizar una suma PCM que pueda cancelar fase. Waveform y espectrograma comparten posición de reproducción. Cambiar de pista conserva el instante actual, los capítulos pueden navegar al reproductor y el Inspector permite cerrar la sesión o analizar otro archivo sin salir del módulo.

En 0.15.2.0 el servicio captura los recursos de la sesión anterior y completa la cancelación de FFmpeg, scheduler, player y AVAudioEngine antes de crear la nueva. Una generación interna hace que A→B→C termine siempre en C; la interfaz muestra solo esa pista como **Cargando…** y conserva el playhead para originales, externos, pausa y pistas más cortas.

En 0.15.3.0 la sustitución conserva además el estado Play/Pausa: una pista nueva seleccionada mientras el reproductor está pausado queda preparada en el mismo instante sin arrancar FFmpeg ni AVAudioEngine hasta que el usuario reanuda. El seek de la waveform mantiene Pausa, el botón de Espectrograma deja de reiniciar a `00:00` y el selector reconoce también sustituciones todavía pendientes. El gráfico del Espectrograma deja de imponer 420 pt mínimos y cede altura al reproductor inferior cuando la ventana es más baja.

En 0.15.4.0 la identidad y el estado de cada botón de preview se resuelven exclusivamente en `MultimediaInspectorViewModel`. Durante una transición se prioriza `requestedPreviewSourceID`, después la fuente confirmada y solo como respaldo la fuente activa interna; Pistas y Espectrograma dejan de mantener lógica distinta para decidir si un clic pausa o inicia.

En 0.15.5.0 se separa la identidad transitoria de carga de la identidad estable del transporte: `requestedPreviewSourceID` solo gobierna `.loading`, mientras `.playing`, `.paused` y `.finished` se asocian exclusivamente a `previewSourceID`. Pistas y Espectrograma ejecutan su acción a partir de la misma proyección `previewPlaybackState(for:)`, evitando que el botón de Pistas vuelva a iniciar la pista cuando debe pausar o reanudar.

En 0.15.6.0 las pistas originales mostradas en modo de inspección dejan de reconstruirse con un `UUID()` nuevo en cada evaluación de SwiftUI. El ViewModel conserva snapshots estables de audio y subtítulos hasta cerrar, sustituir o publicar una nueva inspección; así las actualizaciones frecuentes de `previewPosition` ya no destruyen y recrean las filas de Pistas mientras el usuario intenta pulsar `Pausar`.

En 0.15.7.0 FFprobe decide también si procede el análisis automático complementario. Con exactamente un stream de audio, ZEUVE genera el espectrograma, analiza la señal y después calcula la sonoridad EBU R128 de forma secuencial y cancelable; con cero streams no ejecuta análisis de audio y con dos o más conserva los botones manuales para que el usuario elija la pista. La política depende del contenido real del archivo, no de su extensión.

En 0.15.8.0 waveform y espectrograma comparten un único `AudioTimelineViewport`. El zoom se centra en el playhead cuando hay una posición de reproducción válida, el desplazamiento conserva límites temporales y **Vista completa** restaura todo el archivo. La waveform mantiene una envolvente acotada de hasta 65.536 intervalos y recorta/reduce en memoria la región visible, por lo que navegar no vuelve a decodificar audio. Los capítulos de la fuente original aparecen como marcadores de solo lectura sobre la waveform y el hover muestra su título/tiempo.

En 0.15.9.0 el Inspector incorpora **Análisis de señal** sobre PCM `float32` a sample rate y canales originales. Detecta silencios por ventanas RMS únicamente cuando todos los canales quedan bajo el umbral configurado y localiza agrupaciones conservadoras de muestras cercanas al límite digital como **Posible clipping**. Los resultados son efímeros, se muestran sobre waveform y espectrograma y no persisten PCM ni modifican el original. Con una sola pista la cadena automática pasa a ser espectrograma → señal → sonoridad; con varias pistas continúa siendo manual.

En 0.16.0.0 la pasada EBU R128 existente conserva también una serie temporal acotada de Momentary, Short-term e Integrated LUFS; el Inspector representa Short-term LUFS bajo el espectrograma con el mismo viewport, playhead y seek. La vista Pistas añade comparación **A/B** entre dos audios usando el reproductor compartido: conserva posición y estado Play/Pausa, pero no cambia la pista elegida para el espectrograma. La comparación técnica reutiliza resultados ya disponibles y solo ejecuta, de forma explícita y secuencial, los análisis que falten. Los informes JSON pasan a schema 2 e incorporan timeline y señal sin exportar rutas, fingerprints ni identificadores internos.

En 0.17.0.0 el mismo borrador reversible incorpora **capítulos, attachments y metadatos multimedia**. Los capítulos pueden añadirse, eliminarse, renombrarse y recolocarse; los attachments reales pueden añadirse, quitarse, renombrarse y extraerse, mientras `attached_pic` permanece protegida; y Metadatos permite editar un conjunto seguro de tags. El remux mantiene vídeo/audio en stream copy, usa FFmetadata temporal para capítulos y vuelve a validar con FFprobe antes de publicar.

En 0.18.1.0 la ayuda contextual del Inspector se completa en **Resumen, Pistas, Espectrograma, Metadatos, Lote y Ajustes**. Las métricas y opciones técnicas disponen de iconos de información junto al concepto correspondiente mediante `ContextualHelpButton`/`Help*`, con textos accesibles por teclado y VoiceOver. Abrir una ayuda no ejecuta FFmpeg/FFprobe, no recalcula análisis y no invalida cachés.

En 0.18.0.0 el Inspector incorpora un **modo de lote** para varias selecciones o múltiples archivos arrastrados. La cola procesa los elementos de forma estrictamente secuencial y puede combinar FFprobe, análisis de señal, sonoridad, espectrograma PNG e informe TXT/Markdown/JSON. Con varias pistas de audio, ZEUVE no elige una silenciosamente: conserva la inspección técnica y marca los análisis dependientes de pista como omitidos con aviso. Los resultados correctos ya publicados se conservan si el usuario cancela un lote, y los fallos de un elemento no detienen los siguientes.

Los **presets de lote** se guardan con `SettingsRepository` bajo una clave versionada y nunca contienen rutas, carpetas ni archivos. Se administran exclusivamente desde Ajustes, donde 0.18 amplía también la personalización del Inspector: automatización mono-pista, preview, continuidad de cambio de pista, zoom/pan, waveform y overlays, parámetros de señal, espectrograma y dimensiones PNG, informes, salida/edición y preset predeterminado. Las invariantes de seguridad, privacidad, fingerprints, validación y protección del original siguen sin ser desactivables.

La sonoridad se calcula mediante FFmpeg/EBU R128 y respeta `OperationCoordinator`: se inicia automáticamente solo cuando la inspección contiene exactamente una pista de audio y permanece bajo demanda cuando existen varias pistas. El Inspector muestra offsets/diferencias de duración como datos técnicos, sin afirmar por sí solo que exista desincronización. Los informes `.txt`, `.md` y `.json` se exportan únicamente por acción explícita y omiten rutas completas, fingerprints e identificadores internos. Los valores predeterminados del Inspector se administran desde Ajustes mediante `SettingsRepository`.

`ZEUVEEngines/MediaInspection` centraliza FFprobe, sus modelos y caché temporal por fingerprint. El Conversor universal consume esa misma capa y conserva su comportamiento anterior.

La entrega mantiene Hardened Runtime, ejecución de motores sin shell, `OperationCoordinator`, publicación segura, historial local minimizado y los motores FFmpeg/FFprobe ya empaquetados. **No añade dependencias externas, motores, APIs ni acceso de red.**

## Motores

El Inspector reutiliza FFmpeg y FFprobe existentes. La preparación de motores continúa siendo expresa y separada del uso normal:

```bash
./Scripts/build_macos.sh Release
```

No se descarga ni actualiza ningún motor automáticamente al abrir el Inspector.

## Pruebas

```bash
./Scripts/run_tests.sh
./Scripts/verify_project.sh
```

La compilación Xcode, firma, Hardened Runtime, Accelerate/vDSP, SwiftUI/AppKit y el uso real de motores ARM64 deben verificarse finalmente en un Mac Apple Silicon.

## Documentación principal

El mapa de consulta y las reglas para incorporar nueva documentación están en `Docs/INDEX.md`. La documentación vigente se organiza por finalidad; las evidencias de versiones anteriores viven bajo `Docs/Historico/`.

- `Docs/Modulos/Funcionales/MULTIMEDIA_INSPECTOR.md`: alcance, arquitectura, política híbrida, Spek clean-room y espectrograma.
- `Docs/Modulos/Funcionales/UNIVERSAL_CONVERTER.md`: responsabilidad del Conversor universal.
- `Docs/Fundamentos/ARCHITECTURE.md`: capas y FFprobe compartido.
- `Docs/Fundamentos/SECURITY.md`: protección de originales, procesos y privacidad.
- `Docs/Fundamentos/TESTING.md`: estrategia de pruebas.
- `Docs/Fundamentos/BUILDING.md`: compilación y validación macOS.
- `Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.19.0.0.md`: implementación del macro-bloque final del Inspector multimedia 0.7.0.
- `Docs/Historico/Pruebas/TEST_RESULTS_0.19.0.0.md`: resultados de QA portables y límites de validación macOS.
- `Docs/Historico/Entregas/DELIVERY_0.19.0.0.md`: entrega histórica de 0.19.0.0.
- `Docs/Modulos/Funcionales/CLEANER.md`: arquitectura funcional y comportamiento del Limpiador.
- `Docs/Modulos/Funcionales/CLEANER_PRIVACY_AND_FILES.md`: privacidad, permisos y garantías de archivos del Limpiador.
- `Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.20.0.0.md`, `Docs/Historico/Pruebas/TEST_RESULTS_0.20.0.0.md` y `Docs/Historico/Entregas/DELIVERY_0.20.0.0.md`: cierre de la entrega 0.20.0.0.
- `Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.20.2.0.md`, `Docs/Historico/Pruebas/TEST_RESULTS_0.20.2.0.md` y `Docs/Historico/Entregas/DELIVERY_0.20.2.0.md`: optimización de respuesta del Inspector multimedia 0.7.2.
- `Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.20.3.0.md`, `Docs/Historico/Pruebas/TEST_RESULTS_0.20.3.0.md` y `Docs/Historico/Entregas/DELIVERY_0.20.3.0.md`: correcciones de confianza y cancelación del Limpiador 0.1.1.
- `Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.20.1.0.md`, `Docs/Historico/Pruebas/TEST_RESULTS_0.20.1.0.md` y `Docs/Historico/Entregas/DELIVERY_0.20.1.0.md`: corrección del Inspector multimedia 0.7.1.
- Los documentos 0.18.1.0 se conservan como histórico del cierre de ayuda contextual.
- `Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.18.0.0.md`: lotes, presets y auditoría de personalización del Inspector.
- `Docs/Historico/Pruebas/TEST_RESULTS_0.18.0.0.md`: resultados automáticos ejecutados para esta entrega.
- `Docs/Historico/Entregas/DELIVERY_0.18.0.0.md`: estado final del tercer macro-bloque.
- Los informes 0.17.0.0 se conservan como histórico del cierre de la edición estructural.
- Los informes 0.16.0.0 se conservan como histórico del cierre del análisis avanzado.
- `Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.15.9.0.md`: análisis de silencios/posible clipping e integración en la línea temporal.
- `Docs/Historico/Pruebas/TEST_RESULTS_0.15.9.0.md`: resultados automáticos ejecutados para esta entrega.
- `Docs/Historico/Entregas/DELIVERY_0.15.9.0.md`: estado final de la mejora.
- `Docs/Historico/Implementacion/IMPLEMENTATION_REPORT_0.15.8.0.md`: viewport temporal compartido, waveform de alta resolución acotada y marcadores de capítulos.
- `Docs/Historico/Pruebas/TEST_RESULTS_0.15.8.0.md`: resultados automáticos ejecutados para esta entrega.
- `Docs/Historico/Entregas/DELIVERY_0.15.8.0.md`: estado final de la mejora.
- Los informes 0.15.7.0 se conservan como histórico del análisis automático mono-pista.
- Los informes 0.15.6.0 se conservan como histórico de la identidad estable de filas durante reproducción.
- Los informes 0.15.5.0 se conservan como histórico de la separación entre fuente solicitada y confirmada.
- Los informes 0.15.4.0 se conservan como histórico de la primera centralización de controles.
- Los informes 0.15.3.0 se conservan como histórico de continuidad Play/Pausa y layout adaptable.
- Los informes 0.15.2.0 se conservan como histórico de la sustitución atómica y control de generaciones.
- Los informes 0.15.0.0 se conservan como histórico de waveform, sonoridad, ajustes y sesión reutilizable.
- Los informes 0.14.0.0 se conservan como histórico de la incorporación del reproductor y UX técnica.
- Los informes 0.13.2.0 se conservan como histórico de la optimización del espectrograma.
- Los informes 0.13.0 se conservan como histórico del nacimiento del módulo.

Los documentos históricos de versiones anteriores se conservan sin reescritura retroactiva.
