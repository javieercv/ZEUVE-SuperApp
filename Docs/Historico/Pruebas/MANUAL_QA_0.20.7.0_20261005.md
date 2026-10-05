# QA manual — ZEUVE 0.20.7.0 · 05/10/2026

Marketing 0.20.7, build 73. Nueve parciales locales aceptados desde la interfaz de la copia interna Release en macOS Apple Silicon. Las operaciones utilizan `ZEUVE_DATA_DIR` con SQLite propio, fixtures sintéticos y salidas de QA; no se prueban descargas ni sesiones remotas.

## Resultado por caso

### O-18 — OK

Creación .XYZ normalizada a .xyz, edición a Modelos QA/XYZ, movimiento real del archivo y Deshacer íntegro; persistencia comprobada al reabrir la app, rechazo visible de ../fuera y eliminación de la regla en Ajustes. Datos y archivos sintéticos propios.

### C-11 — OK

Conversión manual WAV → M4A y WAV → AAC correcta; AAC publicado reimportado como AAC sin aviso falso de MP3 y convertido a FLAC. Integración nativa y validación FFprobe complementan la prueba de interfaz.

### C-48 — OK

Guardado, renombrado, fijado, duplicado, exportación JSON, eliminación e importación desde Ajustes; ambas favoritas sobreviven al reinicio. Aplicar favorita restaura FLAC y mantiene ★ Favorita QA 207 tras callbacks; un cambio real a M4A vuelve a Ninguna. Receta/calidad verificadas también con métodos Swift reales.

### I-93 — OK

PGS propio de 12 s abierto por UI; OCR local presenta exactamente tres filas ZEUVE QA UNO/DOS/TRES, 3 incluidos/0 por revisar y tiempos 0–2, 4–6, 8–10 segundos. Sin filas vacías ni duplicados. Captura y AX guardados; original intacto.

### I-96 — OK

En la hoja OCR se edita UNO a ZEUVE QA UNO revisado y se exporta I96_UI_final.srt desde el selector nativo. Lectura de salida confirma tres entradas no vacías, texto editado y tiempos 00:00:00–00:00:02, 00:00:04–00:00:06 y 00:00:08–00:00:10. Original intacto.

### I-134 — OK

Desde UI: añadir JPEG a MOV H264/AAC, sustituir por PNG, conservar editando título global y retirar; cuatro publicaciones correctas y resultados abiertos en solo lectura. Major/compatible brands qt; carátulas extraídas idénticas, paquetes de vídeo/audio SHA-256 intactos y decodificación completa. Fuentes intactas. MP4 quedó revalidado en 0.20.6.0 y conserva regresiones automáticas.

### I-135 — OK

En I99_estructura.mkv, UI elimina Video B y Video A y abre Revisar cambios. Ambas aparecen únicamente como Se eliminará, con antes/después; Copia exacta solo en los dos audios y dos subtítulos efectivos. La revisión enumera capítulos y adjunto; la portada también se revisó explícitamente en I-134. No se publica durante revisión y original intacto.

### I-161 — OK

Lote manual de MOV y MKV: regla Audio 440 → idioma deu produce 1 aplicable y 1 sin cambios. Revisar plan permite abrir ambos; MOV muestra que no genera salida y MKV identifica la regla aplicada y la clasificación. Originales intactos, sin ejecutar el lote.

### I-162 — OK

Revisión manual individual del MKV dentro del lote: cambio spa → deu, seis pistas conservadas, dos capítulos y adjunto text/plain visibles antes de ejecutar. Cambiar/eliminar la regla invalida el preflight anterior; regenerar actualiza clasificación y valores. Revisión sin publicar archivos.

## Evidencia y protección de archivos

Los originales sintéticos iniciales conservan sus nueve SHA-256; `modelo.xyz` se mueve y se restaura con Deshacer. `C11-UI-validation.json` confirma códecs AAC/AAC/FLAC y decodificación completa de las tres salidas iniciadas desde UI. `I134-UI-validation.json` acredita cuatro salidas MOV, marca QuickTime, portada esperada, paquetes de vídeo/audio idénticos y decodificación completa; JPEG/PNG extraídos coinciden con las imágenes originales. `I96_UI_final.srt` conserva exactamente tres eventos y el texto revisado.

Evidencias externas en `QA-partials-20261005`, dentro de la carpeta de visualizaciones del chat: `manual-results.json`, `UIEvidence/` (capturas y estados AX), hashes, validaciones y logs técnicos. Los dos espejos de checklist externos conservan el mismo contenido que la fuente canónica. Los 639 IDs, sus títulos y las observaciones históricas se contrastan con la base remota, sin borrar fallos anteriores.

## Incidencias del recorrido y límites

La pantalla estuvo inicialmente bloqueada y se esperó a recuperar la sesión, sin eludir el bloqueo. La primera prueba Release rechazó nombres de carpetas válidos; el fallo se reprodujo con tests optimizados y se corrigió. O-18 completo se repitió con el ejecutable final. Durante el control hubo clics que no alcanzaron el botón correcto; solo los estados y archivos verificados acreditan los resultados. Un relanzamiento auxiliar usó un nombre incorrecto para la variable de aislamiento y terminó sin interacción; los reinicios de aceptación y las operaciones posteriores usan `ZEUVE_DATA_DIR` con la ruta propia comprobada.

I-161/I-162 comprueban la revisión previa por archivo y su invalidación, sin ejecutar el lote. Las integraciones nativas comprueban ejecución y publicación por separado. I-134 conserva la aceptación manual MP4 de la entrega anterior y vuelve a ejecutar las regresiones de servicio MP4/MKV; la nueva ronda manual recorre MOV.

Checklist acumulada: **599 OK / 1 fallo / 5 parciales / 34 pendientes de 639**. D-15/D-60 y la cobertura remota de P-12 siguen excluidos expresamente. I-29 (volumen) e I-35 (sincronía) conservan el requisito de comprobación acústica: ni análisis de señales ni decodificación certifican audición. El fallo previo restante pertenece al Descargador excluido. No se certifican notarización, distribución ni cualquier archivo posible.
