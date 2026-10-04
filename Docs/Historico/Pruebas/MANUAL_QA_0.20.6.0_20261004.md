# QA manual — ZEUVE 0.20.6.0 · 04/10/2026

## Resultado y base

22/22 IDs corregidos del alcance aceptados desde la UI. Checklist acumulada: **639 IDs; 590 OK, 1 fallido, 14 parciales y 34 pendientes**. El fallo restante D-13 y las sesiones remotas del Descargador quedan excluidos. No se modifica código de producto en esta ronda ni se amplía el alcance de los parciales.

Se partió de `origin/main` sincronizado en `bd16b66dbcd62480df4ad21cc4611db01ddf0995`; las correcciones están en `fa314de10b1d418aec94307b3dc3dca568614900`. La app probada es Release 0.20.6/build 72, en una copia interna QA con firma ad hoc comprobada y `ZEUVE_DATA_DIR` aislado. No se creó otra carpeta versionada del proyecto ni ZIP.

## Método y protección de datos

Acciones reales en la interfaz nativa, con AppleScript/System Events y eventos de ratón CoreGraphics cuando la llamada AX síncrona impedía cancelar a tiempo. El permiso nativo de eventos ya estaba concedido. Cada ID se registró inmediatamente después de terminar. Capturas, lecturas AX, resultados de UI y verificaciones de salida se conservan fuera del repositorio. Las verificaciones CLI examinan los archivos publicados desde UI; no se presentan como aceptaciones UI por sí solas.

Pandoc 3.10 ARM64 se preparó solo en la copia QA, usando el ZIP oficial y el SHA fijado por el proyecto. Binario SHA-256 `d0a20cc85a03ec30f602c6acb568158982240431e5589e0e7c01ce80e0253493`. Sin instalación global ni cambios del empaquetado mantenido.

15 originales sintéticos conservan sus SHA-256; también las 200 y 1000 copias usadas para los lotes de preparación. Las ediciones estructurales conservan todos los paquetes audiovisuales previstos; adjuntos y carátulas se comparan por bytes/extradata. Se decodifican íntegramente las salidas audiovisuales compatibles indicadas. No se usan preferencias personales para el reset ni datos personales para conversiones, ediciones o retiradas.

El Limpiador analiza ubicaciones locales configuradas y la carpeta adicional propia; la preselección está desactivada. Se revisa un plan de ruta única para un instalador ficticio de 83 bytes. Se mueve a Papelera y se restaura con Deshacer tras reinicio normal. SHA-256 restaurado `8ca0c0b8789d5771fc694512c1de2560f314becdeedba662fbe4873d0bec55b5`; SQLite termina sin Undo pendiente. La lectura externa directa de Papelera fue denegada por macOS y no se eludió. La restauración se ejecutó desde ZEUVE. No se borra permanentemente ni se vacía Papelera.

## Resultados individuales

- **C-14 — ✅:** WAV mono → OPUS en Personalizado/Automático: plan anuncia 256 kb/s y UI termina 1 correcto/0 fallidos. En Avanzado, 320 kb/s explícitos mono muestran el aviso de máximo 256 antes de convertir, sin reducir la selección; al sustituir por WAV estéreo, el plan anuncia 320 elegidos y termina 1 correcto/0 fallidos. FFprobe y decodificación íntegra confirman Opus mono/estéreo respectivamente; originales intactos.

- **C-15 — ✅:** WAV mono → OGG en Personalizado/Automático: plan anuncia 256 kb/s, UI 1 correcto/0 fallidos/omitidos/cancelados; FFprobe confirma Opus en Ogg, mono 48 kHz y decodificación íntegra sin errores. Elegir 320 kb/s explícitos muestra antes de ejecutar el aviso de máximo 256 y mantiene la selección. Original intacto.

- **C-35 — ✅:** TXT → Markdown y HTML por UI: cada ruta termina 1 correcto/0 fallidos/omitidos/cancelados. Markdown de párrafos simples aceptado y publicado; HTML independiente válido. Lectura de ambas salidas confirma 12345, acentos y ñ; fuente intacta.

- **C-36 — ✅:** Markdown → TXT y HTML por UI: cada ruta termina 1 correcto/0 fallidos/omitidos/cancelados. TXT elimina marcadores de énfasis/código y conserva contenido/listas; HTML válido conserva estructura. Salidas UTF-8 comprobadas y original intacto.

- **C-37 — ✅:** HTML → TXT y Markdown por UI: cada ruta termina 1 correcto/0 fallidos/omitidos/cancelados. TXT plano sin etiquetas/énfasis y Markdown con contenido textual publicado; 12345 y ñ conservados. Original intacto.

- **C-20 — ✅:** UI simple no ofrece WebM. Avanzado/copia rápida con H.264 muestra rechazo durante la preparación, sin ejecutar un plan incompatible. Contraste AV1/AAC: plan anuncia copia de vídeo y Opus mono a 256 kb/s; UI 1 correcto/0 fallidos. FFprobe verifica WebM AV1/Opus y todos los hashes de paquetes de vídeo coinciden con la fuente; audio decodificado íntegro. El decoder AV1 local no permite comprobar reproducción de vídeo, límite separado del remux. El 320 explícito heredado se rechazó correctamente y se eligió Automático por UI.

- **C-46 — ✅:** Lote de dos vídeos sintéticos de 120 s: botón Cancelar pulsado durante Convirtiendo; resumen 0 correctos/fallidos/omitidos y 2 cancelados, sin FFmpeg residual. Cerrar resultado recupera importar/Quitar todas y permite preparar y ejecutar WAV→MP3 sin reiniciar: 1 correcto/0 fallidos y decodificación íntegra. Fuentes intactas. Primer intento de control no llegó al botón vivo y acabó 2 correctos; solo el segundo acredita cancelación.

- **P-16 — ✅:** Se revalida el fallo transversal mediante C-46: tras cancelar el lote real, la misma sesión recupera controles y ejecuta otra conversión completa sin reiniciar ZEUVE. Motores terminados, secretos efímeros vacíos en UI y originales intactos. Aceptación del recorrido de cancelación del Conversor que originó INC-14; no extrapolación a cualquier motor.

- **I-38 — ✅:** Seek real desde transporte: tras Pausa, +15 s lleva reloj a 00:35 y frame a timecode 00:00:34.9; se conserva Reanudar. Contraste -15 s en estado detenido/finalizado pasa por 25 y 10 s con frame 10.083. Capturas guardadas; no queda la imagen anterior.

- **I-39 — ✅:** Durante vídeo MKV con dos AAC se cambia Tono440 → Tono1320 → Tono440 desde Escuchar en Pistas. Reloj continúa de 10 a 15 y 19 s; frame 18.500 en vuelta A, sin alerta de ejecutor ocupado ni congelación. Pausa y seek posteriores responden. Evidencia visual y AX; no certifica sincronía acústica.

- **I-66 — ✅:** Capturas visuales a 1470×844, 1055×724 y mínimo efectivo 1035×724. Espectrograma generado con vídeo/audio y aviso de PNG exportado: Play, saltos, velocidad, volumen, pantalla completa y Stop quedan dentro de la ventana; al estrecharse pasan a dos filas. Contenido superior desplazable. Se restaura tamaño amplio.

- **I-33 — ✅:** En el multistream H264/2 AAC, Play/Pausa/Reanudar, saltos pausados, navegación Resumen/Pistas/Espectrograma y cambios A→B→A responden sin los bloqueos visuales previos; los frames siguen al destino o al reloj. Acciones de transporte enviadas en ~0,15–0,2 s, capturas confirman resultado. Muestreo funcional, sin afirmar una garantía de latencia máxima para todos los archivos.

- **I-120 — ✅:** Desde Metadatos se escribe título de vídeo A; Pistas muestra el mismo valor. Se reordena A después de B y se publica I120-I127-I136_UI.mkv. FFprobe confirma Video B en ordinal 0 y Vídeo A metadata QA 206 en ordinal 1; paquetes de ambas pistas idénticos al original y decodificación completa correcta.

- **I-127 — ✅:** En Resumen/Adjuntos se cambia nombre a adjunto_metadata_206.bin y MIME a application/octet-stream. Publicación desde Generar archivo nuevo completada y resultado abierto automáticamente en solo lectura. FFprobe confirma ambos tags; extradata idéntica, aunque codec_name sigue ausente como en la entrada.

- **I-136 — ✅:** Generar archivo nuevo publica MKV con los 7 streams, dos capítulos, título reordenado y attachment sin codec_name conservado. No aparece el falso cambio de códec anterior. Los seis streams audiovisuales/subtítulos conservan sus paquetes SHA-256 y el adjunto conserva extradata; vídeo/audio decodifican completos. Original intacto.

- **I-130 — ✅:** UI añade JPEG a MP4 sin carátula. Campo Título vacío/deshabilitado y limitación MP4 visible. Generar archivo nuevo publica I130_UI_add.mp4; FFprobe confirma una attached_pic MJPEG. JPEG extraído idéntico a imagen elegida, vídeo/audio conservan paquetes y decodifican completos. Original intacto.

- **I-131 — ✅:** UI Sustituir cambia JPEG por PNG en MP4. Título vacío/deshabilitado y limitación visible. Se publica I131_UI_replace.mp4 con una única attached_pic PNG, sin la JPEG anterior. PNG extraído idéntico a imagen B, paquetes audiovisuales intactos y decodificación completa correcta.

- **I-132 — ✅:** UI elimina la carátula original de I130_contraste_sin_titulo.mp4 y publica I132_UI_remove.mp4. Resultado con 0 attached_pic, un vídeo y un audio; no falso rechazo de idioma ausente/und ni bloqueo por carátula eliminada. Paquetes de vídeo/audio idénticos y decodificación completa correcta.

- **I-133 — ✅:** UI edita metadata global en MKV con carátula original y publica I133_UI_keep.mkv. Se conserva la imagen como adjunto Matroska; extradata idéntica a la original. Vídeo/audio mantienen todos los paquetes y decodifican completos. Original intacto; resultado abierto en solo lectura.

- **I-164 — ✅:** 201 archivos propios: captura muestra Preparando…, Cancelar preflight y coordinador activo. Clic nativo con permiso de eventos ya concedido cancela durante ejecución; captura posterior muestra Generar preflight, controles activos, sin planes ni coordinador. Sin resultados tardíos. Cerrar/reabrir lote y preparar un archivo termina con 1 aplicable, sin FFprobe residual ni salidas masivas. Intentos AX tardíos se excluyen de aceptación; los lotes de 1201 solo fueron de preparación.

- **S-16 — ✅:** Se crea preset QA206_preset_reset en Ajustes, conjunto QA206_regla_reset en Lote y se marcan ambos favoritos desde UI. General → Restaurar todos los ajustes, confirmación aceptada. Tras cierre normal y reapertura, ambos se seleccionan y conservan configuración/★. SQLite reabierto: presets, reglas y favoritos byte a byte idénticos antes/después del reset y reinicio. Datos aislados; no reset del usuario.

- **L-74 — ✅:** Solo Antiguo-QA-206.pkg propio, 83 bytes, seleccionado y revisado por ruta exacta. UI mueve 1 a Papelera/0 fallidos, persiste Undo. Cierre normal y reapertura (13650→14806): Limpieza ofrece Deshacer antes de analizar. Al pulsarlo, archivo restaurado a su ruta original con SHA-256 idéntico y 0 filas Undo pendientes. La lectura externa de Papelera fue denegada por macOS y no se eludió; restauración comprobada desde ZEUVE.

## Evidencias y límites

Carpeta local de evidencias:

`/Users/javiercv/.codex/visualizations/2026/10/04/01a1076e-1b9d-7cd0-8c38-37429ec79762/QA-fixes`

- `manual-results.json` y `UIEvidence/`: registros de las acciones y resultados individuales.
- `I38-paused-seek.png`, `I39-A.png`, `I39-B.png`, `I66-warning-minimum.png`: controles de reproducción y distribución visual.
- `I164-focused-active.png` y `I164-focused-cancelled.png`: preflight activo y cancelación efectiva. Los intentos AX tardíos y clics que no alcanzaron el botón se excluyen de la aceptación.
- `UIEvidence/I120-I127-I136-verification.json` y verificaciones de I-130–I-133: estructura, paquetes, imagen y decodificación de las ediciones publicadas.
- `UIEvidence/S16-before.json` y comprobaciones tras reset/reinicio: persistencia de presets, reglas y favoritos.
- `UIEvidence/L74-after-trash.json`, `L74-restarted-undo.png`, `L74-restored.json`: registro persistido, Deshacer visible antes de otro análisis y restauración con hash intacto.
- `UIEvidence/final-original-hashes.json` y `final-evidence-manifest.json`: originales/copias y huellas de evidencias.

El cierre de `SkyComputerUseService` durante lecturas AX masivas pertenece al controlador. Se conservan los intentos anteriores como historial; el control alternativo permitió completar las pruebas. La ventana QA se recuperó desde Ventana → Inicio. No se atribuye ese problema de lectura al producto.

C-20 acredita el remux AV1→WebM y la integridad de vídeo por paquetes; el decodificador AV1 local no permitió certificar reproducción de ese vídeo. I-33 es un muestreo funcional de respuesta, sin garantía de latencia máxima universal. I-39 comprueba continuidad visual y ausencia de alerta; no certifica sincronía acústica. MOV, OCR y otros parciales permanecen con su estado anterior. No se prueba Descargador ni sesiones de Instagram.

La app QA se cierra normalmente, sin motores residuales ni operaciones pendientes. Solo queda el directorio vacío `Temporary/UniversalConverter`; las salidas y fixtures propios se conservan como evidencia. Las pruebas automáticas y builds de la corrección están documentados en [TEST_RESULTS_0.20.6.0.md](TEST_RESULTS_0.20.6.0.md); no se afirman repetidos en este cierre documental.

## Verificación documental del cierre

`python3 Scripts/verify/documentation.py`, `python3 Scripts/validate_module_docs.py` y `git diff --check` completados correctamente. Se compararon los 639 IDs/títulos con la base remota: solo cambian a OK los 22 IDs del alcance; las notas históricas de cada caso se conservan. Las dos copias externas de la checklist son idénticas a la mantenida.
