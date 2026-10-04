# CHECKLIST MANUAL DE ACEPTACIÓN DE ZEUVE

Estado acumulado al 04/10/2026 · ZEUVE 0.20.5.0 (marketing 0.20.5, build 71).

**639 pruebas: 546 ✅ OK · 18 ❌ fallidas · 13 ⚠️ parciales · 62 ➖ pendientes.** Ninguna marcada como no aplicable.

Leyenda: ✅ aceptación comprobada; ❌ fallo observado; ⚠️ aceptación parcial; ➖ todavía no validada. Una casilla marcada indica prueba ejecutada con resultado concluyente; el símbolo distingue OK de fallo. Los parciales y pendientes conservan casilla vacía. Los resultados de QA se realizaron sobre una copia Debug con datos aislados y archivos sintéticos; no certifican toda la distribución Release ni cualquier entrada posible.

Confirmación manual del usuario, 28/09/2026: **O-02, A-07, A-39 y A-46–A-48 funcionan**. Estos seis puntos se marcan OK por su confirmación, no como pruebas repetidas por el agente.

Resumen: General 40/40 OK; Historial 15/15 OK; Ajustes 17/18 OK y S-16 fallido; Organizador 49/50 OK y O-18 parcial; Descargador 44/80 OK, D-13 fallido, D-15/D-60 parciales y 33 pendientes; Analizador 75/75 OK. Conversor 53/63 OK, 4 fallos (C-14/C-15/C-20/C-46) y 2 parcial (C-11/C-48), Comparador 26/27 OK, Inspector 160/180 OK, 12 fallos (I-33/I-38/I-39/I-66/I-120/I-127/I-130/I-131/I-132/I-133/I-136/I-164) y 8 parciales (I-29/I-35/I-93/I-96/I-134/I-135/I-161/I-162); Limpiador 65/75 OK, 0 fallidas, 0 parciales y 10 pendientes; Privacidad transversal 2/16 OK (P-13/P-14).

El Descargador continúa pausado por decisión del usuario para separar limitaciones de Internet de fallos de producto. Primer bloque del Conversor: 11 puntos OK (C-01–C-06, C-41, C-43, C-59, C-60 y C-63), con PNG/JPEG/HEIC/TIFF/BMP, dimensiones, carpeta, copia segura, originales, conflictos e Historial comprobados. Se decodificaron 23 archivos publicados; todas las salidas conservaron 320×180 y los cinco originales conservaron sus hashes. C-62 quedó después comprobado OK con la opción activada y un reinicio real; la prueba inicial con la opción desactivada no era un fallo. C-42 y C-45 no se dan por validados por haber completado un lote de carpeta. El avance posterior se registra prueba a prueba justo debajo. No se ha corregido producto.

## Continuidad de pruebas — guardado individual

Desde el 28/09/2026 se actualiza este archivo inmediatamente al terminar cada ID de prueba, antes de iniciar el siguiente. Los intentos incompletos no se marcan OK. Los problemas de control se anotan separados de los fallos de producto.

**Punto de continuación: L-13/L-65; después L-72–L-75 y L-54–L-57 (permanente).** Última prueba guardada: L-60, ✅. Inspector ya abordado completo. Publicación GitHub disponible; sincronizar al cierre.

- **C-07 — OK, guardado antes de comenzar C-08:** GIF sintético de 2 s y 10 fotogramas → MP4. UI: 1 correcto, 0 fallidos/omitidos/cancelados. FFprobe confirma H.264, 160×90, 5 FPS, 10 fotogramas y 2 s. El GIF original conserva su SHA-256. Esta prueba verifica GIF como entrada; no se extrapola a todas las paletas, transparencias o bucles.
- **C-08 — intento incompleto, sin cambio de casilla:** se cerró el resultado C-07 y se intentó preparar Convertir formato → WebP. El control perdió acceso a ventanas; CGSession confirmó screenLocked=1 y el proceso QA seguía vivo. No se verificó WebP seleccionado ni se ejecutó una conversión C-08. Reanudar por este ID después de desbloquear macOS, sin repetir C-07 innecesariamente.

- **C-08 — OK, guardado individual:** GIF → WebP animado por UI: 1 correcto, 0 fallidos/omitidos/cancelados. ImageIO decodifica los 10 fotogramas de 160×90, cada uno de 0,2 s (2 s en total). SHA-256 original sin cambios. FFprobe no interpreta este WebP animado, pero ImageIO verifica todos sus fotogramas: limitación del lector, no fallo de producto.

- **C-09 — OK, guardado individual:** GIF → APNG por UI: 1 correcto, 0 fallidos/omitidos/cancelados. ImageIO decodifica los 10 fotogramas de 160×90, con UnclampedDelayTime 0,2 s por fotograma (2 s). SHA-256 del original intacto. Salida independiente con extensión .apng.

- **C-10 — OK, guardado individual:** WAV sintético (tono 440 Hz, 3 s) → MP3 por UI: 1 correcto y 0 fallidos/omitidos/cancelados. FFprobe: MP3, 48 kHz, mono, 320 kb/s, 3 s. Decodificación completa FFmpeg sin errores. No se extrapola a metadatos ni otras variantes.

- **C-11 — en curso, casilla pendiente:** WAV → M4A comprobado: AAC, 48 kHz mono, 3 s, decodificación completa sin errores; UI 1 correcto y 0 fallidos/omitidos/cancelados. AAC seleccionado con una operación preparada, pero no ejecutado: macOS volvió a bloquear la pantalla (screenLocked=1), proceso QA vivo. Reanudar en AAC y guardar C-11 solo al completar la comprobación restante. Original WAV conserva SHA-256.

- **C-11 — OK, guardado individual:** Sesión recuperada. WAV → M4A y WAV → AAC por UI, cada una con 1 correcto y 0 fallidos/omitidos/cancelados. Códec AAC, 48 kHz mono; M4A 3 s y AAC ADTS 2.989562 s. Ambas salidas decodificadas completas sin errores.

- **C-12 — OK, guardado individual:** WAV → FLAC por UI: 1 correcto y 0 fallidos/omitidos/cancelados. FFprobe: FLAC, 48 kHz, mono, 3 s. Decodificación completa sin errores. Archivo separado del original.

- **C-11 — revisión posterior: PARCIAL, sustituye el OK inicial:** las salidas M4A y AAC son válidas, pero al reimportar la carpeta la app avisa que su propio AAC es MP3. FFprobe confirma AAC ADTS y cabecera FF F1. Causa probable respaldada por código: ConverterFormatDetector comprueba antes MP3 con una firma demasiado amplia que también acepta ADTS; la condición AAC queda detrás. No se corrigió. El alcance validado son las salidas; queda sin aceptar plenamente la detección de AAC como entrada.

- **C-13 — OK, guardado individual:** MP3 generado en C-10 → WAV por UI, no mera copia. 1 correcto y 0 fallidos/omitidos/cancelados. FFprobe: PCM s24le, 48 kHz mono, 1152 kb/s, 3 s. Decodificación completa sin errores. Salida independiente con doble prefijo.

- **C-14 — ❌, guardado individual:** FALLO: MP3 mono → Opus con calidad Personalizado heredada. Vista previa permitió ejecutar; resumen 0 correctos, 1 fallido. libopus rechazó 320000 bps y pidió 500–256000. No se declara fallo de control: el motor explica incompatibilidad de bitrate con esta salida. Pendiente comprobar recuperación con un bitrate compatible; sin corregir producto.

- **C-15 — ❌, guardado individual:** FALLO: WAV mono → OGG con calidad Personalizado. UI 0 correctos y 1 fallido; libopus rechaza 320000 bps y exige 500–256000. La vista previa permitía esta combinación. Mismo límite observado en C-14, ahora reproducido con otra entrada y extensión de salida. No hay salida completa publicada; sin corregir.

- **C-15 — recuperación comprobada, no borra el fallo:** al seleccionar calidad Medio, WAV → OGG sí termina con 1 correcto y 0 fallidos/omitidos/cancelados. FFprobe: Opus en Ogg, 48 kHz mono, 3,0065 s; decodificación completa sin errores. El fallo sigue asociado a Personalizado/320 kb/s con entrada mono. No se corrigió código.
- **C-14 — recuperación comprobada, no borra el fallo:** WAV → Opus en calidad Medio termina con 1 correcto y 0 fallidos/omitidos/cancelados; Opus/Ogg, 48 kHz mono, 3,0065 s y decodificación completa sin errores. Cambiar formato volvió a Personalizado, por lo que se eligió Medio de nuevo y se verificó la vista previa antes de ejecutar.

- **C-16 — ✅, guardado individual:** Calidades Bajo y Alto elegidas por UI con la misma fuente WAV: MP3 128000 y 256000 bits/s respectivamente, frente a 320000 de C-10. Cada conversión: 1 correcto y 0 fallidos/omitidos/cancelados; 48 kHz mono, 3 s, decodificación completa sin errores. Salidas sufijos 2 y 3, sin sobrescribir. La aceptación de este cambio en MP3 no borra los fallos de Opus/OGG.

- **C-17 — ✅, guardado individual:** MP4 sintético H.264/AAC, 3 s, 160×90, 15 fotogramas → MP4 recodificado por UI. 1 correcto y 0 fallidos/omitidos/cancelados. FFprobe verifica H.264, 15 fotogramas, dimensiones, duración y audio AAC mono a 48 kHz. Decodificación completa audiovisual sin errores; no mera copia.

- **C-18 — ✅, guardado individual:** MP4 → MOV por UI: 1 correcto y 0 fallidos/omitidos/cancelados. H.264, 160×90, 15 fotogramas, 3 s y audio AAC 48 kHz mono, verificados por FFprobe y decodificación completa sin errores.

- **C-19 — ✅, guardado individual:** MP4 → MKV por UI: 1 correcto y 0 fallidos/omitidos/cancelados. FFprobe: Matroska, H.264, 160×90, 15 fotogramas, 3,021 s y AAC 48 kHz mono. Decodificación completa sin errores.

- **C-20 — ❌, guardado individual:** FALLO DE PLAN/UI: MP4 H.264/AAC mono → WebM. Vista previa permite una operación y promete recodificación H.264, pero al ejecutar la app rechaza: «WebM solo puede conservar vídeo VP8, VP9 o AV1 con el motor incluido; elige MKV, MOV o MP4 para recodificar». UI 0 correctos, 1 fallido. Documentación vigente condiciona salidas a compatibilidad real y el código confirma esta limitación: no se pide añadir un encoder ni se considera que FFmpeg haya fallado. La discrepancia es ofrecer un plan ejecutable incompatible. No se ha comprobado aún remux de un WebM compatible; sin corregir.

- **C-21 — ✅, guardado individual:** AVI sintético MPEG-4/PCM → MP4 por UI: 1 correcto y 0 fallidos/omitidos/cancelados. AVI reconocido como entrada; FFprobe y decodificación íntegra verifican salida H.264/AAC, 160×90, 15 fotogramas y 3 s. Original separado de la salida.

- **C-22 — ✅, guardado individual:** Comprobación específica de recodificación en la operación C-21: entrada AVI con códec MPEG-4, salida MP4 H.264; cambio real de códec, 15 fotogramas y audio conservados. No se extrapola de una copia del mismo contenedor. En C-17 también se verificó una conversión MP4 → MP4 con recodificación anunciada por UI.

- **C-23 — ✅, guardado individual:** AVI → Extraer el audio → MP3 por UI: 1 correcto y 0 fallidos/omitidos/cancelados. FFprobe verifica un único stream MP3, 48 kHz mono, 320 kb/s, ≈3,008 s; no contiene vídeo. Decodificación completa sin errores. Original AVI y salida MP4 previa intactos.

- **C-24 — ✅, guardado individual:** WAV sintético → Crear vídeo desde audio → MP4 por UI, lienzo horizontal 1920×1080 y fondo por defecto. UI 1 correcto y 0 fallidos/omitidos/cancelados. FFprobe verifica H.264, 90 fotogramas, 1920×1080, vídeo y audio AAC ambos de 3 s; decodificación completa sin errores. No se certifica todavía la variante con imagen de fondo.

- **C-25 — ✅, guardado individual:** Modo Avanzado y copia rápida activados por UI, MP4 → MKV. Vista previa anuncia remux/copia sin recodificar. UI 1 correcto y 0 fallidos/omitidos/cancelados; vídeo H.264 160×90, 15 fotogramas, audio AAC y ≈3 s. Los SHA-256 de los 15 paquetes de vídeo coinciden exactamente entre entrada y salida, confirmando copia de vídeo. Decodificación audiovisual completa sin errores.

- **C-16 — avance intermedio histórico, cerrado en el registro posterior, casilla pendiente:** calidad Bajo aplicada por UI a WAV → MP3; 1 correcto, decodificación íntegra, 128000 bits/s, 48 kHz mono y 3 s. Salida C_audio_tono_3s 2.mp3, sin sobrescribir C-10. Falta comparar con otra calidad antes de cerrar el ID.

- **C-26 — ✅, guardado individual:** Vídeo MP4 sintético de 3 s/5 FPS → Extraer todos los fotogramas → PNG por UI. 1 correcto y 0 fallidos/omitidos/cancelados. ImageIO decodifica los 15 PNG numerados, todos 160×90. SHA-256 del vídeo original intacto.

- **C-27 — ✅, guardado individual:** Se comprueba por separado la carpeta final C_video_3s - Fotogramas en el destino QA: existe, contiene exactamente los 15 fotogramas numerados y no conserva una carpeta Procesando. Corresponde a la extracción real C-26, no a un directorio creado por el controlador.

- **C-28 — ✅, guardado individual:** Crear tiempos.csv estaba activado en UI. El CSV real de C-26 contiene cabecera y 15 filas: índices 1–15, tiempos 0–2,8 s en incrementos de 0,2 y duración de 0,2 s cada uno (total 3 s). Concordancia con los 15 PNG y la fuente.

- **C-29 — ✅, guardado individual:** Extracción sintética de 120 s/3600 fotogramas: segundo intento cancelado por el botón Cancelar durante la fase Convirtiendo. UI: 0 correctos, 0 fallidos/omitidos y 1 cancelado. La carpeta pasa a C29_cancelar_120s - Fotogramas - converted - Incompleto; sus 237 PNG conservados se decodifican completos a 1280×720. Fuente SHA-256 intacta y sin proceso FFmpeg residual. El primer intento acabó antes de alcanzar Cancelar y no se utilizó para aceptar este ID. No se encontró tiempos.csv en la carpeta cancelada; se registra sin extrapolar la validación de C-28 al CSV parcial.

- **C-61 — ✅, guardado individual:** Comprobación específica sobre la cancelación C-29: UI no cuenta el trabajo como correcto y la salida conservada se etiqueta Incompleto. Los 237 PNG publicados se validaron completos con ImageIO; no se conservó un último fotograma truncado ni una carpeta Procesando. Esta aceptación se limita al flujo de extracción probado, no a todos los motores.

- **INC-14 — fallo adicional confirmado después de C-29:** con macOS desbloqueado, la tarjeta sigue en Finalizado/1 cancelado; los botones para importar, Quitar todas y Convertir tienen enabled=false, aunque FFmpeg ya terminó. Navegar a Historial y volver al Conversor no recupera el módulo. No es el bloqueo de pantalla ni un fallo del controlador: System Events lee los controles reales y las opciones de receta siguen habilitadas. Causa probable: cancel() cancela executionTask pero no restablece state; los guard !Task.isCancelled de executePlan() retornan antes de pasar a result/preview, dejando state=.running e isBusy=true. Se conserva C-29 OK para su requisito concreto de fotogramas Incompleto y se registra aparte la recuperación de UI fallida, sin inventar un ID adicional ni aceptar C-46 (lote todavía no probado). Se reinicia normalmente solo la copia QA después de guardar esta evidencia; no se corrige producto.

- **C-30 — ✅, guardado individual:** 15 PNG sintéticos seleccionados por carpeta propia, sin tiempos.csv, → Crear vídeo desde una secuencia de imágenes → MP4 por UI. Resultado: 1 correcto y 0 fallidos/omitidos/cancelados. FFprobe: H.264, 1920×1080, 15,04 s, 16 fotogramas decodificados; 15 imágenes a 1 s por defecto y último fotograma repetido según el manifiesto de secuencia. Decodificación íntegra FFmpeg sin errores y 15/15 hashes fuente intactos. La ruta ofrecida para esta secuencia es vídeo; no se afirma animación directa ni reordenación manual, que no está implementada.

- **C-31 — ✅, guardado individual:** 15 PNG → Crear un PDF con imágenes por UI: 1 correcto y 0 fallidos/omitidos/cancelados. PDF real de 15 páginas, 160×90 puntos, sin cifrado. Poppler renderiza las 15 páginas a 160×90; revisión visual de la hoja de contacto confirma el patrón y los índices 0–14 en orden, sin páginas en blanco ni recorte. Se conserva el PDF separado de las fuentes.

- **C-32 — ✅, guardado individual:** PDF generado en C-31 → Convertir páginas de PDF en imágenes → PNG por UI. 1 correcto y 0 fallidos/omitidos/cancelados; carpeta Páginas con 15 PNG numerados. ImageIO decodifica todos completos a 667×375 (rasterización por defecto a 300 DPI). Hoja de contacto revisada contra el render independiente Poppler: índices 0–14 en orden, contenido conservado, sin páginas vacías.

- **C-33 — ✅, guardado individual:** PDF sintético de dos páginas con texto real → Extraer texto del PDF por UI: 1 correcto y 0 fallidos/omitidos/cancelados. TXT publicado contiene ambos encabezados, el número 12345 y los acentos á/é/í/ó/ú/ñ, en orden y separados por página. No se usa el PDF de imágenes de C-31 para simular OCR; no hay OCR en el alcance.

- **C-34 — ✅, guardado individual:** PDF sintético AES-256 de dos páginas: Extraer texto sin contraseña devuelve el aviso correcto y no publica TXT. Tras introducir la contraseña de QA mediante el campo visible, termina 1 correcto/0 fallidos y el TXT coincide con C-33. Al cerrar el resultado, el campo vuelve a seguro y vacío. Consultas de solo lectura: 0 coincidencias de la contraseña en ajustes e Historial; tampoco en los logs aislados. Hash del PDF protegido intacto. Dos intentos de escritura que no llegaron al binding del campo se separan como control, no como contraseña rechazada por producto. Esta verificación no certifica borrado forense de RAM.

- **C-38 — ✅, guardado individual:** Archivo CSV propio con cabecera fotograma/tiempo_segundos/duracion_segundos y 15 filas, copia del C-28. Importación individual por UI: 1 entrada compatible identificada CSV · 194 bytes, sin aviso de formato incorrecto. Se comprueba reconocimiento, no una conversión de tablas ni compatibilidad con Excel.

- **C-39 — ✅, guardado individual:** JSON sintético válido con objeto, lista, booleano y texto UTF-8. Importación individual por UI: 1 entrada compatible identificada JSON · 75 bytes, sin aviso de extensión/contenido distinto. Se comprueba reconocimiento, no transformación arbitraria de JSON.

- **C-40 — ✅, guardado individual:** XML sintético bien formado, con declaración UTF-8, elemento raíz y dos campos. Importación individual por UI: 1 entrada compatible identificada XML · 101 bytes, sin aviso de formato incorrecto. Se verifica reconocimiento, no conversión XML↔JSON ni validación de cualquier esquema.

- **C-44 — ✅, guardado individual:** ZIP propio con dos PNG importado mediante el botón ZIP: UI enumera las dos entradas y prepara dos conversiones a JPEG. Ejecución: 2 correctos y 0 fallidos/omitidos/cancelados. Salidas independientes dentro de C44_dos_imagenes - Converted; ImageIO confirma ambos JPEG 160×90. SHA-256 del ZIP idéntico antes/después. Se valida ZIP simple, no ZIP cifrado, anidado, corrupto ni todas las reglas de seguridad.

- **C-45 — ✅, guardado individual:** Lote real de dos vídeos sintéticos de 120 s: se observaron ambos nombres, Convirtiendo, porcentajes por archivo, transcurrido/restante aproximado y progreso global creciente de 0 a 0,96. Al terminar A, 1 correcto y progreso global 0,5; después avanzó B. Resumen final en 35 s: 2 correctos y 0 fallidos/omitidos/cancelados. Ambas salidas H.264 1280×720, 120 s/3600 fotogramas, decodificación íntegra sin errores; hashes de las dos fuentes intactos. No se deduce el progreso solo del resumen.

- **C-46 — ❌, guardado individual:** FALLO DE RECUPERACIÓN, INC-14 reproducida con lote: dos vídeos, Cancelar pulsado durante Convirtiendo. El motor se detiene y la tarjeta Finalizado contabiliza 0 correctos/fallidos/omitidos y 2 cancelados; no hay FFmpeg activo ni nuevas salidas parciales publicadas. Sin embargo, Quitar todas y Convertir siguen enabled=false y no se ofrece un nuevo resumen para continuar. Las dos fuentes y las dos salidas completas anteriores conservan sus hashes. La cancelación técnica funciona, pero el flujo de lote no se recupera; se marca fallido y no se corrige.

- **C-47 — ✅, guardado individual:** Dos presets incorporados aplicados por UI y ejecutados con entradas adecuadas: Imagen PNG sin pérdida selecciona PNG/Máxima calidad y produce copia con hash idéntico; Audio MP3 de alta calidad selecciona MP3/Máxima calidad y genera MP3 320 kb/s, 48 kHz mono, 3 s, decodificado íntegro. Cada operación: 1 correcto y 0 fallidos/omitidos/cancelados. Se prueban estos dos presets, no todas las combinaciones de presets con formatos.

- **C-48 — ⚠️, guardado individual:** PARCIAL, INC-15: Guardar como favorita crea Conversión desde resultado y se persiste en universalConverter.favorites.v1. Después de cambiar la receta a FLAC/Bajo, aplicar la favorita restaura MP3/Máxima calidad y ejecuta 1 correcto/0 fallidos; salida MP3 320 kb/s de 3 s, decodificada íntegra. Sin embargo, la UI vuelve inmediatamente a Favorita: Ninguna y Preajuste: Configuración actual, pese a restaurar la receta guardada. Causa probable: aplicar opciones programáticamente dispara onChange de calidad; qualityChanged() borra selectedFavoriteID/selectedPresetID. No se han probado renombrado, duplicado, fijado ni exportación/importación de favoritos; sin corregir.

- **C-49 — ✅, guardado individual:** EPUB sintético mínimo (mimetype EPUB y estructura de contenedor) seleccionado por Un archivo. UI: «C49.epub: formato de libro electrónico no compatible (EPUB).» No se añade ninguna entrada compatible ni receta de conversión; no se convierte ni se instala un motor retirado.

- **C-50 — ✅, guardado individual:** Fixture sintético de cabecera BOOKMOBI seleccionado por UI. Aviso explícito «C50.mobi: formato de libro electrónico no compatible (MOBI).» Sin entrada compatible ni conversión. Se verifica el rechazo de la firma/extension, no la integridad de un libro MOBI completo.

- **C-51 — ✅, guardado individual:** Dos fixtures de extensión .azw y .azw3, sin DRM y con cabecera sintética BOOKMOBI, seleccionados por UI. Ambos se rechazan expresamente como libro electrónico no compatible; aviso adicional AZW3 frente a contenido MOBI coherente con el fixture. Sin receta ni conversión. Se comprueba política de rechazo de ambas extensiones, no lectura de un libro Kindle completo.

- **C-52 — ✅, guardado individual:** FB2 sintético XML con raíz FictionBook, metadatos y cuerpo de texto seleccionado por UI. Aviso claro «C52.fb2: formato de libro electrónico no compatible (FB2).» No aparece como entrada convertible ni se procesa mediante Pandoc u otro motor.

- **C-53 — ✅, guardado individual:** EPS sintético con cabecera PS-Adobe/EPSF, BoundingBox y rectángulo local. UI indica «C53.eps: el formato EPS se reconoce, pero ya no es compatible con el Conversor.» No se ofrece conversión ni se invoca Ghostscript; no se reintroduce ese motor.

- **C-54 — ✅, guardado individual:** Ambas extensiones .doc y .docx rechazadas por UI con «los formatos ofimáticos no son compatibles con el Conversor» y sin entradas convertibles. Fixtures adversariales: PNG propio renombrado, para comprobar que la política de extensión retirada no lo reinterpreta como imagen. No se afirma haber leído documentos Word reales; no se usa LibreOffice.

- **C-55 — ✅, guardado individual:** Ambas extensiones .xls y .xlsx seleccionadas y rechazadas claramente por UI como formatos ofimáticos no compatibles; ninguna entrada convertible. PNG sintéticos renombrados para probar la barrera por extensión retirada, no hojas de cálculo reales ni parsing Excel. No se convierte ni se incorpora dependencia ofimática.

- **C-56 — ✅, guardado individual:** Las dos extensiones .ppt/.pptx se seleccionan y reciben el aviso explícito de formatos ofimáticos no compatibles, sin entradas convertibles. Fixtures adversariales PNG renombrados: confirma rechazo por extensión incluso con contenido convertible; no prueba lectura de presentaciones reales.

- **C-57 — ✅, guardado individual:** ODT, ODS y ODP seleccionados separadamente por UI. Los tres muestran «los formatos ofimáticos no son compatibles con el Conversor», sin convertirlos ni admitirlos como imágenes por su contenido PNG de QA. Se verifica barrera por las tres extensiones retiradas, no parsing de documentos OpenDocument reales.

- **C-58 — ✅, guardado individual:** RTF sintético con cabecera rtf1 seleccionado individualmente. Aviso «C58.rtf: los formatos ofimáticos no son compatibles con el Conversor», sin entrada compatible, receta ni conversión. Todos los rechazos C-49–C-58 se guardaron por ID al terminar, sin interpretarlos como conversiones fallidas.

- **C-62 — ✅, guardado individual:** Se activa Recordar la última carpeta por Ajustes en la copia QA y se vuelve a elegir output por panel nativo. Preferencia comprobada en UI (1), cierre normal y relanzado con los mismos datos aislados. Tras importar una imagen, Salida recupera /tmp/zeuve-converter-qa.uPwA7J/output sin volver a elegirla; vista previa prepara destino output/ZEUVE Converted. Se verifica el reinicio real, no solo SQLite. La opción queda activada únicamente en los datos QA.

- **C-42 — intento de control incompleto, pendiente:** se abrió Seleccionar varios archivos y se intentó seleccionar los 15 PNG propios. El panel nativo cambió la columna accesible y la selección múltiple no pudo confirmarse; se canceló sin importarla. No se cuenta la carpeta C-30 como sustituto del selector múltiple. Se continúa con C-44, sin fallo de producto por este intento.
- **C-35–C-37 — pendientes por entorno, no fallo:** la copia QA no incorpora Pandoc ni lo muestra como motor disponible. No se instala ni se cambia el empaquetado para estas pruebas; las tres conversiones condicionales de TXT/Markdown/HTML siguen sin aceptar. Se continúa por C-38.


- **F-01 — ✅, guardado individual:** ZIP sintético completo seleccionado por panel nativo; aparece F01_exportacion.zip y catálogo de following.json, followers_1.json y followers_3.json bajo una raíz arbitraria. UI informa 4 entradas y solo 3 JSON necesarios; botón Analizar exportación disponible. Se verifica importación/catálogo, todavía sin iniciar comparación. No se usa un ZIP de datos reales.

- **F-03 — ✅, guardado individual:** Comprobación específica del catálogo ya importado: following.json localizado por sufijo bajo raiz_arbitraria/connections/followers_and_following/, tamaño 324 bytes; no se exige que connections sea la raíz del ZIP. No se deduce solo del nombre externo.

- **F-04 — ✅, guardado individual:** Catálogo UI muestra followers_1.json (127 bytes) y followers_3.json (181 bytes), junto a following.json. Detecta los dos archivos y anuncia 3 JSON necesarios de las 4 entradas ZIP. La comparación de sus contenidos se comprobará después de pulsar Analizar.

- **F-10 — ✅, guardado individual:** Tras importar el ZIP y esperar durante las comprobaciones del catálogo, la UI permanece en importación, sin resultados. Historial del módulo conserva 7 entradas previas antes de pulsar Analizar; no se crea una comparación automáticamente. El botón requiere la acción explícita que se realizará a continuación.

- **F-05 — ✅, guardado individual:** El ZIP con followers_1.json y followers_3.json, sin followers_2.json, se analiza por UI y muestra resultados (5 seguidores, 5 seguidos, 2 archivos). Se acepta el hueco de numeración tanto en catálogo como en comparación completa. ZIP original conserva su SHA-256.

- **F-11 — ✅, guardado individual:** Resumen UI: 5 seguidores, coincidente con los cinco nombres únicos del fixture repartido entre followers_1 y followers_3. El duplicado gamma con espacios/mayúsculas no aumenta el total; se comprueba el resultado de la app, no solo la expectativa del generador.

- **F-12 — ✅, guardado individual:** Resumen UI: 5 cuentas seguidas, coincidente con las seis relaciones de following y cinco nombres normalizados. Mutuo repetido con @/espacios/mayúsculas se cuenta una vez; ZIP permanece intacto.

- **F-13 — ✅, guardado individual:** Categoría No te siguen de vuelta: lista UI exacta zeuveqa_alfa, zeuveqa_beta y zeuveqa_zeta, 3 de 3. Coincide con seguidos menos seguidores del fixture; no se infiere por contar solo tarjetas.

- **F-14 — ✅, guardado individual:** Categoría Te siguen y tú no les sigues seleccionada por UI: lista exacta delta, epsilon y gamma con prefijo zeuveqa_, 3 de 3. Coincide con seguidores menos seguidos, incluyendo href /_u/ y compatibilidad media_list_data del fixture.

- **F-15 — ✅, guardado individual:** Categoría Seguimiento mutuo seleccionada: UI muestra ZeuveQA_Mutuo y zeuveqa.punto, 2 de 2. Coincide con la intersección, respeta normalización sin distinguir mayúsculas y conserva representación visible; sin cuentas exclusivas en la lista mutua.

- **F-16 — ✅, guardado individual:** Búsqueda EPSI introducida por UI en categoría de tres seguidores no seguidos. Tras el debounce, contador 1 de 3 y única fila zeuveqa_epsilon. Coincidencia parcial e insensible a mayúsculas, sin iniciar otra lectura/análisis.

- **F-17 — ✅, guardado individual:** Con búsqueda vacía, categoría No te siguen de vuelta muestra alfa, beta, zeta (prefijo zeuveqa_) en orden ascendente A–Z. Se inspeccionan las tres filas en orden, no solo el contador.

- **F-18 — ✅, guardado individual:** Botón de orden pulsado en la misma categoría: filas zeta, beta, alfa (prefijo zeuveqa_), orden inverso exacto Z–A. Cuenta y categoría sin cambios; no se inicia análisis nuevo.

- **F-21 — ✅, guardado individual:** Exportación de toda la categoría No te siguen de vuelta a TXT por UI. Hoja anuncia 3 cuentas; panel nativo guarda F21_categoria.txt en carpeta QA y aviso confirma 3. Archivo real: exactamente alfa, beta, zeta (prefijo zeuveqa_), un nombre por línea y sin otras categorías. Se exporta categoría completa, no solo contador.

- **F-22 — ✅, guardado individual:** CSV publicado por el panel nativo: cabecera real username,category,url y exactamente alfa/beta/zeta con prefijo zeuveqa_, categoría no_te_siguen_de_vuelta y URL pública correspondiente. Lector CSV independiente confirma 3 filas y UTF-8 válido; aviso UI confirma 3 cuentas. Una expectativa del controlador de URL en mayúsculas se ajustó a la cabecera real url; no se considera fallo de producto.

- **F-23 — ✅, guardado individual:** Búsqueda beta deja solo zeuveqa_beta en la tabla. Exportar CSV con Solo cuentas visibles activado anuncia 1 cuenta y publica exactamente una fila beta, con categoría y URL correctas, sin alfa/zeta. Se registra aparte el texto menor «1 cuentas» del diálogo, no un fallo del filtrado/exportación.

- **F-24 — ✅, guardado individual:** Destino limitado al CSV sintético F22_categoria.csv: macOS muestra «ya existe, ¿Quieres reemplazarlo?» y advierte sobre el contenido. Cancelar conserva SHA-256 df438f…2299; al repetir y confirmar Reemplazar explícitamente, el aviso de ZEUVE confirma 3 cuentas y el CSV mantiene el contenido/hash esperado. No hay sustitución silenciosa ni datos reales afectados.

- **F-19 — ✅, guardado individual:** ZIP estructuralmente válido con listas vacías: comparación termina con 0 seguidores/0 seguidos y las tres categorías muestran 0 de 0 y «No hay cuentas en esta categoría / La exportación no contiene resultados para esta comparación», sin error de archivo. Antes, el fixture no vacío con consulta sincoincidenciaqa mostró 0 de 3 y «No hay coincidencias / Prueba con otro nombre de usuario». Ambos estados distintos comprobados por UI; ZIP vacío conserva SHA-256.

- **F-06 — ✅, guardado individual:** Modo JSON separados: following.json y un followers_1.json seleccionados individualmente por panel nativo. Catálogo muestra ambos y la comparación termina con 5 seguidos/3 seguidores, 2 mutuos y única cuenta gamma en Te siguen y tú no les sigues, conforme a este conjunto reducido. Hashes de ambos originales intactos. Se verifica modo avanzado con un archivo followers válido; no se afirma selección múltiple por este ensayo.

- **F-07 — ✅, guardado individual:** ZIP con la misma ruta followers_1.json duplicada: rechazo al importar, aviso explícito «El ZIP contiene archivos en conflicto: entrada duplicada» con la ruta del fixture. No se entra en comparación ni se confunde con una exportación sin seguidores; no se modifica producto.

- **F-08 — ✅, guardado individual:** ZIP catalogado correctamente, pero followers_1.json contiene bytes JSON malformados. Al pulsar Analizar aparece «followers_1.json no contiene un JSON válido», sin publicar resultados de comparación. Mensaje identifica el archivo y el error de sintaxis.

- **F-09 — ✅, guardado individual:** followers_1.json sintácticamente válido pero raíz objeto incompatible con la lista de seguidores. Analizar muestra «followers_1.json es un JSON válido, pero no tiene una estructura de seguidores compatible». Se distingue del JSON inválido de F-08 y de las listas vacías válidas de F-19; no publica comparación falsa.

- **F-26 — ✅, guardado individual:** Historial UI filtrado al Comparador: primera fila «Comparación de seguidores» correspondiente a F-06, 5 seguidos/3 seguidores, 3 no te siguen/1 no sigues/2 mutuos y Archivos JSON/1 archivo. El análisis real aparece con métricas agregadas, sin nombres de cuenta en esta fila.

- **F-27 — ✅, guardado individual:** Las comparaciones ZIP normal, vacío y JSON separados se han ejecutado y mostrado resultados usando únicamente archivos sintéticos locales, sin pantalla de login, cuenta de Instagram, contraseña ni cookies. La aceptación cubre completar el flujo sin iniciar sesión; no se afirma auditoría forense de tráfico de red.

- **F-25 — ✅, guardado individual:** Segundo intento con ZIP propio de 150.000 seguidos/100.000 seguidores: Cancelar presente y habilitado, pulsado durante el análisis. Aviso «La comparación se ha cancelado. No se han guardado listas parciales»; importación/Cambiar selección/Analizar vuelven habilitados. Historial permanece en 11 registros (sin nueva comparación cancelada) y SHA-256 fuente intacto. El primer intento terminó por un error de sintaxis del controlador antes de cancelar y no se usa como aceptación; tampoco el fixture inicial con rutas ZIP no compatibles. No reproduce el bloqueo de recuperación del Conversor.

- **F-20 — ✅, guardado individual:** Botón Abrir Instagram de la fila zeuveqa_alfa: abre en el navegador predeterminado una pestaña con URL exacta https://www.instagram.com/zeuveqa_alfa/. La cuenta sintética no existe y la web responde página no disponible; eso no se atribuye a ZEUVE. Se comprueba construcción/apertura del enlace, sin login, lectura de perfiles reales ni acciones en Instagram. La sesión preexistente del navegador no se usa para los análisis locales de F-27.

- **F-02 — control incompleto, pendiente:** Finder muestra seleccionado únicamente F01_exportacion.zip en la carpeta propia y ZEUVE ofrece el área de soltar ZIP. El arrastre de CUA no cambia el catálogo ni permite verificar que se entregó un archivo a la app. No se marca fallo ni se sustituye esta prueba por el selector F-01. Se reserva para revisión manual y se sigue por I-01.
- **Cierre del Comparador:** 26/27 OK y F-02 pendiente; sin fallos formales nuevos en F. Tras Cancelar F-25, un nuevo análisis pequeño vuelve a terminar con 5 seguidos/5 seguidores, confirmando recuperación real. Detalles menores de pluralización («1 cuentas», «1 archivos») anotados para informe, sin corrección. Evidencias sintéticas propias fuera del repositorio; los originales reales del usuario no se usaron.

- **I-01 — ✅, guardado individual:** Selector nativo abre C_video_3s.mp4 sintético. UI muestra nombre, Resumen técnico y Modo inspección solo lectura, sin pasar a lote ni editar. FFprobe independiente confirma archivo válido de 3 s con H.264/AAC.

- **I-04 — ✅, guardado individual:** MP4 sintético reconocido como QuickTime/MOV: H.264 160×90 a 5 FPS, AAC mono 48 kHz y 3 s. Resumen técnico coincide con inspección independiente de los streams y no presenta error de apertura.

- **I-03 — ✅, guardado individual:** MKV sintético de 30 s y 5 streams abre correctamente en modo solo lectura. Resumen coincide con FFprobe: H.264 320×180, 10 FPS, dos pistas PCM 48 kHz, un subtítulo SubRip y un adjunto. SHA-256 be88d4…98bb5 intacto.

- **I-07 — ✅, guardado individual:** Resumen y encabezado muestran Matroska/WebM para el MKV y QuickTime/MOV para MP4, coincidiendo con las familias format_name devueltas por FFprobe. Se verifica el contenedor, sin confundirlo con el códec H.264.

- **I-08 — ✅, guardado individual:** MKV: encabezado 00:00:30 y Resumen 0 h 00 min 30 s, coincidente con duración independiente 30.000000. MP4 anterior muestra 3 s, también exactos.

- **I-16 — ✅, guardado individual:** Abrir MKV tras MP4 reemplaza nombre, dimensiones 160×90→320×180, duración 3→30 s, audio 1→2 y subtítulos 0→1. No conserva los resultados de sonoridad automáticos del MP4 mono-pista; nuevo archivo muestra sus propios capítulos/adjunto y sigue en solo lectura. Se valida este cambio de sesión, no todos los estados posibles.

- **I-09 — ✅, guardado individual:** Pestaña Pistas del MKV muestra vídeo H264 · 320×180 · 10.000 FPS, coincidente con stream 0 del fixture. No se interpreta el adjunto como vídeo ni se cuenta como pista audiovisual.

- **I-10 — ✅, guardado individual:** Pistas enumera dos audios distintos: spa/Tono 440 QA y eng/Tono 880 QA, ambos PCM_S16LE a 48 kHz, primero Default. A/B identifica índices #1 y #2, canales 1 y bitrates 768 kb/s; concuerda con FFprobe.

- **I-11 — ✅, guardado individual:** Pistas muestra un subtítulo spa · SUBRIP · Texto · Texto QA, correspondiente al stream 3 interno del MKV. Se comprueba que aparece su pista; todavía no se certifica reproducción/sincronización de los textos.

- **I-12 — ✅, guardado individual:** Resumen muestra Capítulos · 2, coincidente con los dos capítulos del MKV. Al expandir aparecen dos filas accionables con ayuda «Reproducir desde el inicio del capítulo». Se comprueba presencia y cantidad; el control AX no expone el texto interno de esas filas, por lo que no se certifica aún título/timing visible ni seek a capítulo.

- **I-14 — ✅, guardado individual:** Adjuntos e imágenes · 1 expandido muestra Stream 4 · attachment con acciones de extracción/copia. Pistas también enumera el stream 4 en Otros streams solo lectura. Coincide con adjunto.txt text/plain del fixture; no se afirma extracción ni edición en este ID.

- **I-13 — ✅, guardado individual:** Metadatos muestra globales title=ZEUVE QA Inspector, ARTIST, COMMENT y QA_UNKNOWN con valores sintéticos exactos. Por stream: títulos/idiomas de los dos audios y subtítulo; attachment filename=adjunto.txt, mimetype=text/plain. Coincide con FFprobe/fixture; modo lectura, sin editar tags.

- **I-05 — ✅, guardado individual:** MOV propio creado por remux del vídeo sintético: selector abre I05_video.mov, UI QuickTime/MOV · H264 · 160×90 · 5 FPS · 3 s, solo lectura. Concuerda con FFprobe (H.264/AAC, 3 s). No se usa renombrado de extensión como sustituto del contenedor real.

- **I-06 — ✅, guardado individual:** WebM real VP8/Opus propio: UI Matroska/WebM, VP8 160×90 5 FPS y 3 s. FFprobe confirma audio Opus y duración 3,016 s; la lectura inicial del control apuntó al grupo sin subtítulos, no se usa para afirmar el detalle de audio en UI. Se abrió con los motores empaquetados de ZEUVE; solo para crear el fixture se usó FFmpeg Homebrew ya instalado, ya que el empaquetado carece del encoder VP8. Sin instalar dependencias ni modificar la app.

- **I-15 — ✅, guardado individual:** MP4 sintético con JPEG attached_pic: Adjuntos e imágenes · 1 expandido muestra imagen y «Carátula · stream 2 · mjpeg» con acciones de extracción/copia. FFprobe confirma disposición attached_pic=1 separada del vídeo principal H.264; original conserva SHA-256. Se acepta detección/presentación, no todavía extracción ni revisión visual del color de la miniatura.

- **I-17 — ✅, guardado individual:** Cerrar análisis devuelve pantalla inicial con selector/lote. Desaparecen nombre, estructura, pestañas y controles de preview de I15_caratula.mp4. No hay diálogo de descarte cuando no existen cambios; original sigue intacto.

- **I-98 — ✅, guardado individual:** Editar cambia explícitamente a Modo edición: borrador limpio y muestra campos permitidos de metadatos. Deshacer/Rehacer/Revisar cambios inicialmente deshabilitados, coherentes con ausencia de modificaciones. No se ejecuta edición sobre el archivo original.

- **I-18 — ✅, guardado individual:** Se cambia el título del borrador a Titulo borrador QA, UI indica cambios pendientes. Cerrar análisis exige «Descartar cambios / Hay cambios sin publicar…» con Conservar y Descartar. Conservar mantiene sesión y título editado; repetir y Descartar vuelve al inicio. SHA-256 MKV intacto antes/después, sin publicar edición. Protege el borrador mediante confirmación explícita.

- **I-19 — ✅, guardado individual:** Escuchar la pista WAV PCM de 30 s inicia preview: transporte pasa de 00:01 a 00:02/00:30 en lecturas sucesivas y FFmpeg empaquetado decodifica como hijo de la app. Se acepta inicio y avance de Play; no se afirma comprobación auditiva del altavoz.

- **I-20 — ✅, guardado individual:** Pausa pulsada durante Play a 00:23/00:30. La lectura inmediatamente posterior y otra 1,2 s después permanecen en 00:23; no avanza otro segundo ni vuelve a cero. Se comprueba respuesta del transporte, no percepción auditiva ni benchmark de latencia submilisegundo.

- **I-21 — ✅, guardado individual:** Reanudar desde Pausa 00:23 conserva ese instante y avanza a 00:25/00:30 tras 1,2 s, sin reiniciar. Se vuelve a pausar para comprobar saltos y velocidades. No se afirma escucha del altavoz.

- **I-24 — ✅, guardado individual:** Retroceder en el transporte lleva el audio pausado de 00:25 a 00:10/00:30, salto de 15 s configurado en esta copia QA. El seek conserva la sesión y no cambia de archivo.

- **I-23 — ✅, guardado individual:** Avanzar lleva el audio pausado de 00:10 a 00:25/00:30, salto de 15 s. Una lectura 0,8 s después permanece en 00:25: seek no reanuda Play accidentalmente.

- **I-25 — ✅, guardado individual:** Selector Velocidad ofrece 0,5×/0,75×/1×/1,25×/1,5×/2×. Elegir 0,5× conserva Pausa/00:25 y la observación posterior confirma 0,5×, sin reiniciar; la lectura AX inmediatamente tras el clic todavía decía 1× por actualización asíncrona. La velocidad real se contrasta por separado en los siguientes IDs.

- **I-26 — ✅, guardado individual:** Con 0,5× aplicado, Play desde 00:10 y Pausa tras 4 s de espera deja 00:12/00:30. Control muestra 0,5×. Avance aproximado 2 s, coherente con media velocidad, no solo selección visual; no se certifica calidad/tono auditivo.

- **I-27 — ✅, guardado individual:** Seleccionar 1× y reanudar conserva posición inicial ≈00:12; tras 4 s de espera y Pausa la UI muestra 00:15/00:30 y 1×. Contraste aproximado a resolución de segundos (3 s mostrados, con arranque/actualización incluidos), no una medición de reloj de alta precisión ni una tasa exacta garantizada.

- **I-28 — ✅, guardado individual:** Con 2× aplicado, Play conserva ≈00:16; tras 4 s de espera y Pausa UI muestra 00:23/00:30 y 2×. Avance aproximado 7 s con resolución a segundos y arranque incluidos, frente a ≈2 s a 0,5× y ≈3 s a 1×; coherente con doble velocidad. No certifica pitch/calidad auditiva.

- **I-02/I-22 — pendientes de control:** CUA devuelve native pipe closed al leer el Inspector y al solicitar captura. Se sigue mediante System Events; no se ejecuta un arrastre verificable en I-02 ni un seek directo sobre la timeline custom AXUnknown en I-22. No son fallos confirmados de producto. I-12 verifica dos capítulos/filas, no títulos/timing visuales ni seek de capítulo; I-15 verifica imagen y attached_pic representados en UI, no revisión visual del color de miniatura.
- **I-29 — avance de control, pendiente de aceptación audible:** escritura AX del slider no cambia su valor (permanece 1). Foco + flechas sí permite 0,0 → 0,4 → 1,0 y se restaura 1; diferencia de control, no prueba de volumen roto. Sin escuchar la salida no se certifica mute/ganancia acústica. Play/Pausa/Reanudar y velocidades anteriores se aceptan para transporte/avance observado, no para calidad/latencia acústica; I-33 sigue pendiente. Preview detenido al cerrar el turno, sin procesos FFmpeg/FFprobe residuales.
- **Preparación I — incidencias ajenas a ZEUVE:** el engine empaquetado no incluye encoder VP8 y rechazó deadline al crear un fixture WebM. FFmpeg Homebrew ya instalado sí incluye VP8; tampoco incluye libvorbis, por lo que se generó VP8/Opus con libopus. Estos errores ocurren en el generador propio, no al abrir WebM en la app. No se instala ni añade un motor a ZEUVE. Un selector de grupo apuntó a Sin pistas de subtítulos; no se usó para certificar audio WebM en UI. Los fixtures se conservan en /tmp/zeuve-inspector-qa.cyTrxb.

- **I-30 — ✅, guardado individual:** MKV sintético de dos audios: preview spa/Tono 440 pausado en 00:02/00:30; cambiar a eng/Tono 880 actualiza la identidad de pista y conserva exactamente 00:02. No vuelve a cero ni cambia de archivo.

- **I-32 — ✅, guardado individual:** Cambio 440→880 desde Pausa: 00:02 se mantiene inmediatamente tras la carga y en otra lectura 1,2 s después. Conserva Pausa; no se interpreta el botón Escuchar de otra pista como petición de reanudar.

- **I-31 — ✅, guardado individual:** Reanudar eng/Tono 880 en 00:03, cambiar a spa/Tono 440 durante Play: posición sigue en 00:03 al cargar y avanza a 00:04 tras 1,2 s, sin pulsar Play de nuevo. Identidad actualizada y reproducción conservada; se pausa al terminar el ensayo.

- **I-42 — ✅, guardado individual:** Botón Pantalla completa del reproductor, identificado por ayuda específica: AXFullScreen de la ventana Inspector multimedia cambia false→true tras la transición. Se comprueba la ventana propietaria de la copia QA, no una ventana global distinta.

- **I-43 — ✅, guardado individual:** El mismo botón devuelve AXFullScreen a false y conserva Inspector multimedia y su sesión. Entrada/salida completas comprobadas por estado nativo; no se extrapola al escalado/aspect ratio del vídeo, todavía pendientes.

- **I-46 — ✅, guardado individual:** Selector Subtítulos ofrece la pista interna spa/Texto QA/SUBRIP; seleccionarla y reproducir el vídeo muestra ZEUVE QA UNO en 00:01/00:30, dentro de su evento 1–4 s. Se pausa conservando el texto. Activación/extracción textual real comprobada, no solo nombre en selector.

- **INC-17 — anomalía reproducida del transporte de vídeo sin audio activo, sin corregir:** I47_dossubtitulos.mkv (30 s, H.264) reabierto mediante Analizar otro archivo para limpiar la sesión. Pistas → botón del único vídeo: el título cambia a H264, pero seis lecturas consecutivas a intervalos de 1 s mantienen 00:00 / 00:30; tras la siguiente pulsación, otras dos lecturas mantienen cero. Una nueva pulsación y cinco lecturas más vuelven a mantener cero. También se había reproducido durante ocho lecturas en la sesión anterior. No hay alerta de error. La lectura accesible no permite certificar movimiento o conservación del fotograma, por lo que I-34–I-41 no se aceptan ni se marcan fallidos solo por esta evidencia. Causa probable, no demostración interna: startVideoOnlyPreview inicia el monitor antes de completar scheduleVideoPreview; el monitor puede leer el servicio de vídeo todavía idle/paused, sobrescribir previewState y salir. Además refreshPreviewSnapshot consulta el servicio de audio cuando previewSourceID identifica vídeo aunque activePreviewSource sea nil, pudiendo restablecer posición/título desde una sesión de audio idle. Se registra el fallo observable del reloj y queda pendiente confirmar visualmente el frame y aislar cuál de estas carreras lo causa. Fixture SHA-256 a8dff5f35b0bd06de213b37ead1669f74c01d254f6320a25deca71fb6954a164. I-48 sigue pendiente; no se confunde el fallo de CUA con esta lectura repetida de la UI real.

- **I-47 — ✅, guardado individual:** Selector eng · ASS QA · ASS activado con audio en pausa a 00:02. La UI muestra un evento ASS QA UNO procedente de la pista ASS real del MKV. Activación verificada, no estilos avanzados ni SSA separado. Incidencia adicional de presentación INC-18: el texto accesible incluye literalmente <font size="18">ASS QA UNO</font>; la conversión ASS→SRT introduce etiquetas y el servicio las conserva como texto plano, que MultimediaPreviewPlayerView entrega a Text sin interpretarlas. Queda por comprobar visualmente si esas etiquetas son visibles también en pantalla; no se afirma todavía ese aspecto como fallo visual confirmado.

- **I-49 — ✅, guardado individual:** Con el transporte en pausa a 00:02, cambiar ASS→SRT sustituye el evento por ZEUVE QA UNO; volver a ASS lo sustituye por <font size="18">ASS QA UNO</font>. No mueve el tiempo ni exige reanudar. Se guardan las diferencias de contenido entre pistas reales; no se certifican estilos ASS (INC-18).

- **I-50 — ✅, guardado individual:** Elegir Desactivados elimina el evento ASS del texto visible/accesible a 00:02; el selector confirma Desactivados y el transporte permanece pausado en el mismo tiempo. No desaparecen las pistas del catálogo ni se altera el archivo.

- **I-51 — ✅, guardado individual:** SRT activo y audio pausado: capítulo Segundo QA lleva a 00:10 y muestra ZEUVE QA DOS; capítulo Inicio QA vuelve a 00:00 y elimina el evento. El salto cambia el texto sin Play y conserva pausa. Comprobado contra tiempos SRT 10–14 y ausencia de evento en 0; sin extrapolar al transporte de vídeo sin audio afectado por INC-17.

- **I-48 — ✅, guardado individual:** Con audio 440 Hz activo y SRT seleccionado, lecturas durante reproducción: UNO visible a 2–4 s, ausente a 5–7; DOS visible a 10–14 s, ausente a 15–16. Coincide con eventos SRT 1–4 y 10–14. La lectura a 00:01 (redondeada) aún no mostraba UNO; no permite medir precisión subsegundo y no se usa como fallo. Aceptación del timing textual en transporte con audio, no sincronización audiovisual ni vídeo sin audio (INC-17).

- **I-52/I-53 — control visual pendiente, sin cambio de casillas:** la waveform expone AXValueDescription con posición/duración, pero su Canvas no expone los buckets generados; no se da por comprobada la generación del dibujo solo por tener controles. Dos clicks System Events calculados al 25 % y 75 % dentro del rectángulo accesible de la waveform no cambiaron el tiempo (seguía 00:16); no se ha demostrado que llegaran al DragGesture de SwiftUI, por lo que se anota como limitación de control para revisión manual, no como fallo confirmado de seek.

- **I-54 — ✅, guardado individual:** Durante Play, el reproductor y AXValueDescription de la waveform coinciden en 00:17, 00:18 y 00:19 de 00:30; en pausa ambos permanecen en 00:19. Se comprueba el playhead expuesto por accesibilidad, no el dibujo píxel a píxel ni la generación del Canvas (I-52 pendiente).

- **I-55 — ✅, guardado individual:** Aumentar zoom cambia vista completa 30 s por rango textual 00:11.919–00:26.919 (15 s), centrado en playhead ≈19.4 s. Reducir vuelve a vista completa y deshabilita Reducir zoom; el transporte permanece en pausa a 00:19. Se verifica rango/control real; el redibujado del Canvas requiere revisión visual.

- **I-56 — ✅, guardado individual:** Con zoom 15 s, Pan atrás cambia rango 00:11.919–00:26.919 a 00:04.419–00:19.419; Pan adelante restaura el rango anterior. Vista completa elimina el rango acotado. Playhead 00:19 permanece en pausa. Se verifica desplazamiento/rango, no dibujo del Canvas.

- **I-59 — ✅, guardado individual:** Pista #1 spa PCM_S16LE, Mezcla, Hann/FFT4096, Lineal, -120…0 dB. Actualizar transforma estado Espectrograma sin generar en resultado con ejes frecuencia/tiempo y leyenda de decibelios; Exportar PNG pasa de deshabilitado a habilitado, sin alerta y sin motor residual. Se verifica resultado generado por la app, no se infiere correspondencia frecuencial hasta inspeccionar exportación.

- **I-65 — ✅, guardado individual:** Exportar PNG publica I65_tono440.png en la carpeta QA elegida, 1600×900 y 47.664 bytes. sips decodifica dimensiones y revisión visual del PNG real confirma raster no vacío con banda tonal horizontal. UI confirma exportación, panel se cierra y original MKV conserva SHA-256 a8dff5…a164. No se certifican todavía todos los formatos, conflictos o ejes en PNG; no hay etiquetas/ejes en este raster exportado.

- **I-60 — ✅, guardado individual:** Se generaron y exportaron dos resultados separados: #1 spa/440 Hz → I65_tono440.png; #2 eng/880 Hz → I60_tono880.png. Ambos PNG 1600×900 decodificados con AppKit y revisados visualmente: la banda tonal de la segunda pista está más alta. Lectura independiente de píxeles: máximo rojo fila 882 y 866, aproximadamente 454 y 881 Hz en eje lineal 0–24 kHz (raster ≈26,7 Hz/píxel, no medición exacta del tono). Confirma que no reutiliza sin cambiar el resultado de la primera pista. Primer Actualizar enviado inmediatamente al cerrar el menú no produjo resultado; repetir después de estabilizar la selección sí lo hizo: intento rápido de control documentado, no fallo formal.

- **I-63 — ✅, guardado individual:** Desde controles propios de Espectrograma, Aumentar zoom muestra 00:11.919–00:26.919 y Pan atrás 00:04.419–00:19.419; Vista completa restablece el rango. No desaparece el resultado ni cambia pista/posición. Se valida el viewport textual compartido; el gesto directo y el dibujo del playhead permanecen pendientes (I-61/I-62).

- **I-64 — en curso, sin cambio de casilla:** resultado de la pista #2/880 Hz generado. Elegir Logarítmica y después Lineal conserva el resultado y Exportar PNG habilitado. Escribir el valor AX del slider no actualiza el binding; AXDecrement sí cambia Rango: -120…0 dB a -125…0 dB sin pulsar Actualizar y sin borrar el resultado. Un muestreo acotado de hijos FFmpeg no detecta ejecuciones, pero no constituye una traza exhaustiva. Faltaba completar contraste/exportación del cambio visual. macOS se bloquea (CGSession screenLocked=1); System Events deja de ver window 1 aunque PID 39084 sigue vivo. I64_log880.png no llegó a crearse, no se interpreta la ausencia de ventana como fallo de ZEUVE. Reanudar tras desbloquear en esta misma pista y comprobar el selector/menú real antes de cualquier clic. I-64 permanece pendiente; último ID cerrado I-63. Estado global 366 OK, 6 fallos, 5 parciales, 262 pendientes; Inspector 45/180 OK.

- **I-64 — ✅, guardado individual:** Retomado tras desbloquear: #2/880 Hz, FFT4096/Hann y resultado existente. Sin Actualizar, Lineal→Logarítmica y AXIncrement del rango -125→-120 dB mantienen resultado y Exportar PNG habilitado. Muestreo solapado 6 s/104 lecturas no detecta FFmpeg hijo de ZEUVE. Exportación I64_log880.png 1600×900, revisada visualmente: banda desplazada por escala logarítmica; SHA distinto de I60_tono880.png. No decodificación observada y código reutiliza fullSpectrogram para rango/render. Aceptación de estos cambios visuales, no de FFT/ventana/canal que requieren nuevo análisis ni garantía de traza de procesos exhaustiva.

- **I-66 — ❌, guardado individual:** FALLO GEOMÉTRICO INC-19: ventana QA en (240,33), 1055×724, límite inferior y=757. En Espectrograma generado con vídeo/audio y aviso de exportación, Play (527,791), 46×21, Fullscreen (1028,790) y Stop (1224,791) quedan íntegramente por debajo de la ventana. Pistas coloca Stop en y=685 dentro de la misma ventana; volver a Espectrograma reproduce y=791 sin redimensionar. Los controles siguen en AX, pero no caben en la superficie visible. No se infiere de falta de captura: se comparan frames nativos con ventana propietaria. Causa probable: VStack de inspected combina mínimos del espectrograma/controles con preview de vídeo y aviso sin adaptación/scroll del conjunto. No se corrige; falta captura visual complementaria, no se certifican otros tamaños.

- **I-67 — ✅, guardado individual:** WAV sintético PCM 48 kHz mono/30 s abierto por UI; resultado automático muestra -21.8 LUFS. Contraste independiente FFmpeg loudnorm, solo análisis a null: input_i=-21.75 LUFS, coincide al redondear a una decimal. Original sin conversión ni publicación de audio; no se extrapola a otros materiales.

- **I-68 — ✅, guardado individual:** La sonoridad de la misma pista muestra LRA 0.0 LU. Referencia loudnorm input_lra=0.00 en el tono constante de 30 s. Coherente para esta señal sin dinámica; no se afirma cobertura de rangos variables ni gates de otros materiales.

- **I-69 — ✅, guardado individual:** UI muestra TP -18.1 dBTP. Análisis independiente loudnorm input_tp=-18.06 dBTP: coincide al redondear. Se acepta cálculo/presentación del true peak de este PCM, no prevención de clipping ni todas las variantes de sobremuestreo.

- **I-70 — ✅, guardado individual:** UI muestra Peak -18.1 dBFS. Lectura independiente de los 1.440.000 samples PCM16 del WAV: máximo absoluto 4095/32768, sample peak -18.0639205773 dBFS, coincide al redondear. SHA-256 original 2c2eb7…abcd4 intacto.

- **I-75 — ✅, guardado individual:** Abrir WAV de una sola pista ejecuta automáticamente señal, sonoridad y espectrograma sin pulsar sus botones. Pistas ya contiene ausencia de silencios/clipping y LUFS/LRA/picos; al abrir Espectrograma existe resultado con Exportar PNG habilitado. Preferencias aisladas: automatización de espectrograma/señal/sonoridad activadas y avanzado desactivado. No se exige análisis avanzado cuando está desactivado ni se extrapola a todas las configuraciones.

- **I-72 — ✅, guardado individual:** Fixture nuevo PCM16 mono/48 kHz, 12 s: tono 0.1, silencio exacto 2–4 s y plateau de amplitud máxima 6–6.2 s. Apertura automática muestra 1 silencios · 2.0 s. Lectura PCM independiente confirma 96.000 muestras cero entre 2 y 4 s, con señal antes/después. Se valida detección/cantidad/duración, no marcador visual de timeline (I-74 pendiente). SHA 466c7672fb93301b2b9511bc84ec1d3a310aeadce3637386a60b82c6e2d0a68b. Detalle UX: singular presentado como 1 silencios, sin impacto en detección.

- **I-73 — ✅, guardado individual:** La misma entrada con plateau 6–6.2 s muestra 1 posibles clippings y Peak -0.0 dBFS; lectura independiente confirma 9.600 muestras consecutivas en 32767, resto del tono máximo 3277. Frente al WAV de tono bajo anterior, que no produjo clipping, el positivo coincide con una saturación sintética controlada. No se extrapola a diagnosis del origen del clipping ni marcadores visuales. INC-20 menor de pluralización: 1 silencios / 1 posibles clippings procede de textos fijos de signalAnalysisLine, sin corregir.

- **I-76 — ✅, guardado individual:** Reabrir MKV de dos pistas limpia los análisis anteriores. Tras estabilizar la inspección, ambas pistas carecen de señal/sonoridad; tabla A/B mantiene n/d para Integrated/LRA/picos/silencios/clipping. Espectrograma indica sin generar y Exportar PNG deshabilitado. No hay FFmpeg/FFprobe residual. Las mismas opciones automáticas estaban activadas, pero no se analizó arbitrariamente la primera pista. Selección inicial del picker no se confunde con inicio de análisis pesado.

- **I-77 — ✅, guardado individual:** Fixture propio con tres audios PCM: #1 spa/440, #2 eng/880 y #5 fra/1320 Hz. Selector A cambia desde #1 a #5 · fra · Tono 1320 QA; B permanece en #2 y slot activo A. La tercera pista permite elegir una alternativa sin colisionar con B. Verificado por UI, no solo defaults.

- **I-78 — ✅, guardado individual:** Selector B cambia de #2/880 a #1 · spa · Tono 440 QA. A permanece #5/fra/1320 y slot activo A; pistas distintas verificadas. No comienza Play ni análisis al elegir las pistas.

- **I-79 — ✅, guardado individual:** Play de A (#5/fra/1320) y Pausa a 00:02. Seleccionar B (#1/spa/440) cambia título de pista pero conserva 00:02; lectura 1 s después sigue 00:02. Se comprueba instante común entre pistas elegidas en el comparador real, no usando botones individuales de las filas.

- **I-80 — ✅, guardado individual:** Cambio A→B en Pausa conservó 00:02 durante 1 s. Después Play de B avanza a 00:04; elegir A conserva 00:04 y avanza sin otro Play a 00:06 tras 1.5 s. Se pausa A a 00:06. A/B mantiene ambos estados, no solo la selección del slot.

- **I-81 — ✅, guardado individual:** Antes de Play A/B el selector Espectrograma era #1 spa; tras alternar A(#5/fra) y B(#1/spa), termina A activo con footer fra · Tono 1320 QA/00:06 pero el selector de Espectrograma sigue #1 spa PCM_S16LE. Comprobado en UI antes/después, no se cambió silenciosamente para seguir la pista de preview.

- **I-82 — ✅, guardado individual:** Completar análisis A/B muestra fase Analizando #5/fra y termina con tabla real A(#5): -20.2 LUFS; B(#1): -21.8 LUFS. Ambas: LRA0, TP/Peak -18.1, 0 silencios/clippings, tiempo silencio0.000. Desaparece estado Completando y no hay alerta/motor residual. Filas individuales contienen esos resultados para #1/#5, mientras #2/880 no tiene análisis: no procesa arbitrariamente la tercera. Preview permanece en pausa 00:06. Fuente SHA e9dfa4335e93f4ba3dd3ca9d15aaf7aba8a06ae4ecc410de110ca39fa7e4ef6e.

- **I-83 — ✅, guardado individual:** Acción Análisis avanzado identificada por ayuda en fila #1/440 Hz del MKV de tres audios. UI muestra Analizando indicios y anomalías espectrales y después resultado Evidencia insuficiente, rolloff y evidencia explicativa, sin alerta ni FFmpeg residual. Termina el análisis local sin confundirlo con la pista activa A/#5.

- **I-84 — ✅, guardado individual:** Resultado del tono #1 se presenta como Evidencia insuficiente · confianza descriptiva 55 %. Explica que un tono o contenido muy estrecho carece de ocupación espectral suficiente y no se interpreta como cutoff. Se comprueba nivel y explicación, no una probabilidad estadística calibrada de 55 % ni una certificación de procedencia.

- **I-85 — ✅, guardado individual:** La UI del análisis real muestra Rolloff 99,5 %: 457 Hz y evidencia titulada Cobertura espectral insuficiente, con explicación específica del tono estrecho. No rellena arbitrariamente banda efectiva/cutoff cuando no hay evidencia. Métrica visible coherente con señal de 440 Hz y resolución FFT; no se da por probado todo el conjunto de evidencias posibles.

- **I-86 — ✅, guardado individual:** Tres materiales sin codec con pérdida: tono440 → Evidencia insuficiente; ruido con seis lowpass → Sin indicios claros (rolloff6012/banda9609); ruido con corte FFT≈6 kHz → Indicios fuertes, rolloff5953/banda6129/candidata6082 Hz, persistencia100 %. En este último explica explícitamente que puede deberse a contenido/filtrado/fuente con pérdida y por sí sola no demuestra compresión previa. No afirma fake lossless pese al corte real creado localmente. Aceptación de redacción prudente y caso de cutoff, no de exactitud universal de clasificación. SHA fuente abrupta259d653b78ecc0c4c79a937169f9c066f776d02396d67193a054ebb2ebf20a11.

- **I-87 — ✅, guardado individual:** Fixture PCM16 mono12 s con tono440 de0–4,4000 de4–8 y880 de8–12, sin silencio/clipping. Análisis avanzado termina y muestra 2 anomalías temporales, coherentes con los dos cambios deliberados; la clasificación general sigue Evidencia insuficiente por señal estrecha y no convierte el transitorio en prueba de origen con pérdida. Casos anteriores constantes no mostraban eventos. No se acepta aún dibujo de overlays (I-89 pendiente). SHA8ed12fbddb458252694cfc1e2bf2e2d186a1bb8cdccc3e29f917bff42ce68772.

- **I-88 — ✅, guardado individual:** Se exporta por UI el JSON técnico real I88_eventos.json para comprobar datos temporales. Dos eventos Cambio espectral brusco: 3.968–4.053333 s y7.978667–8.064 s, envolviendo cambios sintéticos conocidos a4 y8 s. totalAnomalyCount2, anomaliesWereTruncatedfalse. No son solo un contador ni coordenadas inferidas del código; se validan tiempos generados por la app. I-89 dibujo de overlays sigue pendiente de revisión visual.

- **I-172 — ✅, guardado individual:** Durante I-88 se eligió explícitamente JSON en menú de informe y se publicó I88_eventos.json por panel en carpeta QA. JSON.parse lo decodifica íntegro, schemaVersion3, nombre correcto, datos técnicos y advancedAudio con dos eventos. UI confirma Informe técnico exportado y no hay alerta. Se cierra este ID por la exportación real, aunque se cruzó de orden para verificar tiempos; no se extrapola a TXT/Markdown aún.

- **I-173 — ✅, guardado individual:** JSON técnico de WAV12 s comprobado: schema3, nombre sin ruta, una pista PCM16 mono48k/768000bps, duración12; LUFS -21.8/LRA4/TP-20/Peak-19.99947 coinciden con UI. Señal sin eventos y análisis avanzado con dos intervalos conocidos; timeline sonoridad120 muestras. No contiene /tmp/, fingerprint original ni sourceID. Se acepta contenido esperado de este WAV y secciones activas, no todas las combinaciones de metadata/OCR/edición.

- **I-174 — ✅, guardado individual:** Exportación JSON sobre resultados ya calculados: muestreos solapados a apertura del panel (6 s/102 lecturas) y publicación (4 s/68) no observan hijos FFmpeg/FFprobe. No aparece estado Analizando ni se alteran resultados; JSON contiene exactamente el análisis previo. exportTechnicalReport usa resultados existentes. Aceptación de ausencia de nuevo análisis inesperado en esta exportación, no traza exhaustiva del sistema.

- **I-170 — ✅, guardado individual:** Formato Texto elegido por menú, panel en carpeta QA, publica I170_informe.txt UTF-8 legible. Contiene nombre, contenedor, duración12, PCM16/48k/mono, timing, LUFS/LRA/picos, señal y resumen avanzado con2 anomalías. No rutas completas ni original reemplazado. TXT resume anomalías, no muestra los intervalos individuales del JSON; se acepta este formato según la salida vigente. Una lectura demasiado temprana del panel falló; esperar a ventana Exportar informe técnico permitió guardarlo, sin fallo de producto.

- **I-171 — ✅, guardado individual:** Formato Markdown elegido explícitamente; I171_informe.md publicado separado en carpeta QA. Contiene encabezado # Informe técnico multimedia y secciones ## Metadatos globales/Streams/Sincronización/Sonoridad calculada/Análisis de señal/Análisis avanzado, con los mismos datos y2 anomalías que TXT/JSON. UTF-8 y acentos legibles; source SHA8ed12f…68772 intacto. No se cambia producto.

- **I-90 — ✅, guardado individual, 03/10/2026:** Entrada sintética PGS validada con FFprobe y decodificación independiente de todos los bitmaps. La UI detecta 1 subtítulo spa · HDMV_PGS_SUBTITLE · Bitmap en I90_bitmap.mkv, vídeo H.264 640×360 y 12 s. SHA-256 c577cb6cce977effdf4c1e3da6d35244b0a2b4c6cda8aaec44d078cc742e26ec. Sesión nueva con datos propios QA-20261003.oGJ5vx/Data; la antigua /tmp ya no existe. App Debug existente 0.20.5/build 71; ninguna recompilación ni cambio de producto.

- **I-91 — ✅, guardado individual, 03/10/2026:** Al pulsar OCR de la pista bitmap #1 aparece la hoja OCR de subtítulos bitmap y se completa el reconocimiento local: textos ZEUVE QA UNO/DOS/TRES reconocidos al 100 %. El borrador contiene 12 filas; la calidad temporal se revisa por separado en I-93.

- **I-93 — ⚠️, guardado individual, 03/10/2026:** Produce una hoja revisable con texto, inclusión, inicio/fin y 12 filas, pero la estructura temporal es incorrecta (INC-21). La entrada validada tiene tres eventos 0–2, 4–6 y 8–10 s. UI: UNO 0–1999.999 s, DOS 4000–5999.999 s, TRES 8000–9999.999 s, duplicados de texto y 6 filas vacías incluidas; fin de una fila 4294977295.000 s. FFmpeg extrae nombres con PTS en microsegundos y el servicio los multiplica por la base original 1/1000; además trata frames de borrado/EOF como eventos. Borrador visible, aceptación temporal incompleta; sin modificar producto.

- **I-94 — ✅, guardado individual, 03/10/2026:** La hoja real muestra spa y HDMV_PGS_SUBTITLE, Stream 1, Confianza 100 % en las filas con UNO/DOS/TRES y Confianza 0 % + Revisar en las vacías. Resumen 12 incluidos · 6 por revisar. Se verifica la presentación de idioma/confianza; persiste la incidencia temporal INC-21 de I-93.

- **I-95 — ✅, guardado individual, 03/10/2026:** Se edita por teclado el TextEditor de la primera fila: ZEUVE QA UNO → ZEUVE QA UNO REVISADO; el valor real queda actualizado al cambiar el foco. La corrección pertenece únicamente al borrador de QA y se verificará también en el SRT publicado. No se corrige código ni el archivo de entrada.

- **I-96 — ⚠️, guardado individual, 03/10/2026:** Exportar SRT publica I96_sin_retemporizar.srt como archivo nuevo y conserva la corrección ZEUVE QA UNO REVISADO. Sin embargo, exporta también el timing inválido y las filas vacías de INC-21: primera entrada hasta 00:33:19,999 y última hasta 1193049:14:55,050 para un vídeo de 12 s. El formato se escribe, pero el resultado no es utilizable tal como se genera; aceptación parcial. SHA-256 original intacto.

- **I-97 — ✅, guardado individual, 03/10/2026:** Tras OCR, revisión, exportación y cierre de la hoja, Pistas sigue mostrando únicamente el subtítulo spa · HDMV_PGS_SUBTITLE · Bitmap, sin añadir ni sustituir por SRT. La sesión permanece en modo inspección/solo lectura; SHA-256 c577cb6cce977effdf4c1e3da6d35244b0a2b4c6cda8aaec44d078cc742e26ec idéntico antes/después. El SRT se publica aparte.

- **I-92 — ✅, guardado individual, 03/10/2026:** Entrada sintética larga: 300 eventos PGS, 1198 s y 975 KB. Se inicia OCR, se observa la hoja en estado activo (5 botones; Cancelar disponible), se pulsa Cancelar antes de completar y la hoja desaparece. No quedan hijos FFmpeg/FFprobe de PID 41759; OCR y Analizar otro archivo vuelven habilitados. UI permanece utilizable en solo lectura sin mensaje de error ni SRT publicado por esta operación. No se utiliza el resultado rápido anterior como prueba de cancelación.

- **I-135 — ⚠️, guardado individual, 03/10/2026:** Revisar cambios abre el plan antes de ejecutar y enumera dos audios, dos SRT, dos capítulos, un attachment y Video A/Video B como eliminados. Pero muestra simultáneamente dos filas Vídeo · H264 · Copia exacta, aunque el borrador ya no contiene vídeo (INC-22). Causa respaldada por MultimediaEditPreview: enumera inspection.videoStreams en vez de plan.videoTracks. La revisión está disponible pero contradice la estructura prevista; aceptación parcial. Pendiente contrastar la ejecución real I-99.

- **I-136 — ❌, guardado individual, 03/10/2026:** Generar archivo nuevo tras quitar ambos vídeos falla en validación final: «un adjunto original ha cambiado de códec». I99_sin_video.mkv no se publica; el original sigue intacto. FFprobe no proporciona codec_name para el attachment text/plain. MediaEditableAttachment.from representa el ausente como «attachment» y sameCodec compara con nil normalizado a cadena vacía: probable falso rechazo (INC-23). Se conserva el fallo y se probará sin ese attachment para aislar la edición audiovisual; no se corrige producto.

- **I-121 — ✅, guardado individual, 03/10/2026:** En Metadatos, después de entrar en edición, Otros tags · solo lectura conserva QA_UNKNOWN = Etiqueta conservada. También se muestran tags técnicos ENCODER/DURATION y filename/mimetype del attachment. No se extrapola todavía a su preservación en una salida publicada.

- **I-122 — ✅, guardado individual, 03/10/2026:** Metadatos limita los campos editables a nueve tags globales permitidos y título/idioma de streams. QA_UNKNOWN, ENCODER, DURATION y MIME/nombre originales aparecen como textos en Otros tags · solo lectura, con acciones de copia y sin TextField asociado. Mensaje de UI explica la preservación de tags no reconocidos y evita editarlos indiscriminadamente.

- **I-123 — ✅, guardado individual, 03/10/2026:** Resumen → Adjuntos · 1 despliega el attachment adjunto_qa.txt con MIME text/plain, ayuda contextual, Extraer y eliminación del borrador. Metadatos también muestra filename/mimetype y Pistas identifica Stream 6 · attachment · sin códec. Se valida su representación técnica; no se afirma un visor de contenido de texto que la app no ofrece.

- **I-124 — ✅, guardado individual, 03/10/2026:** Extraer publica I124_adjunto_extraido.txt en la carpeta QA. cmp confirma identidad byte a byte con el archivo sintético originalmente adjuntado; SHA-256 94883f0a3aee01adb2caa01b5ceed53eba4a7700249ece7d6cd526ed9d46decb. UI informa de extracción y protección del multimedia original. No se sobrescribe adjunto_qa.txt.

- **I-125 — ✅, guardado individual, 03/10/2026:** Se elimina el attachment del borrador; la UI muestra Sin adjuntos editables y el plan 0 conservados · 0 añadidos · 1 eliminados. Al ejecutar esta variante, FFprobe confirma cero streams attachment en I99_sin_video_sin_adjunto.mkv. El attachment permanece en el original, cuyo SHA-256 no cambia. Se retira solo de la salida nueva.

- **I-99 — ✅, guardado individual, 03/10/2026:** Eliminados Video A y Video B del borrador. La variante sin el attachment que provocaba INC-23 publica correctamente un MKV nuevo de 10 s con 0 vídeo, 2 PCM_s16le, 2 SUBRIP y 2 capítulos. Ambas pistas de audio decodifican completas sin errores. La app abre el resultado en solo lectura. Esta aceptación aislada no borra el fallo de publicación I-136 con attachment ni la contradicción del plan I-135.

- **I-137 — ✅, guardado individual, 03/10/2026:** Después del intento fallido con attachment y de la publicación correcta sin él, I99_estructura.mkv mantiene exactamente su SHA-256 inicial 44b372cc5f6342c40ec314141964ee1f02ff03ee85f1d630638eb5a48744187f. Las acciones del borrador y la ejecución crean/validan otra salida sin modificar el original.

- **I-138 — ✅, guardado individual, 03/10/2026:** La variante publicada I99_sin_video_sin_adjunto.mkv coincide con el borrador efectivo: exactamente 2 audios PCM_s16le (spa/Audio 440 y eng/Audio 880), 2 subtítulos SUBRIP (spa/eng), 2 capítulos a 0/5 s; cero vídeos y cero attachments. FFprobe confirma estructura y 10 s. Persiste la incidencia de presentación del plan INC-22, que no alteró esta salida.

- **I-143 — ✅, guardado individual, 03/10/2026:** Tras validación/publicación, la misma app cambia automáticamente a I99_sin_video_sin_adjunto.mkv y lo abre en modo inspección · solo lectura, duración 10 s, sin alerta. FFprobe inspecciona su estructura y FFmpeg decodifica completas ambas pistas de audio. No se confunde la mera existencia de un archivo temporal con una publicación correcta.

- **I-100 — ✅, guardado individual, 03/10/2026:** Se elimina Audio 440 del borrador original y se retira el attachment para aislar INC-23. I100_sin_audio440.mkv se publica/abre correctamente: 2 H.264, 1 PCM_s16le eng/Audio 880 y 2 SUBRIP; Audio 440 ya no existe en la salida. Decodificación audiovisual completa sin errores. El original mantiene ambas pistas.

- **I-139 — ✅, guardado individual, 03/10/2026:** Comparación independiente SHA-256 de los paquetes codificados: los 100 paquetes de Video A, 100 de Video B y 469 de Audio 880 son idénticos, en el mismo orden, entre original y salida I100_sin_audio440.mkv (mapeo 0→0, 1→1, 3→2). No se deduce stream copy solo por igualdad de códec; se contrasta el payload real. Decodificación completa de los dos vídeos y del audio sin errores.

- **I-101 — ✅, guardado individual, 03/10/2026:** Se elimina SUBRIP spa del borrador de I100_sin_audio440.mkv. I101_solo_eng.mkv se publica y se abre en solo lectura; FFprobe confirma un único subtítulo SUBRIP eng, dos vídeos y Audio 880 conservados. La pista retirada ya no aparece en la salida nueva.

- **I-102 — ✅, guardado individual, 03/10/2026:** Añadir audio inspecciona WAV PCM_s16le mono 48 kHz, 10 s, tono sintético 1320 Hz, e incorpora una segunda pista al borrador. I102_con_audio_externo.mkv se publica y abre con los dos vídeos, Audio 880, el audio externo y el SRT eng. Los 118 paquetes del WAV son idénticos a los de la nueva pista #3 (SHA agregado 69f50adf8d2b8447c4dd9fc2ac06893cdc020c6b229ba30a51e230ab3517c3ba), confirmando copia del audio añadido.

- **I-103 — ✅, guardado individual, 03/10/2026:** Añadir subtítulo inspecciona subs_spa.srt e incorpora una segunda pista SUBRIP al borrador. I103_con_sub_externo.mkv se publica/abre y FFprobe confirma dos SUBRIP (#4 original eng, #5 externo). Los dos paquetes/textos externos conservan sus hashes de datos exactos frente al SRT de entrada. No sustituye la pista previa.

- **I-104 — ✅, guardado individual, 03/10/2026:** Añadir pista de vídeo desde I90_bitmap.mkv añade únicamente su H.264 640×360, sin importar su PGS. La salida I104_con_video_externo.mkv contiene tres vídeos (dos 320×180 previos + uno externo 640×360), dos audios y dos SUBRIP; se publica y abre con 12 s. Los 120 paquetes del vídeo externo coinciden exactamente con su fuente. No hay transcode audiovisual.

- **I-105 — ✅, guardado individual, 03/10/2026:** Mover pista abajo cambia Video A/Video B a Video B/Video A, manteniendo el tercer vídeo externo. I105_video_reordenado.mkv publica ese orden: títulos B, A, externo 640×360. Hashes de todos los paquetes de las tres pistas coinciden con el mapeo previo 0→1, 1→0, 2→2. Orden real comprobado, no solo cambio visual del borrador.

- **I-106 — ✅, guardado individual, 03/10/2026:** Mover Audio 880 abajo coloca primero el audio externo 1320 Hz. I106_audio_reordenado.mkv publica las pistas en ese orden (#3 externo, #4 eng/Audio 880). Los 469 paquetes de 880 Hz y 118 del externo coinciden exactamente tras el intercambio 3→4 y 4→3. Sin recodificación.

- **I-107 — ✅, guardado individual, 03/10/2026:** Mover el SRT eng abajo coloca primero el SRT externo en español. I107_sub_reordenado.mkv publica el orden #5 externo y #6 eng. Los dos paquetes de cada subtítulo mantienen su identidad de datos con el intercambio 5→6 y 6→5; se comprueban las pistas reales de salida.

- **I-108 — ✅, guardado individual, 03/10/2026:** Se cambia el título de la primera pista de audio a Audio externo QA en el borrador. La publicación I108_titulo_audio.mkv conserva ese título exactamente en el stream #3 según FFprobe; Audio 880 mantiene su título independiente. UI permite revisar y ejecutar el cambio.

- **I-109 — ✅, guardado individual, 03/10/2026:** Se cambia el idioma de Audio externo QA a fra. I109_idioma_audio.mkv se publica; FFprobe confirma language=fra en #3 y conserva language=eng/título Audio 880 en #4. El valor del borrador y el de la salida coinciden.

- **I-110 — ✅, guardado individual, 03/10/2026:** Se activa Default en Audio externo QA y Forced en el primer SRT. La UI cambia audio 00→10 y subtítulos 0000→0100. I110_dispositions.mkv publica exactamente default=1 en audio #3 y forced=1 en subtítulo #5, con las demás pistas de esas clases en 0. FFprobe confirma las dispositions reales.

- **I-111 — ✅, guardado individual, 03/10/2026:** Se elige Video B como único vídeo Default/principal en MKV. El borrador cambia flags 010→100 y desmarca Video A automáticamente. I111_video_principal.mkv publica default=1 en Video B #0 y default=0 en Video A #1 y externo #2, confirmado por FFprobe. No se afirma la elección de un reproductor externo distinto.

- **I-112 — ✅, guardado individual, 03/10/2026:** En un borrador limpio de I111_video_principal.mkv se desmarca Default del primer audio (10→00). Deshacer restituye 10, vuelve a Modo edición: borrador limpio y habilita Rehacer. La acción revierte el estado del borrador sin ejecutar ni alterar el archivo publicado.

- **I-113 — ✅, guardado individual, 03/10/2026:** Rehacer tras I-112 vuelve a aplicar la retirada de Default (10→00), muestra Editando un borrador con cambios pendientes y habilita Deshacer. El ciclo ida/vuelta se comprueba en las casillas reales; no se publica otro archivo por Undo/Redo.

- **I-142 — ✅, guardado individual, 03/10/2026:** Cancelar edición con un borrador modificado solicita Descartar cambios. Conservar mantiene la sesión y sus cambios; al repetir y elegir Descartar vuelve a modo inspección · solo lectura. I111_video_principal.mkv conserva SHA-256 40b881cb5d468cf5c24369be1a8f8ad7ad4a12bb51a12ed5c18e6df0e9bb5fb6, sin nueva salida ni motores residuales. Se valida salida/descarte del modo edición; no se extrapola a cancelar una ejecución FFmpeg larga.

- **Continuidad técnica, 03/10/2026:** las antiguas carpetas /tmp de QA habían desaparecido. Se utiliza la app Debug existente 0.20.5/build 71 de DerivedData, con almacenamiento aislado y fixtures persistentes en /Users/javiercv/.codex/visualizations/2026/09/27/01a0e339-8047-7950-991a-cd8b4c6e6344/QA-20261003.oGJ5vx. PID 41759; queda abierta en I111_video_principal.mkv, Pistas/solo lectura, sin preview ni motores activos. 35 IDs cerrados en esta continuación: 31 OK, 1 fallo, 3 parciales; 639 IDs/títulos originales conservados. CUA funcionó inicialmente y después volvió a cerrar su pipe; se prosiguió con AppleScript autorizado. Un botón por ordinal alcanzó el transporte al cambiar el layout; el guard del panel evitó escribir/publicar nada y se reidentificó Generar en el plan real. Son incidencias del control y no se cuentan como fallos de la app. INC-23 contrastada además con remux independiente: attachment original y copiado mantienen codec_name ausente, 49 bytes de extradata idénticos, nombre y MIME iguales. Ningún cambio de producto, build, motores o configuración personal. Al cierre, CGSession confirma screenLocked=1: las 35 pruebas ya estaban terminadas y guardadas; no se intenta I-114 ni se realizan más acciones UI. Retomar capítulos tras recuperar acceso a la pantalla, conservando este checkpoint. Remoto inicial/final sin novedades en 3cc4e1b9d7e5929fdd44c36cbfae2a6d1f3fdad2; verificación de IDs/títulos/estados y documentación correcta.

- **I-114 — ✅, guardado individual, 03/10/2026:** Añadir capítulo en posición actual crea Capítulo 3 en 9,900 s (el transporte redondea a 00:10). El plan muestra 3 capítulos; la salida nueva I114_capitulo_anadido.mkv contiene 0–5 Inicio QA, 5–9,9 Segundo QA y 9,9–12 Capítulo 3, confirmado con FFprobe. I111_video_principal.mkv conserva SHA-256 40b881cb5d468cf5c24369be1a8f8ad7ad4a12bb51a12ed5c18e6df0e9bb5fb6.

- **I-115 — ✅, guardado individual, 03/10/2026:** Eliminar Segundo QA retira exclusivamente el marcador de 5 s. Borrador y salida I115_capitulo_eliminado.mkv contienen Inicio QA 0–9,9 y Capítulo 3 9,9–12; los finales se recalculan automáticamente. FFprobe confirma dos capítulos, y la entrada I114 sigue conteniendo tres.

- **I-116 — ✅, guardado individual, 03/10/2026:** Entrada real por teclado renombra Capítulo 3 a Final QA - capitulo renombrado. La salida I116_capitulo_renombrado.mkv conserva ese título exacto y los intervalos 0–9,9/9,9–12, confirmados con FFprobe. Un intento previo de escribir AXValue no activó el binding y dejó el borrador limpio; el guard de Generar impidió publicar ese intento y se repitió con teclado. Esta diferencia se registra como control, no como fallo de producto ni como prueba de Unicode.

- **I-117 — ✅, guardado individual, 03/10/2026:** El campo Tiempo acepta 7,250 s mediante teclado y confirmación. I117_capitulo_7250.mkv contiene el segundo capítulo en 7,250–12 s y recalcula el final del primero a 7,250 s, manteniendo ambos títulos. FFprobe confirma precisión de milisegundos. El original I116 conserva el marcador en 9,900 s.

- **I-119 — ✅, guardado individual, 03/10/2026:** Metadatos → Título global cambia QA Estructura a ZEUVE QA Metadata global. I119_metadata_global.mkv contiene exactamente ese title; ARTIST=QA Sintetico y QA_UNKNOWN=Etiqueta conservada permanecen, así como los dos capítulos 0–7,25/7,25–12. Confirmación independiente con FFprobe; no se editan tags desconocidos.

- **I-120 — ❌, guardado individual, 03/10/2026:** El título de vídeo stream 0 se introduce por teclado como Video principal metadata QA; el borrador pasa a cambios pendientes y el plan indica 1 campo modificado. Ejecutar muestra alerta: La validación final ha fallado: el título de una pista no coincide. I120_metadata_stream.mkv no se publica. Entrada I119 y sus tags originales siguen intactos. Fallo observado en metadata permitida de vídeo; no se extrapola a todos los campos o tipos de stream. Se investiga la probable divergencia entre metadata de vídeo y título de la pista del borrador, sin cambios de producto.

- **I-126 — ✅, guardado individual, 03/10/2026:** Añadir adjunto acepta adjunto_qa.txt como archivo regular, propone text/plain y el plan 1 añadido. I126_adjunto_anadido.mkv se publica correctamente: FFprobe confirma attachment stream 7, filename=adjunto_qa.txt, mimetype=text/plain y 49 bytes de extradata con el texto sintético exacto. La entrada I119 no tenía attachments y sigue intacta (SHA-256 f6b1081687c3db11c5cde96d72b01a46c727485735183862d3aa5f9e38b45ba2).

- **I-127 — ❌, guardado individual, 03/10/2026:** Nombre y MIME del attachment existente admiten adjunto_renombrado_QA.bin y application/octet-stream en el borrador. Al ejecutar aparece La validación final ha fallado: un adjunto original ha cambiado de códec; I127_adjunto_metadata.mkv no se publica. La entrada conserva filename=adjunto_qa.txt, MIME text/plain y SHA-256 66ebe77dd5ad08d8497b2662daffaf4cca150bcb4170d7ca87b14c8c08015f80. Coincide con INC-23: este attachment no tiene codec_name en FFprobe y el borrador utiliza un fallback distinto. Se considera fallida la edición completa de nombre/MIME en este caso, aunque los controles del borrador responden.

- **Contraste y continuidad, 03/10/2026:** 8 IDs cerrados en esta continuación: I-114–I-117, I-119 e I-126 OK; I-120 e I-127 fallidos. Los siete streams de la entrada I111 y la salida I126 conservan todas sus secuencias de hashes SHA-256 de paquetes: vídeo 100/100/120, audio 118/469 y subtítulos 2/2. El remux independiente INC24_remux_independiente.mkv aplica título antiguo y luego nuevo como el constructor de comandos; FFprobe devuelve el nuevo título con todos los paquetes intactos. La UI real no publica I120, y no se recuperó su temporal: la causa se infiere del código, donde updateVideoMetadata solo cambia metadata.videoValuesByStream, el constructor sobrescribe el título después de los títulos de tracks y validateTrackMetadata todavía exige track.title antiguo. INC-24, sin corregir. I127 amplía INC-23 a edición de nombre/MIME de un attachment existente; añadirlo como externo en I126 sí funciona. Se aceptaron las alertas y descartó el borrador I127: app abierta en I126, Resumen/solo lectura, sin motores ni reproducción. I-118 queda pendiente de comprobación visual; no se marca fallo de producto por falta de acceso al Canvas. Fuente remota inicial 3cc4e1b sin novedades; cambios exclusivamente documentales.

- **I-128 — ⚠️, guardado individual, 03/10/2026:** El MKV sintético contiene cover.jpg MJPEG 240×160 y FFprobe attached_pic=1. Resumen → Adjuntos e imágenes · 1 muestra Carátula · stream 2 · mjpeg, un AXImage y Extraer/Copiar. Reconocimiento técnico y presencia de la vista comprobados; no se certifican imagen visible, color, proporción o calidad del render porque CUA continúa devolviendo native pipe closed. Esa limitación es de control, no un fallo de ZEUVE.

- **I-129 — ✅, guardado individual, 03/10/2026:** Extraer carátula genera I129_caratula_extraida.jpg y la UI confirma la extracción sin modificar original. cmp verifica identidad byte a byte con I128_cover_A.jpg (SHA-256 c82623b375a3f32363d6c494e9fd96adfb102418d594dd76d9da82791b5fb9e0); imagen extraída se abre y conserva el patrón sintético 240×160. No se confunde esta inspección del archivo con la comprobación visual pendiente de la miniatura dentro de ZEUVE.

- **I-130 — ❌, guardado individual, 03/10/2026:** Añadir carátula acepta JPEG externo en I130_base.mp4; el borrador muestra MJPEG, imagen y título automático I128_cover_A. Plan MP4 permitido. Al ejecutar, alerta La validación final ha fallado: el título de una carátula no coincide. I130_caratula_anadida.mp4 no se publica. Fallo de la incorporación completa con el título que la propia app propone; fuente y JPEG originales protegidos. Se contrastará sin ese título para separar el problema de metadata del contenido de la imagen.

- **I-131 — ❌, guardado individual, 03/10/2026:** Sustituir reemplaza en el borrador la carátula JPEG por I131_cover_B.png, PNG 180×240, sin acumular una segunda imagen. Título automático I131_cover_B. Al publicar I131_caratula_sustituida.mp4 se repite La validación final ha fallado: el título de una carátula no coincide y la salida no se publica. La sustitución completa con defaults falla, aunque el borrador sustituye correctamente; probable misma incidencia de metadata que I-130.

- **I-132 — ❌, guardado individual, 03/10/2026:** Eliminar la carátula PNG del borrador muestra Sin carátula attached_pic. Al revisar, la app cambia de MP4 a MKV aunque el borrador ya no contiene esa imagen; anuncia stream copy. Ejecutar rechaza la salida con La validación final ha fallado: el idioma de una pista no coincide. No se publica I132_sin_caratula.mp4 ni otra variante I132. La eliminación completa falla para esta entrada; el original conserva la carátula PNG. Probables dos factores: compatibilidad consulta la imagen original eliminada y el cambio a MKV no conserva und como tag visible.

- **I-133 — ❌, guardado individual, 03/10/2026:** En I128_caratula_original.mkv se conserva la carátula existente y solo se cambia el título global a QA MKV conservar caratula. Plan MKV con un vídeo H264 y un audio AAC. Ejecutar falla: La validación final ha fallado: el número de pistas de vídeo no coincide con el plan; I133_MKV_conservar_caratula.mkv no se publica. Original conserva SHA-256 5f6f0f0a2a00c6807f29754e04b88e011d75f8d6a3343135d5f9cb9e3169fef8. Se contrastará el remapeo de la carátula MJPEG a MKV, sin arreglar producto.

- **I-134 — ⚠️, guardado individual, 03/10/2026:** MP4 publica JPEG y PNG cuando se vacía manualmente el título de carátula: I130_contraste_sin_titulo.mp4 tiene MJPEG attached_pic=1 con paquete SHA-256 idéntico al JPEG, e I131_contraste_sin_titulo.mp4 tiene PNG attached_pic=1 con SHA-256 idéntico al PNG. Defaults con título fallan (I-130/I-131). MOV se prueba aparte con H264/AAC compatibles y JPEG; falla con título automático y vacío: el número de carátulas no coincide con el plan; ninguna salida I134 se publica. Aceptación parcial: imágenes correctas en MP4 sin título, MOV no funciona en el caso probado. No se certifica miniatura UI visual.

- **I-140 — ✅, guardado individual, 03/10/2026:** Añadir fuente sintética rawvideo RGB24/NUT al MP4 crea un segundo vídeo RAWVIDEO. Revisar cambios rechaza la operación con La operación requeriría recodificar vídeo o audio (la pista de vídeo rawvideo no cabe por copia directa en MP4). Utiliza el Conversor universal. No se ofrece plan ejecutable ni panel de salida. Se prueba rechazo previo, no una ejecución recodificada oculta; originales intactos.

- **I-141 — ✅, guardado individual, 03/10/2026, evidencia final corregida:** Elegir como salida I130_contraste_sin_titulo.mp4 ya existente muestra confirmación nativa explícita con Cancelar/Reemplazar. Al intentar cancelar posteriormente, la hoja ya no existe: el control devuelve índice inválido y la app ya anuncia I130_contraste_sin_titulo 2.mp4. Se verifica esa publicación nueva con title=QA conflicto nombre, un H264/un AAC y sin carátula; payloads de ambos streams idénticos a I130_base.mp4. El archivo preexistente conserva SHA-256 589d30a676d622611e894fe5b13159828cb93540e0f220eea67ec0b20a88ed67 y su JPEG, y el original I130_base también conserva su hash. No hubo sobrescritura: el publicador resolvió el conflicto mediante sufijo 2. No se puede afirmar qué decisión cerró la confirmación ni que funcionó Cancelar; esa rama queda para revisión manual de control. Se corrige la anotación inicial de cancelación/no publicación, que no correspondía al estado final observado.

- **Contraste de carátulas y continuidad, 03/10/2026:** I-128–I-134, I-140 e I-141 se guardaron por separado: 3 OK, 4 fallos y 2 parciales. Contrastes posteriores al fallo: borrar el título automático permite publicar JPEG/PNG en MP4, con attached_pic=1 y paquetes de imagen iguales a sus archivos; vídeo H264 (50 paquetes) y audio AAC (236) conservan secuencias SHA-256. INC-25: título automático no representado por la ruta MP4 de carátulas; INC-26: carátula MKV remapeada como vídeo regular; INC-27: la ruta MOV probada omite la carátula; INC-28: compatibilidad revisa PNG original aunque se retire del borrador; INC-29: und desaparece como tag visible en MKV y el validador exige igualdad literal. Cuatro remux independientes reproducen las discrepancias observadas en app; no son los temporales rechazados por la app, que no se recuperaron. Archivo original MKV, base MP4/MOV e imágenes protegidos. Plan revisado no enumera explícitamente carátulas (amplía I-135 parcial sin cambiar su casilla). I-141 corregido al comprobar el estado final: archivo nuevo con sufijo 2 y preexistente intacto, no cancelación certificada. CUA sigue cerrando el pipe; visualización I-128 parcial, no fallo de producto. App PID 41759 en I130_contraste_sin_titulo 2.mp4, solo lectura, sin preview ni motores activos. Siguiente I-144/lotes. Sin correcciones de producto ni cambios de preferencias personales.

- **I-144 — ✅, guardado individual, 03/10/2026:** Selección múltiple real en NSOpenPanel: 01_audio.wav y 02_video.mp4, de la carpeta sintética Seleccion. Se abre Inspector multimedia · Lote con 2 archivos, ambos En espera, sin inspección/edición iniciada. El primer intento de Cmd+A no tenía foco en la lista; al enfocar mediante flecha abajo y seleccionar todo, ambos archivos aparecen correctamente. Diferencia de control, no fallo de selección de ZEUVE.

- **I-145 — ✅, guardado individual, 03/10/2026:** Añadir carpeta al lote selecciona Arbol sin iniciar trabajo pesado. La cola pasa de 2 a 5 archivos con raiz.wav, nivel1.mp4 y nivel2.wav añadidos, conservando los dos iniciales. UI informa Carpeta añadida: 3 archivos; 3 elementos omitidos por filtros o seguridad.

- **I-146 — ✅, guardado individual, 03/10/2026:** Con configuración QA vigente (subcarpetas incluidas), el selector añade nivel1.mp4 de Arbol/Sub y nivel2.wav de Arbol/Sub/Profundo además de raiz.wav. Los tres nombres están presentes y En espera en la cola; la estructura real de fixture confirma profundidades 0/1/2. Recorrido efectivo comprobado, no solo el toggle o lectura del enumerador.

- **I-150 — ✅, guardado individual, 03/10/2026:** El árbol incluye enlaces simbólicos a un archivo y una carpeta con destino único no seleccionado (no_debe_entrar.wav), además de un enlace a vídeo. Al enumerar solo entran los tres archivos regulares: no aparecen enlaces ni destinos exclusivos. UI pasa de 3 a 5 omitidos al añadir dos enlaces nuevos y conserva cola de 5 entradas. No se sigue el enlace de carpeta ni el de archivo.

- **I-151 — ✅, guardado individual, 03/10/2026:** Se vuelve a añadir el mismo árbol con sus tres archivos regulares ya en cola. Recuento permanece 5 y cada nombre 01_audio.wav, 02_video.mp4, nivel1.mp4, nivel2.wav y raiz.wav aparece una sola vez. La deduplicación se comprueba por ruta repetida, no se afirma deduplicación por contenido: archivos idénticos en rutas distintas permanecen como entradas distintas.

- **I-152 — ✅, guardado individual, 03/10/2026:** Lote nativo de inspección rápida sobre 5 fixtures (3 WAV mono y 2 MP4 H.264/AAC): las cinco filas pasan de En espera a Completado. Resumen: 5 correctos, 0 avisos/omitidos/fallidos/cancelados; WAV V0/A1/S0 y MP4 V1/A1/S0. Sin informes ni espectrogramas y sin salida configurada. No se modifican originales.

- **I-147 — ✅, guardado individual, 03/10/2026:** Prueba nativa con la misma carpeta y cola vaciada entre escenarios: Ajustes > Inspector > profundidad 0 añade solo raiz.wav (1); profundidad 1 añade raiz.wav+nivel1.mp4 (2); profundidad 2 añade también nivel2.wav (3). Se cambia con el control de profundidad real, subcarpetas activadas. La enumeración respeta cada límite sin arrastrar archivos de la cola anterior. Baseline 8 se restaurará al terminar ocultos/filtros.

- **I-148 — ✅, guardado individual, 03/10/2026:** Ajustes aislados: con ocultos desactivados entran 3 archivos visibles; al activarlos, vaciar cola y añadir la misma carpeta entran 4 incluyendo .oculto.wav. Se desactiva, vacía y añade de nuevo: vuelven solo nivel1.mp4, nivel2.wav y raiz.wav. Los tres symlinks siguen excluidos incluso con ocultos activados. Preferencia restaurada a false.

- **I-149 — ✅, guardado individual, 03/10/2026:** Se cambian filtros desde Ajustes nativos y se vacía cola entre casos: solo wav admite nivel2.wav+raiz.wav (2) y excluye nivel1.mp4; solo mp4 admite exclusivamente nivel1.mp4 (1). Oculto, txt y symlinks no entran. Se restauran las 20 extensiones iniciales, profundidad 8, subcarpetas true y ocultos false; lectura nativa confirma baseline.

- **I-153 — ✅, guardado individual, 03/10/2026:** Lote de señal nativo con 1 MP4 mono y 2 WAV mono, checkbox señal activado y otras dos operaciones desactivadas. Primera ejecución sin exportación y repetición con JSON: 3 correctos/0 fallos; los 3 informes contienen exactamente un resultado signal (duraciones 5.0133/10/10 s, cero silencios y cero clipping, coherente con tonos continuos). loudness vacío confirma que no se lanzó la otra operación.

- **I-156 — ✅, guardado individual, 03/10/2026:** El lote nativo anterior publica 3 informes JSON en la carpeta sintética Resultados, uno por archivo, con nombre/duración/streams y signal coincidentes; todos parsean como JSON válido. UI resumen 3 informes y 0 espectrogramas; no fallos ni sobreescritura de originales. TXT/Markdown individuales ya estaban verificados; esta prueba de lote ejercita JSON.

- **I-154 — ✅, guardado individual, 03/10/2026:** Lote nativo con sonoridad activada y señal/espectrograma desactivados: 3 correctos y 3 nuevos JSON, sin fallos ni avisos. Cada informe nuevo tiene un resultado loudness y signal vacío, con EBU R128 y mapa temporal; WAV idénticos: -20.2 LUFS, -18.1 dBTP, ~10 s. Los informes de señal anteriores se conservan y la app usa sufijo 2 ante conflicto.

- **I-155 — ✅, guardado individual, 03/10/2026:** Lote nativo: señal/sonoridad off, espectrograma on y JSON. Los 3 archivos terminan correctos; resumen 3 PNG+3 informes. Se abren los 3 PNG exportados y se verifica 1600×900: banda continua a ~660 Hz para MP4 y ~1320 Hz para ambos WAV, coherente con fixtures. No imágenes vacías, no fallos ni sobreescrituras de los JSON previos (sufijo 3).

- **I-157 — ✅, guardado individual, 03/10/2026:** Se añade no_multimedia.txt expresamente desde el selector y, detrás, 3 archivos válidos. Ejecutado lote nativo JSON: el primero falla con «FFprobe no ha podido analizar el archivo»; los tres siguientes se procesan y publican informes JSON válidos. Resumen 4 archivos, 3 correctos, 1 fallido, 0 cancelados; el error esperado queda aislado y no detiene el resto.

### Continuidad técnica — lotes, 03/10/2026

14 IDs nuevos OK: I-144–I-157. Carpetas, selección múltiple, profundidad 0/1/2, ocultos, filtros, symlinks y deduplicación comprobados por UI nativa; inspección, señal, sonoridad, PNG e informes comprobados con resultados publicados. El TXT incompatible esperado falla sin detener los tres archivos válidos, no es un nuevo defecto de producto. Estado 446 OK, 14 fallos, 10 parciales, 169 pendientes; Inspector 125/180 OK, 8 fallos, 5 parciales, 42 pendientes.

Fixtures y salidas: QA-20261003.oGJ5vx/Batch-I144, fuera del repositorio. Ajustes aislados restaurados: profundidad 8, subcarpetas activadas, ocultos desactivados y las 20 extensiones iniciales; orden A–Z y política de incompatibles sin cambiar. App QA PID 41759, pantalla de lote completado (4 archivos, 3 correctos, TXT fallido esperado), JSON seleccionado, tres operaciones desactivadas, carpeta Resultados; sin proceso pesado activo. Siguiente I-158: preparar un caso cancelable y verificar resultados ya publicados, después reglas I-159. Ningún arreglo ni cambio de código/configuración del proyecto.

Control separado: seleccionar Ajustes mediante AXPress en fila/texto no cambió de sección; navegación por teclado sí. La lectura completa de Ajustes fue lenta y se sustituyó por lectura del grupo pertinente. El selector de salida tiene un botón adicional «Nueva carpeta»: el ordinal antiguo pulsó Cancelar; se corrigió solo el auxiliar de QA para usar «Usar carpeta». Otro selector necesitó un segundo clic explícito para cerrar; no se atribuyen estos intentos de automatización a ZEUVE ni se marcaron pruebas por ellos. CUA visual sigue pendiente; se inspeccionaron los PNG exportados como archivos, no la ventana mediante captura.

- **I-158 — ✅, guardado individual, 04/10/2026:** Lote nativo de sonoridad+JSON: 01_corto.wav (10 s), 02_largo.flac (tono sintético 2 h), 03_pendiente.wav. Se observa primero Completado/informe publicado, segundo Analizando sonoridad EBU R128 y tercero En espera; se pulsa Cancelar lote. Resultado 1 correcto/2 cancelados/0 fallos/1 informe. Carpeta de salida contiene solo el JSON del primero, válido y con SHA-256 igual antes/después (add477…ce1c), sin resultados de los cancelados. No motores activos tras cancelar y hashes de los tres originales intactos.

- **I-159 — ✅, guardado individual, 04/10/2026:** Desde UI nativa se crea regla Audio / Idioma / Es igual a / spa → Cambiar idioma / fra y se guarda «QA I159 spa a fra». Aparece como conjunto seleccionable y SQLite aislado confirma un ruleSet schema1 con condición/action correctas, sin rutas multimedia. No se editan preferencias reales ni código.

- **I-161 — ⚠️, guardado individual, 04/10/2026:** Preflight real distingue 01_coincide.mp4 Aplicable y 02_no_coincide.mp4 Sin cambios; resumen 1 aplicable/1 sin cambios, sin escribir salidas. Aceptación parcial: solo enseña clasificación por archivo. No muestra el plan individual, pista afectada, idioma anterior/nuevo ni explicación de cambios/avisos; código de la vista confirma que solo renderiza nombre/clasificación/contador de avisos. No se considera limitación de control ni se corrige.

- **I-162 — ⚠️, guardado individual, 04/10/2026:** Antes de ejecutar se puede revisar la clasificación del preflight y no se publica automáticamente; el botón ejecutable depende de carpeta. Aceptación parcial: no hay vista/botón de detalle de cada plan para revisar las transformaciones exactas; el usuario ve Aplicable/Sin cambios y los controles generales de regla, no un antes/después individual. Se documenta esta cobertura limitada junto a I-161, sin cambiar producto.

- **I-160 — ✅, guardado individual, 04/10/2026:** Regla real spa→fra sobre dos MP4 H.264/AAC: preflight 1 aplicable/1 sin cambios, confirmación explícita Ejecutar y publicación solo de 01_coincide_editado.mp4. FFprobe confirma audio fra, vídeo und, mismos codecs/duración5 s. Hash de cada paquete coincide con original (50 vídeo/236 audio): stream copy sin recodificar. No se genera salida del archivo eng; ambos originales mantienen SHA-256.

- **I-165 — ✅, guardado individual, 04/10/2026:** Se añade un tercer MP4 spa, manteniendo el eng que no coincide. Preflight real: 2 aplicables/1 sin cambios; confirmación explícita Ejecutar. Se publican 01_coincide_editado 2.mp4 y 03_coincide_editado.mp4 en la ejecución secuencial, ambos audio fra/H264+AAC/5 s. Los paquetes de ambos streams coinciden con originales y se conserva la salida preexistente; ningún archivo eng publicado. No errores. La UI al finalizar no ofrece resumen persistente de esta ejecución estructural; resultado verificado en las salidas, no extrapolado al estado En espera de la cola de análisis.

- **I-163 — ✅, guardado individual, 04/10/2026:** Con lote de sonoridad activo en 02_largo.flac (UI 4/4, 86 %) se pulsa Generar preflight. ZEUVE muestra «Ya hay una operación en curso: Analizando sonoridad.» y no prepara planes. Se cancela después el lote para liberar coordinación. Se verifica rechazo real desde UI mientras una operación pesada del mismo módulo estaba activa, no solo código ni un busy simulado.

- **I-164 — ❌, guardado individual, 04/10/2026:** Aceptación fallida en la interfaz: al preparar preflight nativo de 200 MP4 sintéticos no hay acción «Cancelar preflight». Se completa con 200 aplicables. Se inspecciona UI y vista real: mientras isPreflighting solo cambia Generar preflight a Preparando…/spinner; el encabezado decide Cancelar lote únicamente por isRunning. Cerrar lote no llama cancelStructural ni cancela structuralTask; la tarjeta global tampoco ofrece cancelar. No se pudo solicitar cancelación de preflight desde el flujo previsto. No se atribuye fallo al algoritmo interno (las pruebas históricas de servicio sí contemplan cancelación); es una ruta de cancelación no expuesta por la UI. Sin arreglar.

- **I-166 — ✅, guardado individual, 04/10/2026:** Se crea «QA I166 informe» desde Ajustes > Inspector, se edita a JSON sin señal/sonoridad/espectrograma y guarda. Se cambia a Inspección rápida y se vuelve a seleccionar el personalizado en Lote: restaura los tres toggles off y JSON. Ejecución real sobre MP4 termina 1 correcto/1 informe; JSON válido y signal/loudness vacíos. SettingsRepository aislado conserva el preset schema1/configuración correcta, sin rutas.

- **I-168 — ✅, guardado individual, 04/10/2026:** Se marca el preset personalizado como favorito desde su estrella: ayuda cambia a Quitar preset de favoritos y SettingsRepository registra batchPreset con ID/nombre, sin rutas. Se desmarca: ayuda vuelve a Añadir preset a favoritos y el registro desaparece mientras el favorito de reglas permanece. El preset conserva configuración y ejecución comprobada en I-166. Alta/baja real sin afectar archivos ni otros favoritos.

- **I-169 — ✅, guardado individual, 04/10/2026:** Se marca conjunto QA I159 spa a fra como favorito: selector muestra ★ y store aislado registra kind structuralRuleSet, referencia al conjunto y nombre, sin archivos/rutas. Se desmarca: desaparece ★ y store queda con items vacío. No se borra ni modifica la regla persistida spa→fra; ejecución semántica comprobada en I-160/I-165. Ambos favoritos de prueba vuelven al estado inicial vacío.

- **I-167 — ✅, guardado individual, 04/10/2026:** En Ajustes aislados se pulsa Restaurar presets de lote predeterminados y se revisa confirmación explícita «Se sustituirán los presets actuales por los incluidos con ZEUVE». Al aceptar vuelven exactamente los 4 defaults/configuraciones (rápida, MD, audio completo JSON y PNG), desaparece solo el personalizado QA; batch vuelve a Inspección rápida. Favoritos de prueba ya vacíos, regla guardada se conserva y archivos/resultados mantienen hashes. Restauración específica con advertencia correcta, no reset global S-16.

### Continuidad técnica — reglas, cancelación y presets, 04/10/2026

12 IDs nuevos cerrados individualmente: I-158–I-169, 9 OK, 1 fallo y 2 parciales. Estado 455 OK, 15 fallos, 12 parciales, 157 pendientes; Inspector 134/180 OK, 9 fallos, 7 parciales, 30 pendientes. I-164 falla por ausencia de ruta de cancelación de preflight en la UI; I-161/I-162 solo clasifican archivos, sin detalle de plan individual. No se confunde lo anterior con fallo del servicio interno de cancelación. INC-30/INC-31 ampliadas en el informe de incidencias fuera del proyecto; ningún arreglo.

I-162: evidencia adicional posterior, sin convertirla en OK completo. Ejecutar planes aplicables abre confirmación nativa explícita con Cancelar/Ejecutar y explica archivos nuevos/originales intactos/validación FFprobe. Se confirma la barrera previa a escritura, pero la confirmación tampoco muestra el antes/después individual. I-165 publica ambos planes; al acabar desaparecen los contadores de edición y la cola de análisis permanece En espera. Se registra esta limitación comunicativa sin falsear el resultado verificado en salidas.

Datos persistentes de pruebas: Batch-I158 (FLAC sintético 2 h/193 MB, WAV cortos e informe conservado tras cancelar), Batch-I159 (MP4 spa/eng/spa y 3 salidas estructurales verificadas por paquetes), Batch-I164 (200 MP4 sintéticos, solo preflight; ninguna ejecución masiva). Todo fuera del repositorio, sin datos reales. El reset específico de presets tiene advertencia correcta y no reproduce el reset global S-16. Se restauran 4 defaults, se desmarcan los dos favoritos QA y se retira únicamente el conjunto QA I159 creado en esta sesión; reglas/favoritos vuelven vacíos. La regla retirada es recuperable a partir de su condición/acción documentadas y de las salidas, y no se borran fixtures ni resultados.

App QA PID 41759 en pantalla inicial del Inspector, sin análisis/preview/motores activos; Ajustes cerrados y opciones de carpetas sin cambios respecto al baseline restaurado. Siguiente I-175: medir memoria con archivo largo, después I-176–I-180. Se conservan pendientes anteriores y no se certifica Release completa. Control separado: se esperó actualización real tras cambiar menús dinámicos; algunos intentos de acceso demasiado pronto o de navegación del selector no concluyeron y no sirvieron como evidencia de producto.

- **I-52 — ✅, guardado individual, 04/10/2026:** Revisión visual nativa del FLAC de 2 h: waveform completa visible, buckets de amplitud constante coherentes con tono de 880 Hz y playhead superpuesto. Captura QA I175-preview.png. Ya no se depende exclusivamente del AXUnknown.

- **I-175 — ✅, guardado individual, 04/10/2026:** FLAC sintético de 7200 s, 202,8 MB, mono48k: inspección, análisis completo de señal/sonoridad y reproducción nativa con waveform completados. RSS basal247792–248032KB; monitor de apertura max307568KB/15312KB hijos; segundo monitor108s max315440KB app y29344KB hijos, final315280/14176KB. Lectura posterior295936/14256KB. Sin crecimiento proporcional a PCM completo de2h, congelación ni error. Medición RSS, no heap/VRAM ni garantía universal.

- **I-176 — ✅, guardado individual, 04/10/2026:** Muestra local HEVC3840×2160,12fps,8s: inspección correcta, Ver prepara preview y Play reproduce hasta00:08/00:08 con frame testsrc2 visible. RSS puntual760512KB app+552096KB FFmpeg durante preparación y1116720KB app sin hijos al finalizar. Sin cierre/error; alcance es esta muestra4K corta, no benchmark de4K60/largometraje. Capturas I176-play/final.

- **I-177 — ✅, guardado individual, 04/10/2026:** HEVC hvc1/yuv420p en MP4 validado por ffprobe instalado y por UI3840×2160/12FPS. Inspección, análisisAAC, Play y frame final correctos en ZEUVE. No se confunde Ver (selección/preparación) con Play.

- **I-178 — ✅, guardado individual, 04/10/2026:** DecoderAV1 presente en FFmpeg empaquetado; noencoderAV1, por lo que fixture sintético640×360/12fps/8s creado con SVTAV1 del FFmpeg Homebrew ya instalado (sin instalación/modificación de motores ZEUVE). UI identificaAV1; Play reproduce frame y reloj00:05/00:08 con waveform/playhead coherentes. CapturaI178-resultado.

- **I-179 — ✅, guardado individual, 04/10/2026:** Fixture H26420s realmenteVFR: timestamps ffprobe0–10s cada0.1s y10–20s cada0.066667s. UI indicaFPSmedio12.521,duración20s; reproducción muestra reloj09s,framecontemporáneo~09s/playhead~45%,yfinal20s conframe19.933s. Timeline temporal coherente conPTS/noestiramiento. ClickSystemEvents sobrecanvas noefectivo no se usa como prueba de seek.

- **I-180 — ✅, guardado individual, 04/10/2026:** MuestraHEVC Main10/PQ/BT.2020 comprobada por ffprobe; Resumen nativo identificaHDR(PQ·BT.2020) y preview muestra frames a00:05/00:08. Noerror/crash. Solo compatibilidad/preview, sin certificar luminancia/tone mapping ni monitorHDRdereferencia. PrimerafixtureVideoToolbox perdiótransfer/primarias y se descartó como evidenciaHDR; fixtureválida hechaconx265ya instalado fueraapp.

- **I-34 — ✅, guardado individual, 04/10/2026:** Reproducción nativaMKV40s H264testsrc2+AAC: frames dinámicos visibles desde preparación hasta~15s,Play/Pausa responden; evidenciaI34-frameA eI36-pausaA. También contrasteAV1/HEVC. No es solo cambio de reloj sin imagen.

- **I-36 — ✅, guardado individual, 04/10/2026:** Pausa alrededor15s conserva el último frame tras breve asentamiento de cola: capturasI36-pausaB/C mantienen exactamente patrón ytimecode14.750,pese alecturasposteriores. El reloj permanece00:15/00:40,no se borra la imagen ni vuelve0. Captura inmediatamente traspausarA tenía14.583 antesdeasentarse2frames.

- **I-22 — ✅, guardado individual, 04/10/2026:** Arrastre real de puntero sobrecanvas waveform mediantehelperQA invocadodesdeAppleScript,75%→25% delancho: playhead/reloj cambian15→10s,posición~25%. ClickAXSystemEvents anterior noactivabaDragGesture y noera evidenciadefallo. CapturaI38-seek10; efecto de seek sobreframe evaluado porseparadoI38.

- **I-53 — ✅, guardado individual, 04/10/2026:** Scrub realwaveformMKV40s mueveplayheada10s/25%,relojcoincidente. No se certifica porAXsetValue: fuegesture down/drag/up yverificaciónvisual.

- **I-38 — ❌, guardado individual, 04/10/2026:** Fallo reproducido enpausa: scrubrealde~15s→10s cambia reloj/playhead,pero framepermanece contimecode14.750durantecapturasI38-seek10 eI38-espera separadas. Al Play imagen vuelveaavanzar desdeel destino. Seektemporal funciona, pero actualizaciónvisualpausada no. NoatribuidoclickAX: gesto realverificado.

- **I-37 — ✅, guardado individual, 04/10/2026:** Play despuésdelseekpausadoa10s reanuda desdeeldestino,sinvolver0: después~6s reloj16s/frame15.333yplayhead~40%. CapturaI37-reanudar. DiferentedeI38: reanudarcorrecto,framepausadoseekestancado.

- **I-39 — ❌, guardado individual, 04/10/2026:** Durante vídeoMKV2AAC, B→A conB reproduciendoa25s: tras4s conserva reloj29s yselecciónTono440,pero aparecealerta«Este ejecutor ya tiene un proceso activo» yelframequeda~24.917s mientrasrelojavanza30s. CapturasI39-estable/vueltaA/modalActual. Posición se conserva, flujo de cambio no es sano. Primerintento durantecarga separado delcontrasteestable; noseatribuyefallo porintentoAXincorrectodescartaralerta.

- **I-40 — ✅, guardado individual, 04/10/2026:** VídeoPatron16x9→Morado9x16 en pausa30s conserva reloj/playhead30s; Playreanuda desde30 hasta36conimagenrealdeotrostream(moradovertical),sinreinicio0. CapturasI40-morado/moradoPlay. La imagen seactualizaalreproducir; limitaciónpausedframeyacapturadaI38.

- **I-45 — ✅, guardado individual, 04/10/2026:** ComparaciónvisualdosstreamsconSAR1: original640×360seve~289×162(16:9); segundo360×640semuestra~90×162(9:16),centradoconbandaslaterales,sindeformación. CapturasI34-frameA/I40-moradoPlay.

- **I-44 — ✅, guardado individual, 04/10/2026:** Previewvertical conservaaspectfit centrado enventana yfullscreen: regiónnormal~90×162; fullscreen~117×208mismo9:16,bandasnegras ysinrecorte/estiramiento. CapturaI44-fullscreen. Escalado mayor al ampliarapp,ycontenido permaneceentero. Pruebadentrodeapp,noexportadovideo.

- **I-41 — ✅, guardado individual, 04/10/2026:** BorradornativoañadeexternoI41_externo_verde.mkv(H264stream0verde) aloriginalI34_multistream40.mkv(H264stream0testsrc2). SelectorVídeo·H264reproduceverde; volverPatron16x9reproducepatrónoriginal. Ambosstreamíndice0dearchivosdistintos,nocruzafuentes. CapturasI41-externoVerde/original0. Borradornopublicado.

- **I-57 — ✅, guardado individual, 04/10/2026:** WaveformnativaMKV40sconcapítulosInicioQA0s/SegundoQA5s: marcadorespunteadosvisiblesal0% y12.5%,coherentesconffmetadata yduración40s. CapturasI34-frameA/I36-pausaC.No sesustituye porfilasAX; secomprobócanvasreal.

- **I-118 — ✅, guardado individual, 04/10/2026:** Borradordecapítulosnativo: SegundoQA cambia5→20s conentrada real de teclado; field muestra20.000 ymarcadortimelinepasa12.5%→50% antesdeRevisar/Generar. CapturaI118-capitulo20. No archivoresultantepublicado; ffprobeoriginalseguirácapítulo5s trasdescartarborrador.

- **I-58 — ✅, guardado individual, 04/10/2026:** QA nativa 04/10: I58_silencio_clipping.wav (12 s, PCM16, silencio 2–4 s y saturación 6–7 s). Overlays activados visibles en la forma de onda: franja gris con tooltip 00:02.000–00:04.000 y marcador naranja cerca de 6,5 s. Captura I58-overlays.png; también comprobados visualmente en Espectrograma. Sin cambios de preferencias.

- **I-74 — ✅, guardado individual, 04/10/2026:** QA nativa 04/10: la línea temporal coloca el silencio 2–4 s y el clipping 6–7 s donde fueron generados en I58_silencio_clipping.wav. Forma de onda, bandas del espectrograma y marcador naranja coinciden sobre el mismo eje de 12 s; tooltip de silencio precisa 2.000–4.000 s.

- **I-71 — ✅, guardado individual, 04/10/2026:** QA nativa 04/10: Espectrograma muestra el gráfico «Sonoridad temporal · Short-term LUFS» con curva y eje temporal 0–12 s. Tras la ventana inicial de 3 s, presenta descenso/recuperación alrededor del silencio y aumento alrededor de la señal saturada 6–7 s; no es solo la cifra LUFS integrada. Interpretado como short-term con ventana, no como amplitud instantánea.

- **I-62 — ✅, guardado individual, 04/10/2026:** QA nativa 04/10 mediante CUA: clic en el centro del espectrograma de 12 s lleva el transporte a 00:06 y arrastre desde la coordenada 9 s hasta 3 s lo lleva a 00:03. La app inicia/reanuda escucha al hacer seek; se pausa posteriormente con su control propio. El gesto real funciona, a diferencia del AXPress sin arrastre de intentos antiguos.

- **I-61 — ✅, guardado individual, 04/10/2026:** QA visual nativa 04/10: durante reproducción y en pausa a ~9/12 s, líneas blancas de espectrograma, gráfico LUFS y waveform señalan la misma fracción temporal (~75 %) aunque sus márgenes/ancho difieren; reloj 00:09/00:12 coherente. No se confunde cursor punteado de hover (9.000 s) con playhead continuo.

- **I-29 — ⚠️, guardado individual, 04/10/2026:** QA nativa 04/10: clic real en slider cambia 1→0 (icono Silencio)→0.438889→0.994444 y acción Increment restituye exactamente 1. El control responde y el estado mute es coherente. No existe escucha ni captura loopback de la salida en esta sesión: no certifico ganancia/mute acústicos. Revisión humana breve: reproducir un tono y comparar 0/medio/1.

- **I-89 — ✅, guardado individual, 04/10/2026:** QA nativa 04/10: nuevo PCM16/48 kHz de 12 s, tonos 440 Hz 0–4, 4000 Hz 4–8 y 880 Hz 8–12. Análisis avanzado devuelve 2 anomalías; screenshot I89-timeline.png muestra bandas violetas en ~4 y ~8 s, coincidentes con los cambios de la señal. Se acepta posición temporal del overlay, no clasificación como origen con pérdida (correctamente Evidencia insuficiente) ni exactitud del eje Y ya registrada aparte.

- **I-02 — ✅, guardado individual, 04/10/2026:** QA nativa 04/10: arrastre real desde una fila de Finder (carpeta aislada con un único I02-arrastrar.wav) a la zona visible del Inspector. La app abre exactamente ese WAV, identifica duración 12 s y permanece en modo inspección/solo lectura. SHA de copia y fixture idéntico db7aeed036929e92d938c29731d1f825aaa3d3dc5e88235e65ef57f8b14726c9. Primer arrastre tomó una captura PNG por desplazamiento de filas; es error de coordenadas del controlador, no de ZEUVE; también fue aceptada como archivo.

- **I-33 — ❌, guardado individual, 04/10/2026:** QA 04/10: no se acepta el criterio global de respuesta habitual. Play/Pausa de audio y seek de espectrograma responden, pero el seek de vídeo pausado deja indefinidamente la imagen anterior (I-38: playhead 10 s, frame 14.750 s aún en captura posterior), y cambiar audio durante vídeo produce alerta y frame congelado (I-39: reloj 29–30 s, frame ~24.917 s). No es una medición exacta de latencia de entrada de 1 s; son bloqueos visuales confirmados en acciones habituales, no los retardos de lectura AX del controlador.

- **I-35 — ⚠️, guardado individual, 04/10/2026:** QA 04/10: fixtures H.264/HEVC/AV1/VFR con audio permiten contrastar reloj, frames con timecode y waveform en reproducción normal; I-34/I-179 confirman coherencia temporal visual dentro de resolución de FPS y redondeo del reloj. En cambio I-39 demuestra pérdida de actualización del vídeo tras cambio de audio. No escucho la salida real ni dispongo de loopback: sincronía acústica/lip-sync no certificada. Revisión humana breve: vídeo de pulsos/beeps o habla, inicial y tras seek/cambio de pista. Conservado parcial, no aprobación por inferencia del código.

- **I-128 — ✅, guardado individual, 04/10/2026:** Revisión visual adicional 04/10, sustituye el parcial de control del 03/10: se reabre I128_caratula_original.mkv, despliega Adjuntos e imágenes y desplaza hasta mostrar la miniatura completa. Captura I128-miniatura-completa.png: patrón de barras/color/círculo y proporción 3:2 coinciden con I128_cover_A.jpg (240×160), sin recorte propio de la miniatura; la primera vista cortada era el borde del scroll. Identificación Carátula · stream 2 · mjpeg coherente. Ahora OK por render realmente observado, no por AXImage.

- **Cierre del Inspector, 04/10/2026:** 30 IDs pendientes abordados y I-128 revalidado visualmente: 26 OK adicionales, 3 casillas fallidas (I-33/I-38/I-39; dos incidencias de vídeo distintas) y 2 parciales acústicos. Total Inspector 160/180 OK, 12 fallidas y 8 parciales; 0 pendientes. El resto de módulos no cambia. Original multistream conserva SHA 320e47cd…501ca y capítulos 0/5 s tras descartar borradores de vídeo externo y capítulo 20 s; no se publican ediciones de esos borradores. Preview detenido, volumen restituido exactamente a 1, ventana devuelta a tamaño/posición iniciales y sin motores hijos activos. No se cambia código, configuración de producto, versión, motores ni empaquetado. Casos 4K/HEVC/AV1/VFR/HDR están acotados a fixtures sintéticos; HDR es compatibilidad, no calibración de color. Todos los resultados se guardaron individualmente.

- **L-01 — ✅, guardado individual, 04/10/2026:** En la app QA nativa, pulsar Analizar cambia inmediatamente la acción a Cancelar y aparece indicador de actividad. No se ha ejecutado limpieza ni retirada; se analiza el inventario local permitido por el módulo.

- **L-02 — ✅, guardado individual, 04/10/2026:** Mientras se analiza aparece indicador de uso y botón Cancelar, diferenciando el estado de trabajo del inicial Analizar. Se comprobará por separado que termine y la información final; no se infiere un porcentaje a partir del spinner.

- **L-08 — ✅, guardado individual, 04/10/2026:** Primer análisis nativo completado: Resumen muestra Cobertura «Completa». Se acepta presencia/estado mostrado, no se extrapola a cobertura de archivos protegidos que no se hayan enumerado.

- **L-09 — ✅, guardado individual, 04/10/2026:** Resumen nativo muestra 568 aplicaciones detectadas tras el análisis. El inventario de aplicaciones se contrastará en su pestaña; no se borró ninguna app.

- **L-10 — ✅, guardado individual, 04/10/2026:** Resumen nativo muestra 442 candidatos y un bloque de elementos grandes; se distinguen las cifras de apps y de candidatos.

- **L-11 — ✅, guardado individual, 04/10/2026:** Resumen muestra «Analizado 51,04 GB», además de tamaños por candidato. Se valida que la métrica exista y no esté vacía; no equivale al espacio recuperable.

- **L-12 — ✅, guardado individual, 04/10/2026:** Resumen muestra «Selección segura potencial 1,18 GB» y explica que son elementos regenerables que cumplen guardas y no implica eliminación. Es distinto de 51,04 GB analizados; no se ejecutó esa selección sobre datos reales.

- **L-05 — ✅, guardado individual, 04/10/2026:** Segundo análisis nativo iniciado con indicador de actividad. Se pulsa Cancelar aproximadamente 10 s después; desaparece el spinner y aparece «Análisis cancelado.» en la siguiente lectura (<1 s de comando/lectura). No se solicitó ni ejecutó retirada.

- **L-06 — ✅, guardado individual, 04/10/2026:** Tras Cancelar la UI vuelve a sin indicador de actividad, conserva las cinco pestañas y el resumen anterior, muestra «Análisis cancelado.» y recupera la acción inicial. Se comprobará reanálisis por separado.

- **L-07 — ✅, guardado individual, 04/10/2026:** Después del estado «Análisis cancelado.» se pulsa de nuevo Analizar: reaparece indicador de actividad, se retira el mensaje de cancelación y comienza otro análisis. No es solo botón habilitado: nuevo trabajo nativo observado.

- **L-03 — ✅, guardado individual, 04/10/2026:** Reanálisis iniciado a 09:21:49 UTC y comprobado terminado a 09:22:14 UTC: límite superior observado 25 s (no cronometraje del instante exacto de fin). Sin spinner, resumen disponible tras cancelación previa. Tiempo razonable para esta sesión/volumen; no garantía para cualquier disco.

- **L-04 — ✅, guardado individual, 04/10/2026:** Dos análisis reales han terminado y uno intermedio se canceló. El último vuelve a resumen en ≤25 s, sin quedar atrapado indefinidamente en inventario. No se da por probada una fase solo por leer el código de Spotlight.

- **L-14 — ✅, guardado individual, 04/10/2026:** Inventario nativo, filtrado por «Visual Studio Code»: muestra Code, ruta /Applications/Visual Studio Code.app, versión 1.140.0 y estado Instalada. La ruta existe en filesystem. Detección real de /Applications, no solo fuente configurada.

- **L-17 — ✅, guardado individual, 04/10/2026:** Fila de inventario muestra nombre Code y ruta /Applications/Visual Studio Code.app con versión y estado, coherentes con el bundle instalado. El buscador puede encontrar por ruta aunque el nombre visible difiera del nombre de carpeta.

- **L-16 — ✅, guardado individual, 04/10/2026:** Búsqueda real: «Visual Studio Code» devuelve solo la fila Code por coincidencia de ruta; consulta sintética inexistente deja lista sin filas; volver a la consulta inicial recupera la fila. No se abre ni desinstala Code.

- **L-15 — ✅, guardado individual, 04/10/2026:** Tras colocar una .app sintética propia en ~/Applications y volver a analizar, Aplicaciones muestra «ZEUVE QA Limpiador», versión 1.0, 540 bytes y ruta exacta /Users/javiercv/Applications/ZEUVE QA Limpiador Sil382.app. No se ejecutó ni eliminó la app; se retira después de esta comprobación.

- **L-66 — ✅, guardado individual, 04/10/2026:** Se abre el área Espacio del Limpiador. Antes de analizar muestra «Explorador de espacio», permite elegir carpeta, umbral mínimo en MB y Analizar espacio; explica que no se siguen enlaces simbólicos.

- **L-67 — ✅, guardado individual, 04/10/2026:** Elegida la carpeta sintética Espacio, el árbol nativo calcula 201,3 MB totales; grande.bin muestra 134,2 MB y Subcarpeta 67,1 MB. Contraste directo con tamaños lógicos 134217728 y 67108864 bytes de fixtures propios; los archivos son dispersos y no se confunde esta medición con espacio físico recuperable.

- **L-68 — ✅, guardado individual, 04/10/2026:** El despliegue nativo de Espacio y Subcarpeta permite navegar la jerarquía: grande.bin, carpeta hija y enlace; al abrir Subcarpeta aparecen mediano.bin (67,1 MB) y pequeno.txt (70 bytes). No hay mezcla de los hijos con el nivel superior.

- **L-69 — ✅, guardado individual, 04/10/2026:** no-seguir-enlace aparece como archivo de 134 bytes, sin hijos. Apunta a un fixture propio externo de 256 MiB, pero Espacio suma 201,3 MB, no los ~469,8 MB que resultaría de seguirlo. El destino permanece intacto y fuera del árbol.

- **L-70 — ✅, guardado individual, 04/10/2026:** Tras subir Mín. de 0 a 100 MB y pulsar Analizar espacio, el árbol conserva Espacio (201,3 MB) y grande.bin (134,2 MB) y oculta Subcarpeta (67,1 MB), sus hijos pequeños y el enlace (134 bytes). El filtro se aplica al volver a analizar, no inmediatamente al cambiar el umbral.

- **L-71 — ✅, guardado individual, 04/10/2026:** Con Mín. 200 MB y nuevo análisis, aparece «Sin resultados de espacio» y «Ningún elemento de esta carpeta supera el tamaño mínimo elegido. Reduce el mínimo y vuelve a analizar.», distinto del mensaje inicial «Explorador de espacio» antes de analizar. El directorio conserva los fixtures, no está realmente vacío.

- **L-18 — ✅, guardado individual, 04/10/2026:** Arrastre real desde Finder de la .app sintética propia a ZEUVE: aparece el banner «Desinstalación: ZEUVE QA Limpiador», 1 elemento revisable y botón Revisar plan en Limpieza. No se abre la aplicación ni se ejecuta retirada. El inventario anterior aún enseña su antigua ruta de ~/Applications; se contrasta la ruta efectiva en el plan, no se asume actualización automática.

- **L-35 — ✅, guardado individual, 04/10/2026:** En Limpieza, la casilla de la .app sintética propia se desmarca (0 seleccionados, 0 KB) y se vuelve a marcar (1 seleccionado, 540 bytes). La ruta del plan es la ubicación QA actual, no la entrada histórica de ~/Applications. No se ejecuta retirada.

- **L-36 — ✅, guardado individual, 04/10/2026:** Con la .app sintética marcada, pulsar Seleccionar elementos seguros mantiene su casilla en 1 y el total en 1 seleccionado / 540 bytes. El único candidato de este plan es la app, riesgo medio; no se interpreta como limpieza regenerable ni se borra.

- **L-40 — ✅, guardado individual, 04/10/2026:** Pulsar Mover a Papelera… abre una hoja de revisión previa «¿Mover los elementos seleccionados a Papelera?», con cancelar y confirmar separados. El fixture sigue existiendo con SHA-256 c3cc867a…347c7; no se confirma la retirada en esta prueba.

- **L-41 — ✅, guardado individual, 04/10/2026:** La hoja de revisión previa muestra «1 elementos», consistente con la única .app sintética seleccionada. No se pulsa confirmar.

- **L-42 — ✅, guardado individual, 04/10/2026:** La hoja de revisión muestra «540 bytes de tamaño conocido» y la fila «Aplicación · 540 bytes · Riesgo medio», consistente con el fixture propio y el total del plan.

- **L-43 — ✅, guardado individual, 04/10/2026:** La confirmación lista la ruta completa del único objetivo, QA-L.Sil382/Apps/ZEUVE QA Limpiador.app, sin sustituirla por la ruta antigua del inventario. Ninguna ruta de usuario real está seleccionada.

- **L-44 — ✅, guardado individual, 04/10/2026:** La confirmación identifica explícitamente «Mover … a Papelera», explica la posibilidad de deshacer movimientos completados y que se revalidará cada elemento y se omitirán cambios. No se confunde con borrado permanente.

- **L-19 — intento incompleto, sin cambiar casilla, 04/10/2026:** Después de cancelar la revisión de Papelera se colocó temporalmente el bundle propio de nuevo en su ruta de inventario de ~/Applications y se envió Analizar desinstalación. No se obtuvo una lectura final: macOS bloqueó la sesión (CGSSessionScreenIsLocked=true), System Events dejó de exponer ventanas y screencapture no pudo capturar. El proceso QA 41759 seguía vivo; no se afirma un fallo de ZEUVE ni se da el ID por terminado. La app sintética se devolvió a QA-L.Sil382/Apps/ZEUVE QA Limpiador.app, hash c3cc867aad12cd57d0b8ef7c59265c7e67ec368611cbe00f6df80c948ba347c7 intacto, sin copia restante en ~/Applications. Antes de reanudar, asegurar que la ruta del candidato coincida con su ubicación actual. No se ejecutó limpieza ni borrado.

- **L-19 — ✅, guardado individual, 04/10/2026:** Repetido el botón nativo Analizar desinstalación con el bundle propio presente en la ruta inventariada de ~/Applications. Se abre plan de 1 candidato (la app), casilla seleccionada y 540 bytes; app e Info.plist siguen existiendo con SHA-256 c3cc867a…347c7 intacto. No se ejecuta retirada. Las lecturas AX inmediatas fueron transitoriamente inaccesibles; lectura posterior y hash confirman el desenlace, sin atribuir ese control al producto.

- **L-20/L-21 — preparados, todavía pendientes, 04/10/2026:** Se crearon seis fixtures propios del Bundle ID com.zeuve.qa.cleaner.sil382 en Caches, Logs, Preferences, Application Support, Containers y Group Containers; no se analizaron ni retiraron desde ZEUVE. macOS volvió a bloquearse (CGSSessionScreenIsLocked=Yes, PID QA 41759 vivo) antes de abrir el nuevo análisis. No se cambian casillas. Cinco raíces se trasladaron recuperablemente a QA-L.Sil382/Asociados-preparados, con subcarpetas por categoría, y la .app se devolvió a QA-L.Sil382/Apps/ZEUVE QA Limpiador.app; Info.plist mantiene SHA c3cc867a…347c7. La raíz sintética de Containers no pudo renombrarse: macOS devuelve Operation not permitted. Su archivo propio ZEUVE-QA-Sil382.txt sí se movió a la carpeta QA; en la raíz solo queda la metadata .com.apple.containermanagerd.metadata.plist creada automáticamente por macOS. Se preserva y no se elude esa protección; comprobar el contenido antes de continuar. No queda la app temporal en ~/Applications. Las otras cinco raíces no quedan en ~/Library. Reanudar tras desbloquear, reponer únicamente los fixtures propios en las ubicaciones documentadas y verificar su plan; no usar el candidato de la ruta antigua si falta la app. No se ejecutó retirada.

- **L-20 — ✅, guardado individual, 04/10/2026:** Analizar desinstalación de la app sintética genera 7 elementos: la .app y seis asociados propios (Caches, Logs, Preferences, Application Support, Containers, Group Containers). Cada fila muestra ruta exacta, categoría y motivo «Coincide con el Bundle ID observado de la aplicación». No se asocia por un simple prefijo; alcance acotado a coincidencia exacta de este fixture.

- **L-21 — ✅, guardado individual, 04/10/2026:** En el plan nativo, los cuatro asociados persistentes propios aparecen con casilla 0, Riesgo alto y aviso «Puede contener preferencias o datos persistentes. No se selecciona automáticamente.»; solo .app, caché y log están seleccionados (3 / 790 bytes). No se ejecuta retirada.

- **L-26 — ✅, guardado individual, 04/10/2026:** La caché propia ~/Library/Caches/com.zeuve.qa.cleaner.sil382 está preseleccionada, 125 bytes, Riesgo bajo, asociación exacta por Bundle ID y consecuencia regenerable. Es un fixture elegible, no una autorización para retirar cachés reales.

- **L-27 — ✅, guardado individual, 04/10/2026:** El log propio ~/Library/Logs/com.zeuve.qa.cleaner.sil382 está preseleccionado, 125 bytes, Riesgo bajo y motivo de Bundle ID exacto. No se acepta por extrapolación a todos los logs; no se retira.

- **L-28 — ✅, guardado individual, 04/10/2026:** Preferences/com.zeuve.qa.cleaner.sil382.plist aparece como Preferencias, 260 bytes, Riesgo alto y casilla 0 aunque la asociación sea exacta. Aviso de datos persistentes presente.

- **L-29 — ✅, guardado individual, 04/10/2026:** Application Support/com.zeuve.qa.cleaner.sil382 aparece con casilla 0, Riesgo alto y aviso de datos persistentes, aunque coincide exactamente con Bundle ID. Fixture de 125 bytes.

- **L-30 — ✅, guardado individual, 04/10/2026:** Containers/com.zeuve.qa.cleaner.sil382 aparece como Container, 595 bytes (fixture de 125 + metadata propia de macOS de 470), Riesgo alto y casilla 0. No se prueba aquí la retirada del contenedor ni se elude su protección.

- **L-31 — ✅, guardado individual, 04/10/2026:** Group Containers/com.zeuve.qa.cleaner.sil382 aparece con casilla 0, Riesgo alto y aviso persistente. La asociación observada es por Bundle ID exacto de fixture sintético; no se afirma validación de entitlement App Group real ni de compartición entre apps.

- **L-37 — ✅, guardado individual, 04/10/2026:** Desde Deseleccionar todo (7 casillas a 0), se selecciona explícitamente solo la .app y se pulsa Seleccionar elementos seguros: añade caché y log propios (125 bytes cada uno), deja los cuatro persistentes en 0 y conserva app seleccionada. No se basa solo en preselección inicial.

- **L-38 — ✅, guardado individual, 04/10/2026:** Plan con app+caché+log seleccionados; se marca manualmente también la preferencia propia (4 seleccionados), luego se desmarca la .app. Todos los seis asociados pasan a casilla 0 y enabled=false, incluidos persistentes seleccionados de forma manual.

- **L-39 — ✅, guardado individual, 04/10/2026:** Con app desmarcada, intento de clic sobre caché deshabilitada deja casilla a 0; todos los asociados siguen enabled=false. Al volver a marcar la app se habilitan, conservando casillas a 0. No se obliga el valor AX ni se salta la barrera.

- **L-32 — intento incompleto, sigue pendiente, 04/10/2026:** Se abrió Más de la caché propia, con Conservar visible, pero antes de ejecutar esa opción macOS bloqueó la sesión (CGSSessionScreenIsLocked=Yes, proceso QA vivo). El clic devolvió ventana inaccesible; no se observa desmarcado ni bloqueo por conservar. Consulta de solo lectura en SQLite QA: 0 decisiones para esa ruta. No se marca OK/parcial/fallo. Esta vez se conservan preparados los seis fixtures propios en sus ubicaciones de ~/Library y la .app en ~/Applications, para reanudar sin perder asociación. Solo contienen los datos sintéticos documentados; la raíz Containers incluye su metadata automática de macOS. No se ejecutó retirada ni borrado. Tras desbloquear, revisar/cerrar el menú si sigue abierto y repetir Conservar sobre la caché propia.

- **L-32 — ✅, guardado individual, 04/10/2026:** Conservar ejecutado desde Más de la caché propia: aparece «Elemento marcado como Conservado.», su casilla pasa de 1 a 0 y queda deshabilitada; total baja de 3 / 790 bytes a 2 / 665 bytes. SQLite QA en solo lectura confirma decision=keep para esa ruta. No hay retirada.

- **L-33 — ✅, guardado individual, 04/10/2026:** Clic físico sobre la casilla de la caché conservada no la selecciona; enabled=false y valor0 permanecen. Pulsar Seleccionar elementos seguros tampoco la añade: app+log siguen marcados y la caché conservada queda en0.

- **L-34 — ✅, guardado individual, 04/10/2026:** Se vuelve a ejecutar Analizar desinstalación de la misma app. El nuevo plan mantiene 7 candidatos: caché propia conservada a0/deshabilitada, app+log seleccionados. La decisión keep sigue en SQLite QA. Reanálisis real, no solo cambio de pestaña.

- **L-45 — ✅, guardado individual, 04/10/2026:** Plan general: se deseleccionó todo (incluidos candidatos reales), se seleccionó únicamente el log sintético de 125 bytes y se revisó la hoja con esa única ruta. Confirmar Mover a Papelera termina en «1 eliminados · 0 omitidos · 0 fallidos», original ausente y registro Undo para ese objetivo. No se retira la app ni ningún dato real.

- **L-46 — ✅, guardado individual, 04/10/2026:** SQLite QA registra la ruta real de FileManager.trashItem: /Users/javiercv/.Trash/com.zeuve.qa.cleaner.sil382. El log ya no existe en su ubicación de Library/Logs; su archivo dentro de Papelera conserva SHA-256 0cc506e5c06c1f26e8b2f2ebfc748743aa4abb570195d9b04c9e70caedc15889. Movimiento real y recuperable, no borrado permanente.

- **L-47 — ✅, guardado individual, 04/10/2026:** Resultado de la retirada propia distingue explícitamente «1 eliminados · 0 omitidos · 0 fallidos». Esta prueba valida presentación de los tres contadores en una ejecución correcta; no afirma haber forzado aquí un fallo de filesystem ni un omitido.

- **L-48 — ✅, guardado individual, 04/10/2026:** Tras mover el único log propio a Papelera se observa reanálisis automático: indicador de actividad y lista temporalmente Sin elementos, después desaparece el indicador y se repuebla el plan general. No se pulsa Analizar manualmente para producir esta renovación. Resultado de retirada se conserva visible.

- **L-49 — ✅, guardado individual, 04/10/2026:** Después de terminar el reanálisis automático, la UI muestra 0 seleccionados / 0 KB, casillas visibles vacías y Mover a Papelera deshabilitado. No vuelve a seleccionar automáticamente los candidatos reales tras limpiar.

- **L-50 — ✅, guardado individual, 04/10/2026:** Antes de la retirada no había botón Deshacer en Limpieza; después del movimiento real recuperable aparece Deshacer. SQLite QA contiene el original/ruta de Papelera/fingerprint del único log propio. No se infiere aquí el comportamiento de borrado permanente, todavía pendiente.

- **L-51 — ✅, guardado individual, 04/10/2026:** Deshacer devuelve el log propio a Library/Logs; UI «1 elementos restaurados; 0 no se pudieron restaurar.». Hash del archivo restaurado igual al original 0cc506e5…5889. Se retira su objeto de Papelera y el registro Undo de esa operación queda a0; Deshacer desaparece y la selección sigue vacía.

- **L-52 — ✅, guardado individual, 04/10/2026:** Segundo lote recuperable, solo app+log sintéticos (2 /665 bytes). Tras moverlos a Papelera se crea un log NUEVO propio en la ruta original, hash d789b651…1f02. Deshacer restaura la app, no sobrescribe ni mezcla el nuevo log y deja el original intacto en Papelera (hash0cc506e5…5889). UI1 restaurado/1 no restaurado; protección contra conflicto comprobada.

- **L-53 — ✅, guardado individual, 04/10/2026:** En el Undo parcial del lote propio, la app queda restaurada con hashc3cc867a…347c7 y se elimina su registro Undo. SQLite QA conserva exactamente1 pendiente (log original/ruta de Papelera), la UI mantiene Deshacer y el objeto de Papelera sigue verificable. No se confunde un conflicto previsto con fallo de producto.

- **L-50/L-52/L-53 — recuperación completa, 04/10/2026, sin cambiar recuentos:** Se libera la ruta del log moviendo el objeto NUEVO propio a QA-L.Sil382/Conflicto-Undo/log-nuevo-preservado (hash d789b651…1f02), sin borrarlo. Segundo Deshacer restaura el log original con hash0cc506e5…5889; la app mantiene hashc3cc867a…347c7. UI1 restaurado/0 no restaurados, registros Undo de ese lote a0 y Deshacer desaparece. Los movimientos de esta sesión afectan solo a log y app sintéticos; todos se han restaurado y no queda ninguno de esos originales en Papelera. Caché propia sigue Conservada; otros cuatro persistentes no se retiran. Selección final0. La lista analizada puede preceder a la restauración: volver a analizar antes de preparar otro plan.

- **L-22 — ✅, guardado individual, 04/10/2026:** Al reanalizar la app propia con «ZEUVE QA Uninstall Simulado.app» en Contents/Resources, se observa el aviso de desinstalador relacionado y las acciones Abrir desinstalador oficial/Reanalizar residuos. No se ejecuta el desinstalador. Fixture de bundle válido sin ejecutable ni Team ID: se acepta la oferta por ubicación/nombre, no autenticidad de proveedor ni validación de firma de terceros.

- **L-23 — ✅, guardado individual, 04/10/2026:** La app sintética ZEUVE QA Abierta Sil382 (PID 10230; Bundle ID com.zeuve.qa.cleaner.sil382.running) se detecta abierta. Su app y caché quedan desmarcadas y deshabilitadas; Mover a Papelera también está deshabilitado. «Cerrar aplicación y continuar» termina únicamente el proceso propio y reanaliza: ambas filas pasan a seleccionables/seleccionadas. No se ejecuta eliminación; hashes de Info.plist y caché sin cambios.

- **L-24 — ✅, guardado individual, 04/10/2026:** Tras cerrar y apartar recuperablemente el bundle de QA, un análisis completo con 0 ubicaciones inaccesibles presenta su caché de 106 bytes en Residuos como «Residuo probable», riesgo bajo y evidencia de Bundle ID observado. La fila queda visible con su ruta exacta; no se retira.

- **L-25 — ✅, guardado individual, 04/10/2026:** El log propio ~/Library/Logs/ZEUVE QA Abierta Sil382 coincide solo por nombre, no por Bundle ID: Residuos lo etiqueta «Asociación incierta», riesgo alto y evidencia heurística. Tras «Seleccionar elementos seguros» permanece desmarcado, mientras la caché propia con evidencia fuerte sí se selecciona. No se elimina nada.

- **L-61 — ✅, guardado individual, 04/10/2026:** UI Residuos detecta antiguo-QA.dmg (95 bytes, modificación 01/01/2025) dentro de Downloads/ZEUVE-QA-Sil382-instaladores: Instalador, Asociación incierta, riesgo medio, más de 90 días. Fixture de texto con extensión .dmg, no imagen montable; se valida clasificación por extensión/antigüedad, sin abrirlo.

- **L-62 — ✅, guardado individual, 04/10/2026:** UI Residuos detecta antiguo-QA.pkg (97 bytes, modificación 01/01/2025) como Instalador/Asociación incierta/riesgo medio, más de 90 días. Archivo sintético de texto con extensión .pkg, no paquete instalable; no se instala ni ejecuta.

- **L-63 — ✅, guardado individual, 04/10/2026:** UI Residuos detecta antiguo-QA.xip (98 bytes, modificación 01/01/2025) como Instalador/Asociación incierta/riesgo medio, más de 90 días. Archivo sintético de texto con extensión .xip, no XIP válido; no se extrae ni ejecuta.

- **L-64 — ✅, guardado individual, 04/10/2026:** Los tres instaladores sintéticos antiguos permanecen a 0 después de «Seleccionar elementos seguros». UI muestra riesgo medio, asociación incierta y «La antigüedad no demuestra que ya no sea necesario. Nunca se selecciona automáticamente». Se verifica en contraste con la caché propia probable seleccionada. No se retira ningún instalador.

- **L-58 — ✅, guardado individual, 04/10/2026:** El plan nativo de Limpieza presenta datos de desarrollo detectados realmente: DerivedData de ZEUVE (704,5 MB), ModuleCache.noindex (276,1 MB) y SymbolCache.noindex (21,2 MB), con estado Regenerable y riesgo bajo. Se consultan solo etiquetas/metadatos; todos quedan desmarcados y no se toca ningún dato de Xcode.

- **L-59 — ✅, guardado individual, 04/10/2026:** UI clasifica la carpeta de compilación como «Xcode DerivedData» y ModuleCache.noindex/SymbolCache.noindex como «Índice Xcode», Regenerable/riesgo bajo, con consecuencias diferenciadas recompilar/regenerar índice y evidencia DerivedData. Corroborado en raíces persistidas del análisis. Sin eliminación ni cambio de archivos reales.

- **L-60 — ✅, guardado individual, 04/10/2026:** Se crea exclusivamente el fixture propio Xcode/Archives/ZEUVE-QA-Sil382.xcarchive (texto, no archivo de distribución real). Nuevo análisis nativo termina con cobertura Completa y 0 sin acceso: no genera ninguna raíz de Archives en el resultado persistido, mientras DerivedData/índices siguen presentes. El escáner vigente limita esa categoría a DerivedData. Fixture conservado sin cambios; no se trata como caché ni se autoselecciona. Selección final vacía.

- **Continuidad técnica, 04/10/2026 — L-22–L-25/L-58–L-64:** 11 IDs nuevos OK, ninguno fallido. App propia abierta cerrada por la acción nativa de ZEUVE; su bundle se aparta recuperablemente como QA-L.Sil382/Apps/ZEUVE QA Abierta Sil382.bundle-qa para probar residuos. Su caché y el log heurístico propios permanecen en ~/Library; tres instaladores ficticios de texto, fechados 01/01/2025, en ~/Downloads/ZEUVE-QA-Sil382-instaladores. Fixture de Archives propio conservado bajo ~/Library/Developer/Xcode/Archives/ZEUVE-QA-Sil382.xcarchive. La app propia de ~/Applications conserva el desinstalador simulado anidado, no ejecutado. No se borra ni se mueve ningún dato real; selección final0, app de QA principal PID41759 abierta. Oferta de desinstalador validada por nombre/ubicación en fixture sin firma, no autenticidad de proveedor. Control: clic auxiliar reidentificado por AX y foreground; corregidas coma decimal y referencia AppleScript fuera del proyecto. Lectura masiva de cientos de filas fue demasiado lenta y se canceló solo el controlador propio; se usó la pestaña Residuos y filas concretas de Xcode. No son fallos de ZEUVE. Quedan L-13/L-65, L-72–L-75 y L-54–L-57; no se intenta borrado permanente en esta continuación.

## 1. ZEUVE general




### Arranque y navegación

- [x] ✅ **G-01** ZEUVE abre normalmente sin errores.
- [x] ✅ **G-02** Inicio muestra las siete herramientas.
- [x] ✅ **G-03** Aparece Organizador.
- [x] ✅ **G-04** Aparece Descargador universal.
- [x] ✅ **G-05** Aparece Analizador de chats.
- [x] ✅ **G-06** Aparece Conversor universal.
- [x] ✅ **G-07** Aparece Comparador de seguidores.
- [x] ✅ **G-08** Aparece Inspector multimedia.
- [x] ✅ **G-09** Aparece Limpiador.
- [x] ✅ **G-10** Pulsar una tarjeta de Inicio abre el módulo correcto.
- [x] ✅ **G-11** Pulsar cada módulo en la barra lateral abre el módulo correcto.
- [x] ✅ **G-12** Historial abre correctamente.
- [x] ✅ **G-13** Ajustes abre correctamente.
- [x] ✅ **G-14** Cambiar repetidamente entre módulos no bloquea ni cierra la app.

### Atajos y orden

- [x] ✅ **G-15** ⌘1 abre Organizador con valores de fábrica.
- [x] ✅ **G-16** ⌘2 abre Descargador.
- [x] ✅ **G-17** ⌘3 abre Analizador.
- [x] ✅ **G-18** ⌘4 abre Conversor.
- [x] ✅ **G-19** ⌘5 abre Comparador.
- [x] ✅ **G-20** ⌘6 abre Inspector.
- [x] ✅ **G-21** ⌘7 abre Limpiador.
- [x] ✅ **G-22** ⌘8 abre Historial.
- [x] ✅ **G-23** En Ajustes puedes cambiar el orden de los módulos.
- [x] ✅ **G-24** El nuevo orden aparece igual en la barra lateral.
- [x] ✅ **G-25** El nuevo orden aparece igual en Inicio.
- [x] ✅ **G-26** Puedes cambiar un atajo.
- [x] ✅ **G-27** El nuevo atajo funciona.
- [x] ✅ **G-28** Puedes dejar un módulo sin atajo.
- [x] ✅ **G-29** No permite crear combinaciones conflictivas/inválidas.
- [x] ✅ **G-30** «Restaurar orden y atajos predeterminados» funciona.

### Apariencia y ayuda

- [x] ✅ **G-31** Tema Sistema funciona.
- [x] ✅ **G-32** Tema Claro funciona.
- [x] ✅ **G-33** Tema Oscuro funciona.
- [x] ✅ **G-34** Los textos siguen siendo legibles en claro y oscuro.
- [x] ✅ **G-35** Los iconos `ⓘ`/ayuda contextual se pueden abrir.
- [x] ✅ **G-36** Abrir ayuda no inicia operaciones ni cambia ajustes.

### OperationCoordinator

- [x] ✅ **G-37** Durante una operación pesada aparece información/progreso global.
- [x] ✅ **G-38** Mientras hay una operación pesada, otra operación pesada incompatible no arranca simultáneamente.
- [x] ✅ **G-39** Cancelar una operación devuelve posteriormente ZEUVE a un estado utilizable.
- [x] ✅ **G-40** Después de terminar/cancelar una operación puedes empezar otra normalmente.

---

# 2. Historial global

- [x] ✅ **H-01** Una operación terminada aparece en Historial.
- [x] ✅ **H-02** Muestra correctamente el módulo.
- [x] ✅ **H-03** Muestra correctamente estado: completada/fallida/cancelada/etc.
- [x] ✅ **H-04** El filtro «Todos los módulos» funciona.
- [x] ✅ **H-05** Puedes filtrar por Organizador.
- [x] ✅ **H-06** Puedes filtrar por Descargador.
- [x] ✅ **H-07** Puedes filtrar por Analizador.
- [x] ✅ **H-08** Puedes filtrar por Conversor.
- [x] ✅ **H-09** Puedes filtrar por Comparador.
- [x] ✅ **H-10** Puedes filtrar por Inspector.
- [x] ✅ **H-11** Puedes filtrar por Limpiador cuando corresponda.
- [x] ✅ **H-12** «Actualizar» refresca el historial.
- [x] ✅ **H-13** Cuando una operación tiene carpeta de salida aparece «Abrir» y funciona.
- [x] ✅ **H-14** Las operaciones de Organizador deshacibles muestran «Deshacer».
- [x] ✅ **H-15** El historial continúa funcionando después de cerrar y volver a abrir ZEUVE.

---

# 3. Ajustes generales

- [x] ✅ **S-01** La sección General funciona.
- [x] ✅ **S-02** Hay sección de Organizador.
- [x] ✅ **S-03** Hay sección de Descargador.
- [x] ✅ **S-04** Hay sección de Analizador.
- [x] ✅ **S-05** Hay sección de Conversor.
- [x] ✅ **S-06** Hay sección de Inspector.
- [x] ✅ **S-07** Hay sección de Limpiador.
- [x] ✅ **S-08** El Comparador no muestra innecesariamente una sección propia.
- [x] ✅ **S-09** Puedes abrir la carpeta de registros.
- [x] ✅ **S-10** ZEUVE muestra la versión correcta.
- [x] ✅ **S-11** Cambiar un ajuste persiste al reiniciar la app.
- [x] ✅ **S-12** Cambiar un valor predeterminado no modifica una operación ya preparada.
- [x] ✅ **S-13** «Restaurar todos los ajustes predeterminados» pide confirmación.
- [x] ✅ **S-14** La restauración funciona.
- [x] ✅ **S-15** No borra Historial.
- [x] ❌ **S-16** No borra presets/preajustes.
- [x] ✅ **S-17** No borra favoritos.
- [x] ✅ **S-18** No borra los archivos del usuario.

---

# 4. Organizador de archivos

## Entrada

- [x] ✅ **O-01** Seleccionar carpeta con el selector funciona.
- [x] ✅ **O-02** Arrastrar una carpeta funciona.
- [x] ✅ **O-03** Recuerda la última carpeta.
- [x] ✅ **O-04** Aparecen carpetas recientes.
- [x] ✅ **O-05** Puedes reutilizar una carpeta reciente.

## Clasificación

- [x] ✅ **O-06** Nivel Simple crea categorías generales.
- [x] ✅ **O-07** Nivel Detallado crea categoría + formato.
- [x] ✅ **O-08** Clasifica imágenes.
- [x] ✅ **O-09** Clasifica vídeos.
- [x] ✅ **O-10** Clasifica audio.
- [x] ✅ **O-11** Clasifica documentos.
- [x] ✅ **O-12** Clasifica comprimidos.
- [x] ✅ **O-13** Clasifica instaladores.
- [x] ✅ **O-14** Clasifica código.
- [x] ✅ **O-15** Clasifica fuentes/diseño.
- [x] ✅ **O-16** Una extensión desconocida va a «Otros».
- [x] ✅ **O-17** Un archivo sin extensión se maneja correctamente.
- [ ] ⚠️ **O-18** Las reglas personalizadas funcionan.

## Archivos relacionados

- [x] ✅ **O-19** Dos archivos con mismo nombre base pueden agruparse.
- [x] ✅ **O-20** Si son de la misma categoría quedan juntos correctamente.
- [x] ✅ **O-21** Si son de categorías diferentes van a «Relacionados».
- [x] ✅ **O-22** Desactivar agrupación hace que vuelvan a clasificarse individualmente.

## Recursión y seguridad

- [x] ✅ **O-23** «Incluir subcarpetas» funciona.
- [x] ✅ **O-24** Desactivarlo limita el análisis correctamente.
- [x] ✅ **O-25** «Incluir ocultos» funciona.
- [x] ✅ **O-26** Con la opción desactivada no mueve ocultos.
- [x] ✅ **O-27** No sigue enlaces simbólicos.
- [x] ✅ **O-28** No entra dentro de `.app`/bundles como si fueran carpetas normales.
- [x] ✅ **O-29** Rechaza una ubicación crítica del sistema.

## Vista previa

- [x] ✅ **O-30** Analizar genera una vista previa antes de mover nada.
- [x] ✅ **O-31** El resumen de archivos es correcto.
- [x] ✅ **O-32** El resumen de categorías es correcto.
- [x] ✅ **O-33** El resumen de conflictos es correcto.
- [x] ✅ **O-34** Puedes desmarcar movimientos individuales.
- [x] ✅ **O-35** Puedes volver a marcarlos.
- [x] ✅ **O-36** Exportar plan a CSV funciona.
- [x] ✅ **O-37** Exportar CSV no mueve archivos.

## Conflictos

- [x] ✅ **O-38** «Renombrar automáticamente» evita sobrescribir.
- [x] ✅ **O-39** Genera nombres como `archivo_2.ext`.
- [x] ✅ **O-40** «Omitir» deja intacto el archivo conflictivo.
- [x] ✅ **O-41** «Revisar conflictos» los deja visibles.
- [x] ✅ **O-42** Si aparece un conflicto después del análisis, no sobrescribe el archivo nuevo.

## Ejecución y Undo

- [x] ✅ **O-43** Ejecutar mueve realmente los archivos seleccionados.
- [x] ✅ **O-44** No mueve los desmarcados.
- [x] ✅ **O-45** «Abrir carpeta» funciona al terminar.
- [x] ✅ **O-46** Cancelar durante una operación funciona.
- [x] ✅ **O-47** La operación aparece en Historial.
- [x] ✅ **O-48** Deshacer devuelve los archivos a sus ubicaciones originales.
- [x] ✅ **O-49** Undo no sobrescribe una ruta original que haya vuelto a ocuparse.
- [x] ✅ **O-50** Si modificas el archivo organizado antes del Undo, ZEUVE lo trata de forma segura.

---

# 5. Descargador universal

## Entrada y análisis general

- [x] ✅ **D-01** Pegar una URL válida permite analizarla.
- [x] ✅ **D-02** Una URL no compatible produce un error comprensible.
- [x] ✅ **D-03** Cancelar un análisis funciona.
- [x] ✅ **D-04** Después de cancelar puedes analizar otra URL.
- [x] ✅ **D-05** Un archivo descargado aparece realmente en la carpeta elegida.
- [x] ✅ **D-06** No deja `.part` publicado como resultado definitivo.
- [x] ✅ **D-07** No sobrescribe un archivo existente silenciosamente.
- [x] ✅ **D-08** El progreso funciona.
- [x] ✅ **D-09** Cancelar una descarga funciona.

## Plataformas

- [x] ✅ **D-10** YouTube.
- [ ] ➖ **D-11** Instagram.
- [x] ✅ **D-12** TikTok vídeo.
- [x] ❌ **D-13** TikTok foto/carrusel.
- [x] ✅ **D-14** Pinterest.
- [ ] ⚠️ **D-15** X/Twitter.
- [ ] ➖ **D-16** Facebook.
- [ ] ➖ **D-17** Reddit.
- [ ] ➖ **D-18** Twitch con contenido ya publicado.
- [x] ✅ **D-19** Vimeo.
- [x] ✅ **D-20** Dailymotion.
- [x] ✅ **D-21** SoundCloud.
- [ ] ➖ **D-22** Tumblr.
- [ ] ➖ **D-23** Threads.
- [ ] ➖ **D-24** Snapchat público.
- [ ] ➖ **D-25** EroMe mediante enlace concreto, si se quiere probar esa compatibilidad.

## YouTube

- [x] ✅ **D-26** Un vídeo público funciona sin iniciar sesión.
- [x] ✅ **D-27** «Original» conserva el contenido sin convertir cuando es viable.
- [x] ✅ **D-28** «Vídeo» funciona.
- [x] ✅ **D-29** «Solo audio» funciona.
- [x] ✅ **D-30** Una selección de calidad concreta se respeta.
- [x] ✅ **D-31** Un preset de vídeo funciona.
- [x] ✅ **D-32** Un preset con subtítulos funciona con un vídeo que los tenga.

## Instagram

- [ ] ➖ **D-33** `@usuario` funciona.
- [ ] ➖ **D-34** URL de perfil funciona.
- [ ] ➖ **D-35** Publicación individual funciona.
- [ ] ➖ **D-36** Foto funciona.
- [ ] ➖ **D-37** Vídeo/Reel funciona.
- [ ] ➖ **D-38** Carrusel muestra todos los elementos y en el orden correcto.
- [ ] ➖ **D-39** Un perfil público se analiza sin obligar a iniciar sesión.
- [ ] ➖ **D-40** Muestra publicaciones.
- [ ] ➖ **D-41** Muestra Reels.
- [ ] ➖ **D-42** Muestra foto de perfil.
- [ ] ➖ **D-43** Sin sesión, Stories/Destacadas restringidas no bloquean el resto del perfil.
- [ ] ➖ **D-44** Con una sesión válida se puede acceder a las secciones que esa cuenta ya puede ver.
- [ ] ➖ **D-45** Pegar una cabecera Cookie funciona.
- [ ] ➖ **D-46** Importar `cookies.txt` funciona.
- [ ] ➖ **D-47** Seleccionar archivo Netscape funciona.
- [ ] ➖ **D-48** Importar expresamente desde un navegador compatible funciona.
- [ ] ➖ **D-49** «Recordar» conserva la sesión.
- [ ] ➖ **D-50** Reiniciar ZEUVE recupera la sesión recordada.
- [ ] ➖ **D-51** Restaurar ajustes globales elimina esa sesión recordada.

## Catálogos y selección

- [ ] ➖ **D-52** Vista cuadrícula funciona.
- [x] ✅ **D-53** Vista lista funciona.
- [ ] ➖ **D-54** Cambiar tamaño de miniaturas funciona.
- [x] ✅ **D-55** Carga inicial del catálogo funciona.
- [ ] ➖ **D-56** «Cargar más» funciona.
- [x] ✅ **D-57** Selección individual funciona.
- [x] ✅ **D-58** Selección múltiple funciona.
- [x] ✅ **D-59** «Seleccionar solo contenido nuevo» funciona.
- [ ] ⚠️ **D-60** Organización en carpetas por plataforma/sección/publicación funciona según configuración.

## Perfiles y presets

- [x] ✅ **D-61** «Por defecto de la plataforma» funciona.
- [x] ✅ **D-62** El valor de fábrica «Original sin convertir» funciona.
- [x] ✅ **D-63** Editar un perfil de plataforma funciona.
- [x] ✅ **D-64** Restaurar el perfil funciona.
- [x] ✅ **D-65** Crear una regla personalizada para un dominio funciona.
- [x] ✅ **D-66** La regla solo para dominio exacto funciona.
- [x] ✅ **D-67** La opción de incluir subdominios funciona.
- [x] ✅ **D-68** Desactivar una regla sin borrarla funciona.
- [x] ✅ **D-69** Un modo elegido manualmente tiene prioridad sobre el perfil.
- [x] ✅ **D-70** Cambiar un perfil durante una descarga ya preparada no altera esa descarga.

## Otros comportamientos

- [x] ✅ **D-71** El bloqueo de contenido adulto aparece cuando corresponde y está desactivado.
- [x] ✅ **D-72** Activarlo desde Ajustes cambia ese comportamiento.
- [ ] ➖ **D-73** Un directo activo/programado se rechaza.
- [ ] ➖ **D-74** Una repetición ya publicada como vídeo normal puede descargarse.
- [x] ✅ **D-75** Guardar descripción opcional funciona.
- [x] ✅ **D-76** Guardar JSON de metadatos funciona.
- [x] ✅ **D-77** Una descarga correcta aparece en Historial.
- [ ] ➖ **D-78** Si un elemento de un lote falla, los demás pueden continuar.
- [x] ✅ **D-79** La carpeta de salida recordada persiste correctamente.
- [x] ✅ **D-80** Restaurar ajustes globales olvida la carpeta de salida pero no borra archivos descargados.

---

# 6. Analizador de chats

## Importación

- [x] ✅ **A-01** WhatsApp ZIP funciona.
- [x] ✅ **A-02** WhatsApp TXT directo funciona.
- [x] ✅ **A-03** Instagram ZIP completo funciona.
- [x] ✅ **A-04** ZIP de una conversación Instagram funciona.
- [x] ✅ **A-05** En modo avanzado se pueden seleccionar `message_N.html`.
- [x] ✅ **A-06** En modo avanzado se puede seleccionar una carpeta exportada de Instagram.
- [x] ✅ **A-07** Drag & drop funciona.
- [x] ✅ **A-08** No acepta dos veces exactamente la misma fuente.
- [x] ✅ **A-09** Si un ZIP de WhatsApp contiene varios TXT candidatos permite escoger.
- [x] ✅ **A-10** Si solo hay uno lo selecciona automáticamente.
- [x] ✅ **A-11** Si Instagram contiene varias conversaciones permite elegir.
- [x] ✅ **A-12** Si solo contiene una la selecciona.

## WhatsApp

- [x] ✅ **A-13** Mensajes multilínea se interpretan bien.
- [x] ✅ **A-14** Nombres que contienen espacios funcionan.
- [x] ✅ **A-15** Texto con `:` no rompe el autor.
- [x] ✅ **A-16** Mensajes del sistema se reconocen.
- [x] ✅ **A-17** Multimedia se reconoce.
- [x] ✅ **A-18** Llamadas se reconocen.
- [x] ✅ **A-19** Ubicaciones/contactos/enlaces se reconocen.
- [x] ✅ **A-20** Con ZIP, adjuntos existentes aparecen como existentes.
- [x] ✅ **A-21** Adjuntos faltantes aparecen como faltantes.
- [x] ✅ **A-22** Con TXT solo aparecen como «no comprobados», no como faltantes.

## Instagram y fechas

- [x] ✅ **A-23** Los mensajes aparecen cronológicamente.
- [x] ✅ **A-24** Fechas españolas se interpretan correctamente.
- [x] ✅ **A-25** Fechas inglesas se interpretan correctamente.
- [x] ✅ **A-26** La estrategia California → España funciona.
- [x] ✅ **A-27** UTC → España funciona.
- [x] ✅ **A-28** «Ya está en horario de España» funciona.
- [x] ✅ **A-29** «No convertir hora» funciona.

## Las 9 pestañas

- [x] ✅ **A-30** Resumen.
- [x] ✅ **A-31** Actividad.
- [x] ✅ **A-32** Participantes y perfiles.
- [x] ✅ **A-33** Palabras y emojis.
- [x] ✅ **A-34** Búsqueda.
- [x] ✅ **A-35** Conversaciones.
- [x] ✅ **A-36** Tiempos de respuesta.
- [x] ✅ **A-37** Comparación.
- [x] ✅ **A-38** Fusiones.

## Filtros y gráficos

- [x] ✅ **A-39** Filtro por fechas.
- [x] ✅ **A-40** Filtro por participante.
- [x] ✅ **A-41** Filtro por plataforma.
- [x] ✅ **A-42** Filtro por tipo de contenido.
- [x] ✅ **A-43** Filtro por día de semana.
- [x] ✅ **A-44** Filtro horario.
- [x] ✅ **A-45** Un intervalo horario que cruza medianoche funciona.
- [x] ✅ **A-46** Hover de gráficos muestra valores.
- [x] ✅ **A-47** Hover no deja tooltips atrapados.
- [x] ✅ **A-48** Mapa de calor responde al cursor.
- [x] ✅ **A-49** Cambiar filtros no congela la interfaz.

## Búsqueda

- [x] ✅ **A-50** Frase exacta.
- [x] ✅ **A-51** Todas las palabras.
- [x] ✅ **A-52** Cualquiera de las palabras.
- [x] ✅ **A-53** Mayúsculas/minúsculas.
- [x] ✅ **A-54** Palabra completa.
- [x] ✅ **A-55** Tratamiento de tildes.
- [x] ✅ **A-56** Contexto 1 mensaje.
- [x] ✅ **A-57** Contexto 3 mensajes.
- [x] ✅ **A-58** Contexto 5 mensajes.
- [x] ✅ **A-59** Paginación 25.
- [x] ✅ **A-60** Paginación 50.
- [x] ✅ **A-61** Paginación 100.

## Conversaciones, respuestas y fusiones

- [x] ✅ **A-62** Cambiar umbral de conversación cambia la agrupación.
- [x] ✅ **A-63** Cambiar ventana máxima de respuesta cambia el cálculo.
- [x] ✅ **A-64** Comparar dos personas funciona.
- [x] ✅ **A-65** Fusionar identidades recalcula estadísticas.
- [x] ✅ **A-66** Deshacer una fusión funciona.
- [x] ✅ **A-67** Restablecer fusiones funciona.
- [x] ✅ **A-68** Las fusiones desaparecen al cerrar la sesión, como está previsto.

## Ciclo de vida

- [x] ✅ **A-69** «Analizar otro chat» vuelve a una pantalla vacía.
- [x] ✅ **A-70** «Cerrar análisis» conserva las fuentes seleccionadas.
- [x] ✅ **A-71** Cancelar un análisis funciona.
- [x] ✅ **A-72** No presenta resultados parciales como completos.
- [x] ✅ **A-73** Tras cancelar se puede iniciar otro análisis.
- [x] ✅ **A-74** El análisis aparece en Historial.
- [x] ✅ **A-75** Los iconos de ayuda de las nueve pestañas funcionan.

---

# 7. Conversor universal

## Imágenes

- [x] ✅ **C-01** PNG → JPEG.
- [x] ✅ **C-02** JPEG → PNG.
- [x] ✅ **C-03** HEIC → JPEG/PNG.
- [x] ✅ **C-04** TIFF.
- [x] ✅ **C-05** BMP.
- [x] ✅ **C-06** Conversión que preserve correctamente dimensiones esperadas.

## Animaciones

- [x] ✅ **C-07** GIF.
- [x] ✅ **C-08** WebP animado.
- [x] ✅ **C-09** APNG.

## Audio

- [x] ✅ **C-10** MP3.
- [ ] ⚠️ **C-11** M4A/AAC.
- [x] ✅ **C-12** FLAC.
- [x] ✅ **C-13** WAV.
- [x] ❌ **C-14** Opus.
- [x] ❌ **C-15** OGG.
- [x] ✅ **C-16** Cambiar calidad/bitrate cuando la salida lo permita.

## Vídeo

- [x] ✅ **C-17** MP4.
- [x] ✅ **C-18** MOV.
- [x] ✅ **C-19** MKV.
- [x] ❌ **C-20** WebM.
- [x] ✅ **C-21** AVI como entrada.
- [x] ✅ **C-22** Vídeo → vídeo recodificado.
- [x] ✅ **C-23** Vídeo → audio.
- [x] ✅ **C-24** Audio → vídeo.
- [x] ✅ **C-25** Copia rápida/stream copy en modo avanzado cuando sea compatible.

## Imágenes/secuencias/fotogramas

- [x] ✅ **C-26** Vídeo → fotogramas.
- [x] ✅ **C-27** Se genera la carpeta de fotogramas.
- [x] ✅ **C-28** `tiempos.csv` se genera si se solicita.
- [x] ✅ **C-29** Cancelar extracción deja resultados completos como «Incompleto» según diseño.
- [x] ✅ **C-30** Secuencia de imágenes → vídeo/animación cuando corresponda.
- [x] ✅ **C-31** Imágenes → PDF.

## PDF

- [x] ✅ **C-32** PDF → imágenes.
- [x] ✅ **C-33** PDF → texto.
- [x] ✅ **C-34** Un PDF protegido compatible permite introducir contraseña sin persistirla.

## Texto y datos

- [ ] ➖ **C-35** TXT → Markdown/HTML si Pandoc está preparado.
- [ ] ➖ **C-36** Markdown → TXT/HTML si Pandoc está preparado.
- [ ] ➖ **C-37** HTML → TXT/Markdown si Pandoc está preparado.
- [x] ✅ **C-38** CSV se reconoce correctamente.
- [x] ✅ **C-39** JSON se reconoce correctamente.
- [x] ✅ **C-40** XML se reconoce correctamente.
- [x] ✅ **C-41** Una operación mismo formato/copia segura funciona.

## Entradas múltiples

- [ ] ➖ **C-42** Varios archivos.
- [x] ✅ **C-43** Carpeta.
- [x] ✅ **C-44** ZIP.
- [x] ✅ **C-45** El progreso de lote funciona.
- [x] ❌ **C-46** Cancelar un lote funciona.
- [x] ✅ **C-47** Presets funcionan.
- [ ] ⚠️ **C-48** Favoritos funcionan.

## Rechazos deliberados

Estos deben rechazarse claramente, no convertirse:

- [x] ✅ **C-49** EPUB.
- [x] ✅ **C-50** MOBI.
- [x] ✅ **C-51** AZW/AZW3.
- [x] ✅ **C-52** FB2.
- [x] ✅ **C-53** EPS.
- [x] ✅ **C-54** DOC/DOCX.
- [x] ✅ **C-55** XLS/XLSX.
- [x] ✅ **C-56** PPT/PPTX.
- [x] ✅ **C-57** ODT/ODS/ODP.
- [x] ✅ **C-58** RTF.

## Seguridad

- [x] ✅ **C-59** El original sigue intacto después de convertir.
- [x] ✅ **C-60** Un conflicto de nombre no produce sobrescritura silenciosa.
- [x] ✅ **C-61** Cancelar no publica como válido un archivo roto.
- [x] ✅ **C-62** La carpeta de salida recordada funciona.
- [x] ✅ **C-63** Una conversión completada aparece en Historial.

---

# 8. Comparador de seguidores de Instagram

- [x] ✅ **F-01** Importar ZIP completo funciona.
- [ ] ➖ **F-02** Drag & drop del ZIP funciona.
- [x] ✅ **F-03** Detecta `following.json`.
- [x] ✅ **F-04** Detecta uno o varios `followers_N.json`.
- [x] ✅ **F-05** Acepta huecos en la numeración de followers.
- [x] ✅ **F-06** Modo avanzado con JSON separados funciona.
- [x] ✅ **F-07** Archivos duplicados se rechazan.
- [x] ✅ **F-08** Un JSON malformado da error comprensible.
- [x] ✅ **F-09** Un JSON válido pero de estructura incorrecta da un error distinto.
- [x] ✅ **F-10** El análisis no comienza hasta pulsar «Analizar exportación».
- [x] ✅ **F-11** Total de seguidores es correcto.
- [x] ✅ **F-12** Total de seguidos es correcto.
- [x] ✅ **F-13** «Sigo pero no me siguen» es correcto.
- [x] ✅ **F-14** «Me siguen pero no sigo» es correcto.
- [x] ✅ **F-15** «Seguimiento mutuo» es correcto.
- [x] ✅ **F-16** Búsqueda parcial funciona.
- [x] ✅ **F-17** Orden A–Z funciona.
- [x] ✅ **F-18** Orden Z–A funciona.
- [x] ✅ **F-19** Un resultado vacío se presenta correctamente.
- [x] ✅ **F-20** «Abrir en Instagram» abre manualmente el perfil.
- [x] ✅ **F-21** Exportar categoría a TXT.
- [x] ✅ **F-22** Exportar categoría a CSV.
- [x] ✅ **F-23** Exportar solo resultados visibles tras búsqueda.
- [x] ✅ **F-24** El reemplazo de una exportación existente exige confirmación de macOS.
- [x] ✅ **F-25** Cancelar análisis funciona.
- [x] ✅ **F-26** El análisis aparece en Historial.
- [x] ✅ **F-27** Funciona sin iniciar sesión en Instagram.

---

# 9. Inspector multimedia

## Apertura e inspección

- [x] ✅ **I-01** Abrir archivo con selector.
- [x] ✅ **I-02** Arrastrar archivo.
- [x] ✅ **I-03** MKV.
- [x] ✅ **I-04** MP4.
- [x] ✅ **I-05** MOV.
- [x] ✅ **I-06** WebM.
- [x] ✅ **I-07** Muestra contenedor/formato.
- [x] ✅ **I-08** Muestra duración.
- [x] ✅ **I-09** Muestra streams de vídeo.
- [x] ✅ **I-10** Muestra streams de audio.
- [x] ✅ **I-11** Muestra subtítulos.
- [x] ✅ **I-12** Muestra capítulos.
- [x] ✅ **I-13** Muestra metadata.
- [x] ✅ **I-14** Muestra attachments.
- [x] ✅ **I-15** Muestra carátulas/`attached_pic` cuando existen.
- [x] ✅ **I-16** Abrir otro archivo limpia correctamente el estado anterior.
- [x] ✅ **I-17** Cerrar archivo limpia correctamente la sesión.
- [x] ✅ **I-18** Si existe un borrador con cambios pide confirmación antes de descartarlo.

## Preview de audio

- [x] ✅ **I-19** Play.
- [x] ✅ **I-20** Pausa responde inmediatamente.
- [x] ✅ **I-21** Reanudar responde inmediatamente.
- [x] ✅ **I-22** Seek con la timeline.
- [x] ✅ **I-23** Seek hacia delante.
- [x] ✅ **I-24** Seek hacia atrás.
- [x] ✅ **I-25** Cambiar velocidad.
- [x] ✅ **I-26** 0,5× funciona.
- [x] ✅ **I-27** 1× funciona.
- [x] ✅ **I-28** 2× funciona.
- [ ] ⚠️ **I-29** Volumen funciona.
- [x] ✅ **I-30** Cambiar pista de audio conserva el instante.
- [x] ✅ **I-31** Cambiar pista mientras reproduce conserva Play.
- [x] ✅ **I-32** Cambiar pista estando pausado conserva Pausa.
- [x] ❌ **I-33** Ninguna acción habitual se siente con el retraso de \~1 segundo que se corrigió.

## Preview de vídeo

- [x] ✅ **I-34** El vídeo se reproduce.
- [ ] ⚠️ **I-35** Vídeo y audio están sincronizados.
- [x] ✅ **I-36** Pausar conserva el frame.
- [x] ✅ **I-37** Reanudar no reinicia desde cero.
- [x] ❌ **I-38** Seek de vídeo funciona.
- [x] ❌ **I-39** Cambiar pista de audio durante vídeo conserva posición.
- [x] ✅ **I-40** Cambiar stream de vídeo conserva posición.
- [x] ✅ **I-41** El cambio de stream no reproduce accidentalmente otro stream con el mismo índice de otra fuente.
- [x] ✅ **I-42** Fullscreen entra correctamente.
- [x] ✅ **I-43** Fullscreen sale correctamente.
- [x] ✅ **I-44** Escalado de vídeo es correcto.
- [x] ✅ **I-45** Aspect ratio se conserva.

## Subtítulos de preview

- [x] ✅ **I-46** Activar subtítulos SRT internos.
- [x] ✅ **I-47** Activar ASS/SSA.
- [x] ✅ **I-48** Los textos aparecen sincronizados.
- [x] ✅ **I-49** Cambiar pista de subtítulos funciona.
- [x] ✅ **I-50** Desactivar subtítulos funciona.
- [x] ✅ **I-51** Seek actualiza correctamente el subtítulo visible.

## Waveform/timeline

- [x] ✅ **I-52** Se genera waveform.
- [x] ✅ **I-53** Scrub sobre waveform mueve el playhead.
- [x] ✅ **I-54** Playhead de waveform y reproductor coincide.
- [x] ✅ **I-55** Zoom funciona.
- [x] ✅ **I-56** Pan funciona.
- [x] ✅ **I-57** Capítulos aparecen en timeline cuando corresponde.
- [x] ✅ **I-58** Overlays de análisis aparecen cuando están activados.

## Espectrograma

- [x] ✅ **I-59** Generar espectrograma.
- [x] ✅ **I-60** El resultado corresponde a la pista elegida.
- [x] ✅ **I-61** El playhead coincide con reproductor/waveform.
- [x] ✅ **I-62** Pulsar/scrub en espectrograma hace seek correctamente.
- [x] ✅ **I-63** Zoom/pan funciona.
- [x] ✅ **I-64** Cambiar parámetros visuales reutilizables no vuelve a decodificar innecesariamente.
- [x] ✅ **I-65** Exportar espectrograma funciona.
- [x] ❌ **I-66** La barra inferior/reproductor sigue visible.

## Sonoridad y señal

- [x] ✅ **I-67** Integrated Loudness / LUFS.
- [x] ✅ **I-68** LRA.
- [x] ✅ **I-69** True Peak.
- [x] ✅ **I-70** Sample Peak.
- [x] ✅ **I-71** Timeline de sonoridad.
- [x] ✅ **I-72** Detección de silencios.
- [x] ✅ **I-73** Detección de posible clipping.
- [x] ✅ **I-74** Eventos aparecen en timeline.
- [x] ✅ **I-75** Con una sola pista se ejecuta correctamente la automatización configurada.
- [x] ✅ **I-76** Con varias pistas no selecciona silenciosamente una pista para análisis pesado.

## A/B

- [x] ✅ **I-77** Elegir pista A.
- [x] ✅ **I-78** Elegir pista B.
- [x] ✅ **I-79** Alternar A/B conserva timestamp.
- [x] ✅ **I-80** Alternar A/B conserva Play/Pausa.
- [x] ✅ **I-81** A/B no cambia silenciosamente la pista seleccionada para espectrograma.
- [x] ✅ **I-82** «Completar análisis A/B» funciona.

## Fuente con pérdida y anomalías

- [x] ✅ **I-83** Análisis de indicios de fuente con pérdida termina.
- [x] ✅ **I-84** Presenta nivel de evidencia comprensible.
- [x] ✅ **I-85** Muestra métricas/evidencias.
- [x] ✅ **I-86** No afirma automáticamente «fake lossless» basándose solo en un cutoff.
- [x] ✅ **I-87** Detección de anomalías espectrales funciona.
- [x] ✅ **I-88** Las anomalías tienen localización temporal.
- [x] ✅ **I-89** Aparecen correctamente en timeline.

## OCR bitmap

Con un archivo que tenga PGS compatible:

- [x] ✅ **I-90** Detecta la pista bitmap.
- [x] ✅ **I-91** Inicia OCR.
- [x] ✅ **I-92** Puede cancelarse.
- [ ] ⚠️ **I-93** Produce borrador revisable.
- [x] ✅ **I-94** Muestra confianza/idioma cuando corresponda.
- [x] ✅ **I-95** Permite revisar/corregir el texto.
- [ ] ⚠️ **I-96** Exportar SRT funciona.
- [x] ✅ **I-97** No sustituye automáticamente el subtítulo original.

## Edición de streams

Usar siempre una copia prescindible.

- [x] ✅ **I-98** Entrar en modo edición.
- [x] ✅ **I-99** Eliminar vídeo cuando la estructura resultante sea válida.
- [x] ✅ **I-100** Eliminar pista de audio.
- [x] ✅ **I-101** Eliminar subtítulo.
- [x] ✅ **I-102** Añadir audio externo compatible.
- [x] ✅ **I-103** Añadir subtítulo externo compatible.
- [x] ✅ **I-104** Añadir vídeo externo compatible cuando proceda.
- [x] ✅ **I-105** Reordenar vídeo.
- [x] ✅ **I-106** Reordenar audio.
- [x] ✅ **I-107** Reordenar subtítulos.
- [x] ✅ **I-108** Cambiar título.
- [x] ✅ **I-109** Cambiar idioma.
- [x] ✅ **I-110** Cambiar default/disposition.
- [x] ✅ **I-111** Elegir stream principal cuando el contenedor lo permita.
- [x] ✅ **I-112** Undo del borrador funciona.
- [x] ✅ **I-113** Redo del borrador funciona.

## Capítulos

- [x] ✅ **I-114** Añadir capítulo.
- [x] ✅ **I-115** Eliminar capítulo.
- [x] ✅ **I-116** Renombrar capítulo.
- [x] ✅ **I-117** Cambiar su posición temporal.
- [x] ✅ **I-118** Timeline refleja cambios antes de ejecutar.

## Metadata

- [x] ✅ **I-119** Editar tag permitido.
- [x] ❌ **I-120** Editar metadata de stream permitida.
- [x] ✅ **I-121** Tags desconocidos siguen visibles.
- [x] ✅ **I-122** No convierte indiscriminadamente cualquier tag en editable.

## Attachments

- [x] ✅ **I-123** Visualizar attachment.
- [x] ✅ **I-124** Extraer attachment.
- [x] ✅ **I-125** Eliminar attachment.
- [x] ✅ **I-126** Añadir attachment externo compatible.
- [x] ❌ **I-127** Editar nombre/MIME cuando corresponda.

## Carátulas

- [x] ✅ **I-128** Visualizar carátula.
- [x] ✅ **I-129** Extraer carátula.
- [x] ❌ **I-130** Añadir carátula.
- [x] ❌ **I-131** Sustituir carátula.
- [x] ❌ **I-132** Eliminar carátula.
- [x] ❌ **I-133** Resultado correcto en MKV.
- [ ] ⚠️ **I-134** Resultado correcto en MP4/MOV compatible.

## Ejecutar edición

- [ ] ⚠️ **I-135** Antes de ejecutar se puede revisar el plan.
- [x] ❌ **I-136** Ejecutar genera un archivo nuevo.
- [x] ✅ **I-137** El original permanece intacto.
- [x] ✅ **I-138** El resultado contiene exactamente los streams previstos.
- [x] ✅ **I-139** Audio/vídeo se mantienen por stream copy.
- [x] ✅ **I-140** Una operación que necesitaría transcode audiovisual es rechazada, no recodificada a escondidas.
- [x] ✅ **I-141** Conflicto de nombre no sobrescribe silenciosamente.
- [x] ✅ **I-142** Cancelar edición funciona.
- [x] ✅ **I-143** El archivo final abre correctamente después de la validación.

## Lotes

- [x] ✅ **I-144** Seleccionar varios archivos.
- [x] ✅ **I-145** Añadir carpeta.
- [x] ✅ **I-146** Recorrer subcarpetas.
- [x] ✅ **I-147** Controlar profundidad.
- [x] ✅ **I-148** Incluir/excluir ocultos.
- [x] ✅ **I-149** Aplicar filtros.
- [x] ✅ **I-150** No seguir symlinks.
- [x] ✅ **I-151** Deduplicar entradas.
- [x] ✅ **I-152** Lote de inspección.
- [x] ✅ **I-153** Lote de señal.
- [x] ✅ **I-154** Lote de sonoridad.
- [x] ✅ **I-155** Lote de espectrogramas.
- [x] ✅ **I-156** Lote de informes.
- [x] ✅ **I-157** Un archivo incompatible no detiene los demás.
- [x] ✅ **I-158** Cancelar lote conserva únicamente resultados ya publicados correctamente.

## Reglas de edición por lotes

- [x] ✅ **I-159** Crear conjunto de reglas.
- [x] ✅ **I-160** Condición → acción funciona.
- [ ] ⚠️ **I-161** Preflight muestra qué ocurrirá.
- [ ] ⚠️ **I-162** Se puede revisar antes de ejecutar.
- [x] ✅ **I-163** Una operación pesada ya activa impide empezar indebidamente el preflight.
- [x] ❌ **I-164** Cancelar el preflight funciona.
- [x] ✅ **I-165** Ejecutar edición secuencial funciona.

## Presets, favoritos e informes

- [x] ✅ **I-166** Crear/usar preset de lote.
- [x] ✅ **I-167** Restaurar preset.
- [x] ✅ **I-168** Favorito de configuración funciona.
- [x] ✅ **I-169** Favorito de reglas funciona.
- [x] ✅ **I-170** Exportar informe TXT.
- [x] ✅ **I-171** Exportar informe Markdown.
- [x] ✅ **I-172** Exportar informe JSON.
- [x] ✅ **I-173** El informe incluye la información técnica esperada.
- [x] ✅ **I-174** Exportar informe no lanza análisis nuevos inesperadamente.

## Compatibilidad/rendimiento

- [x] ✅ **I-175** Archivo largo no provoca un crecimiento absurdo de RAM.
- [x] ✅ **I-176** Vídeo 4K puede inspeccionarse/reproducirse dentro de límites razonables.
- [x] ✅ **I-177** HEVC.
- [x] ✅ **I-178** AV1 si el FFmpeg instalado lo soporta.
- [x] ✅ **I-179** VFR mantiene una timeline coherente.
- [x] ✅ **I-180** HDR se puede inspeccionar/previsualizar sin tratarlo como monitor HDR de referencia.

---

# 10. Limpiador

## Análisis general

- [x] ✅ **L-01** Pulsar «Analizar» inicia el análisis.
- [x] ✅ **L-02** Se ve claramente que está trabajando.
- [x] ✅ **L-03** Termina en un tiempo razonable.
- [x] ✅ **L-04** Ya no se queda eternamente en «Inventariando aplicaciones».
- [x] ✅ **L-05** Cancelar funciona.
- [x] ✅ **L-06** Después de cancelar vuelve a estado normal.
- [x] ✅ **L-07** Se puede volver a analizar después.

## Resumen

- [x] ✅ **L-08** Muestra cobertura.
- [x] ✅ **L-09** Muestra aplicaciones.
- [x] ✅ **L-10** Muestra candidatos.
- [x] ✅ **L-11** Muestra tamaño analizado.
- [x] ✅ **L-12** Muestra selección segura potencial.
- [ ] ➖ **L-13** Muestra ubicaciones sin acceso cuando existen.

## Aplicaciones

- [x] ✅ **L-14** Detecta apps de `/Applications`.
- [x] ✅ **L-15** Detecta apps de `~/Applications` si existen.
- [x] ✅ **L-16** Buscar una aplicación funciona.
- [x] ✅ **L-17** Muestra nombre/ubicación correctamente.
- [x] ✅ **L-18** Arrastrar una `.app` abre su análisis de desinstalación.
- [x] ✅ **L-19** «Analizar desinstalación» no elimina nada.
- [x] ✅ **L-20** Detecta asociados razonables de la app.
- [x] ✅ **L-21** Datos persistentes aparecen pero no preseleccionados.
- [x] ✅ **L-22** Si existe un desinstalador oficial, se ofrece.
- [x] ✅ **L-23** Una app abierta recibe el tratamiento previsto antes de intentar retirarla.

## Residuos y selección segura

- [x] ✅ **L-24** Muestra residuos probables.
- [x] ✅ **L-25** Muestra asociaciones inciertas sin tratarlas como seguras.
- [x] ✅ **L-26** Cachés regenerables elegibles pueden preseleccionarse.
- [x] ✅ **L-27** Logs regenerables elegibles pueden preseleccionarse.
- [x] ✅ **L-28** Preferences no se autoseleccionan.
- [x] ✅ **L-29** Application Support no se autoselecciona.
- [x] ✅ **L-30** Containers no se autoseleccionan.
- [x] ✅ **L-31** Group Containers no se autoseleccionan.
- [x] ✅ **L-32** «Conservar» desmarca inmediatamente el elemento.
- [x] ✅ **L-33** «Conservar» impide volver a seleccionarlo indebidamente.
- [x] ✅ **L-34** La decisión sigue presente tras volver a analizar.

## Desinstalación

- [x] ✅ **L-35** Seleccionar la `.app` funciona.
- [x] ✅ **L-36** «Seleccionar elementos seguros» mantiene seleccionada la `.app`.
- [x] ✅ **L-37** Solo añade asociados regenerables seguros.
- [x] ✅ **L-38** Desmarcar la `.app` desmarca sus asociados.
- [x] ✅ **L-39** No se pueden volver a seleccionar asociados de esa desinstalación mientras la app esté desmarcada.
- [x] ✅ **L-40** Antes de ejecutar aparece confirmación.
- [x] ✅ **L-41** La confirmación muestra cantidad.
- [x] ✅ **L-42** Muestra tamaño.
- [x] ✅ **L-43** Muestra rutas.
- [x] ✅ **L-44** Muestra modo de retirada.

## Papelera

Usar únicamente elementos que se puedan perder.

- [x] ✅ **L-45** «Mover a Papelera» funciona.
- [x] ✅ **L-46** El elemento termina realmente en la Papelera.
- [x] ✅ **L-47** Resultado distingue retirados/omitidos/fallidos.
- [x] ✅ **L-48** Después de limpiar renueva el análisis.
- [x] ✅ **L-49** Después de limpiar la selección queda vacía.
- [x] ✅ **L-50** «Deshacer» aparece solo si hubo movimientos recuperables.
- [x] ✅ **L-51** Deshacer restaura correctamente.
- [x] ✅ **L-52** No sobrescribe una ruta original que ahora esté ocupada.
- [x] ✅ **L-53** Un Undo parcial mantiene pendientes los elementos que todavía podrían restaurarse.

## Borrado permanente

Con un elemento completamente prescindible:

- [ ] ➖ **L-54** Borrado permanente no está seleccionado por defecto.
- [ ] ➖ **L-55** Requiere confirmación.
- [ ] ➖ **L-56** Elimina el elemento.
- [ ] ➖ **L-57** No ofrece Undo.

## Xcode

Si Xcode está instalado:

- [x] ✅ **L-58** Detecta datos regenerables correspondientes.
- [x] ✅ **L-59** DerivedData/índices elegibles se clasifican correctamente.
- [x] ✅ **L-60** Xcode Archives no se trata como caché normal autoseleccionable.

## Instaladores

- [x] ✅ **L-61** Detecta `.dmg` antiguos.
- [x] ✅ **L-62** Detecta `.pkg` antiguos.
- [x] ✅ **L-63** Detecta `.xip` antiguos.
- [x] ✅ **L-64** No considera automáticamente «seguro borrar» algo solo porque sea antiguo.
- [ ] ➖ **L-65** Una misma ubicación añadida por rutas solapadas no genera candidatos duplicados.

## Espacio

- [x] ✅ **L-66** Explorador de Espacio abre.
- [x] ✅ **L-67** Calcula tamaños.
- [x] ✅ **L-68** La navegación jerárquica funciona.
- [x] ✅ **L-69** No sigue symlinks.
- [x] ✅ **L-70** El filtro de tamaño funciona.
- [x] ✅ **L-71** Distingue «sin resultados por filtro» de «carpeta no analizada».

## Persistencia

- [ ] ➖ **L-72** Reiniciar ZEUVE conserva inventario/histórico necesario.
- [ ] ➖ **L-73** Reiniciar conserva decisiones «Conservar».
- [ ] ➖ **L-74** Undo pendiente sigue apareciendo cuando todavía es verificable.
- [ ] ➖ **L-75** Restaurar ajustes del Limpiador no borra indebidamente inventario/Undo/decisiones que deban conservarse.

---

# 11. Privacidad y seguridad transversal

- [ ] ➖ **P-01** Organizador funciona sin Internet.
- [ ] ➖ **P-02** Analizador de chats funciona sin Internet.
- [ ] ➖ **P-03** Conversor funciona sin Internet.
- [ ] ➖ **P-04** Comparador funciona sin Internet.
- [ ] ➖ **P-05** Inspector funciona sin Internet.
- [ ] ➖ **P-06** Limpiador funciona sin Internet.
- [ ] ➖ **P-07** Solo el Descargador necesita Internet para su trabajo normal.
- [ ] ➖ **P-08** Un archivo original convertido permanece intacto.
- [ ] ➖ **P-09** Un archivo original inspeccionado/editado permanece intacto.
- [ ] ➖ **P-10** Ningún conflicto normal sobrescribe silenciosamente un archivo existente.
- [ ] ➖ **P-11** Después de utilizar una sesión de Instagram, los registros no muestran cookies.
- [ ] ➖ **P-12** Los registros no muestran tokens/credenciales.
- [x] ✅ **P-13** Analizar chats no deja mensajes completos en Historial.
- [x] ✅ **P-14** Comparar seguidores no deja usernames/listas en Historial.
- [ ] ➖ **P-15** OCR del Inspector no deja el texto OCR completo en Historial.
- [ ] ➖ **P-16** Cancelar operaciones no deja ZEUVE permanentemente bloqueado.
