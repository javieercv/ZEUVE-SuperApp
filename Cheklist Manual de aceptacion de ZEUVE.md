# CHECKLIST MANUAL DE ACEPTACIÓN DE ZEUVE

Estado acumulado al 29/09/2026 · ZEUVE 0.20.5.0 (marketing 0.20.5, build 71).

**639 pruebas: 295 ✅ OK · 6 ❌ fallidas · 5 ⚠️ parciales · 333 ➖ pendientes.** Ninguna marcada como no aplicable.

Leyenda: ✅ aceptación comprobada; ❌ fallo observado; ⚠️ aceptación parcial; ➖ todavía no validada. Una casilla marcada indica prueba ejecutada con resultado concluyente; el símbolo distingue OK de fallo. Los parciales y pendientes conservan casilla vacía. Los resultados de QA se realizaron sobre una copia Debug con datos aislados y archivos sintéticos; no certifican toda la distribución Release ni cualquier entrada posible.

Confirmación manual del usuario, 28/09/2026: **O-02, A-07, A-39 y A-46–A-48 funcionan**. Estos seis puntos se marcan OK por su confirmación, no como pruebas repetidas por el agente.

Resumen: General 40/40 OK; Historial 15/15 OK; Ajustes 17/18 OK y S-16 fallido; Organizador 49/50 OK y O-18 parcial; Descargador 44/80 OK, D-13 fallido, D-15/D-60 parciales y 33 pendientes; Analizador 75/75 OK. Conversor 53/63 OK, 4 fallos (C-14/C-15/C-20/C-46) y 2 parciales (C-11/C-48), Comparador 0/27, Inspector 0/180 y Limpiador 0/75 todavía sin su batería completa; Privacidad transversal 2/16 OK (P-13/P-14).

El Descargador continúa pausado por decisión del usuario para separar limitaciones de Internet de fallos de producto. Primer bloque del Conversor: 11 puntos OK (C-01–C-06, C-41, C-43, C-59, C-60 y C-63), con PNG/JPEG/HEIC/TIFF/BMP, dimensiones, carpeta, copia segura, originales, conflictos e Historial comprobados. Se decodificaron 23 archivos publicados; todas las salidas conservaron 320×180 y los cinco originales conservaron sus hashes. C-62 quedó después comprobado OK con la opción activada y un reinicio real; la prueba inicial con la opción desactivada no era un fallo. C-42 y C-45 no se dan por validados por haber completado un lote de carpeta. El avance posterior se registra prueba a prueba justo debajo. No se ha corregido producto.

## Continuidad de pruebas — guardado individual

Desde el 28/09/2026 se actualiza este archivo inmediatamente al terminar cada ID de prueba, antes de iniciar el siguiente. Los intentos incompletos no se marcan OK. Los problemas de control se anotan separados de los fallos de producto.

**Punto de continuación: F-01 — Comparador de seguidores de Instagram, todavía sin iniciar.** Conversor: 53 OK, 4 fallos (C-14/C-15/C-20/C-46), 2 parciales (C-11/C-48) y 4 pendientes (C-35–C-37 sin Pandoc; C-42 por control del selector múltiple). Última prueba guardada C-62, OK. UI QA en Conversor sin entradas ni operación activa, PID 39084; carpeta recordada output y favorita sintética conservadas en datos aislados. C-42: último intento de AXSelectedChildren no confirmó selección; panel cancelado, ninguna importación múltiple aceptada. Publicación remota pendiente por falta de autenticación HTTPS.

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

- [ ] ➖ **F-01** Importar ZIP completo funciona.
- [ ] ➖ **F-02** Drag & drop del ZIP funciona.
- [ ] ➖ **F-03** Detecta `following.json`.
- [ ] ➖ **F-04** Detecta uno o varios `followers_N.json`.
- [ ] ➖ **F-05** Acepta huecos en la numeración de followers.
- [ ] ➖ **F-06** Modo avanzado con JSON separados funciona.
- [ ] ➖ **F-07** Archivos duplicados se rechazan.
- [ ] ➖ **F-08** Un JSON malformado da error comprensible.
- [ ] ➖ **F-09** Un JSON válido pero de estructura incorrecta da un error distinto.
- [ ] ➖ **F-10** El análisis no comienza hasta pulsar «Analizar exportación».
- [ ] ➖ **F-11** Total de seguidores es correcto.
- [ ] ➖ **F-12** Total de seguidos es correcto.
- [ ] ➖ **F-13** «Sigo pero no me siguen» es correcto.
- [ ] ➖ **F-14** «Me siguen pero no sigo» es correcto.
- [ ] ➖ **F-15** «Seguimiento mutuo» es correcto.
- [ ] ➖ **F-16** Búsqueda parcial funciona.
- [ ] ➖ **F-17** Orden A–Z funciona.
- [ ] ➖ **F-18** Orden Z–A funciona.
- [ ] ➖ **F-19** Un resultado vacío se presenta correctamente.
- [ ] ➖ **F-20** «Abrir en Instagram» abre manualmente el perfil.
- [ ] ➖ **F-21** Exportar categoría a TXT.
- [ ] ➖ **F-22** Exportar categoría a CSV.
- [ ] ➖ **F-23** Exportar solo resultados visibles tras búsqueda.
- [ ] ➖ **F-24** El reemplazo de una exportación existente exige confirmación de macOS.
- [ ] ➖ **F-25** Cancelar análisis funciona.
- [ ] ➖ **F-26** El análisis aparece en Historial.
- [ ] ➖ **F-27** Funciona sin iniciar sesión en Instagram.

---

# 9. Inspector multimedia

## Apertura e inspección

- [ ] ➖ **I-01** Abrir archivo con selector.
- [ ] ➖ **I-02** Arrastrar archivo.
- [ ] ➖ **I-03** MKV.
- [ ] ➖ **I-04** MP4.
- [ ] ➖ **I-05** MOV.
- [ ] ➖ **I-06** WebM.
- [ ] ➖ **I-07** Muestra contenedor/formato.
- [ ] ➖ **I-08** Muestra duración.
- [ ] ➖ **I-09** Muestra streams de vídeo.
- [ ] ➖ **I-10** Muestra streams de audio.
- [ ] ➖ **I-11** Muestra subtítulos.
- [ ] ➖ **I-12** Muestra capítulos.
- [ ] ➖ **I-13** Muestra metadata.
- [ ] ➖ **I-14** Muestra attachments.
- [ ] ➖ **I-15** Muestra carátulas/`attached_pic` cuando existen.
- [ ] ➖ **I-16** Abrir otro archivo limpia correctamente el estado anterior.
- [ ] ➖ **I-17** Cerrar archivo limpia correctamente la sesión.
- [ ] ➖ **I-18** Si existe un borrador con cambios pide confirmación antes de descartarlo.

## Preview de audio

- [ ] ➖ **I-19** Play.
- [ ] ➖ **I-20** Pausa responde inmediatamente.
- [ ] ➖ **I-21** Reanudar responde inmediatamente.
- [ ] ➖ **I-22** Seek con la timeline.
- [ ] ➖ **I-23** Seek hacia delante.
- [ ] ➖ **I-24** Seek hacia atrás.
- [ ] ➖ **I-25** Cambiar velocidad.
- [ ] ➖ **I-26** 0,5× funciona.
- [ ] ➖ **I-27** 1× funciona.
- [ ] ➖ **I-28** 2× funciona.
- [ ] ➖ **I-29** Volumen funciona.
- [ ] ➖ **I-30** Cambiar pista de audio conserva el instante.
- [ ] ➖ **I-31** Cambiar pista mientras reproduce conserva Play.
- [ ] ➖ **I-32** Cambiar pista estando pausado conserva Pausa.
- [ ] ➖ **I-33** Ninguna acción habitual se siente con el retraso de \~1 segundo que se corrigió.

## Preview de vídeo

- [ ] ➖ **I-34** El vídeo se reproduce.
- [ ] ➖ **I-35** Vídeo y audio están sincronizados.
- [ ] ➖ **I-36** Pausar conserva el frame.
- [ ] ➖ **I-37** Reanudar no reinicia desde cero.
- [ ] ➖ **I-38** Seek de vídeo funciona.
- [ ] ➖ **I-39** Cambiar pista de audio durante vídeo conserva posición.
- [ ] ➖ **I-40** Cambiar stream de vídeo conserva posición.
- [ ] ➖ **I-41** El cambio de stream no reproduce accidentalmente otro stream con el mismo índice de otra fuente.
- [ ] ➖ **I-42** Fullscreen entra correctamente.
- [ ] ➖ **I-43** Fullscreen sale correctamente.
- [ ] ➖ **I-44** Escalado de vídeo es correcto.
- [ ] ➖ **I-45** Aspect ratio se conserva.

## Subtítulos de preview

- [ ] ➖ **I-46** Activar subtítulos SRT internos.
- [ ] ➖ **I-47** Activar ASS/SSA.
- [ ] ➖ **I-48** Los textos aparecen sincronizados.
- [ ] ➖ **I-49** Cambiar pista de subtítulos funciona.
- [ ] ➖ **I-50** Desactivar subtítulos funciona.
- [ ] ➖ **I-51** Seek actualiza correctamente el subtítulo visible.

## Waveform/timeline

- [ ] ➖ **I-52** Se genera waveform.
- [ ] ➖ **I-53** Scrub sobre waveform mueve el playhead.
- [ ] ➖ **I-54** Playhead de waveform y reproductor coincide.
- [ ] ➖ **I-55** Zoom funciona.
- [ ] ➖ **I-56** Pan funciona.
- [ ] ➖ **I-57** Capítulos aparecen en timeline cuando corresponde.
- [ ] ➖ **I-58** Overlays de análisis aparecen cuando están activados.

## Espectrograma

- [ ] ➖ **I-59** Generar espectrograma.
- [ ] ➖ **I-60** El resultado corresponde a la pista elegida.
- [ ] ➖ **I-61** El playhead coincide con reproductor/waveform.
- [ ] ➖ **I-62** Pulsar/scrub en espectrograma hace seek correctamente.
- [ ] ➖ **I-63** Zoom/pan funciona.
- [ ] ➖ **I-64** Cambiar parámetros visuales reutilizables no vuelve a decodificar innecesariamente.
- [ ] ➖ **I-65** Exportar espectrograma funciona.
- [ ] ➖ **I-66** La barra inferior/reproductor sigue visible.

## Sonoridad y señal

- [ ] ➖ **I-67** Integrated Loudness / LUFS.
- [ ] ➖ **I-68** LRA.
- [ ] ➖ **I-69** True Peak.
- [ ] ➖ **I-70** Sample Peak.
- [ ] ➖ **I-71** Timeline de sonoridad.
- [ ] ➖ **I-72** Detección de silencios.
- [ ] ➖ **I-73** Detección de posible clipping.
- [ ] ➖ **I-74** Eventos aparecen en timeline.
- [ ] ➖ **I-75** Con una sola pista se ejecuta correctamente la automatización configurada.
- [ ] ➖ **I-76** Con varias pistas no selecciona silenciosamente una pista para análisis pesado.

## A/B

- [ ] ➖ **I-77** Elegir pista A.
- [ ] ➖ **I-78** Elegir pista B.
- [ ] ➖ **I-79** Alternar A/B conserva timestamp.
- [ ] ➖ **I-80** Alternar A/B conserva Play/Pausa.
- [ ] ➖ **I-81** A/B no cambia silenciosamente la pista seleccionada para espectrograma.
- [ ] ➖ **I-82** «Completar análisis A/B» funciona.

## Fuente con pérdida y anomalías

- [ ] ➖ **I-83** Análisis de indicios de fuente con pérdida termina.
- [ ] ➖ **I-84** Presenta nivel de evidencia comprensible.
- [ ] ➖ **I-85** Muestra métricas/evidencias.
- [ ] ➖ **I-86** No afirma automáticamente «fake lossless» basándose solo en un cutoff.
- [ ] ➖ **I-87** Detección de anomalías espectrales funciona.
- [ ] ➖ **I-88** Las anomalías tienen localización temporal.
- [ ] ➖ **I-89** Aparecen correctamente en timeline.

## OCR bitmap

Con un archivo que tenga PGS compatible:

- [ ] ➖ **I-90** Detecta la pista bitmap.
- [ ] ➖ **I-91** Inicia OCR.
- [ ] ➖ **I-92** Puede cancelarse.
- [ ] ➖ **I-93** Produce borrador revisable.
- [ ] ➖ **I-94** Muestra confianza/idioma cuando corresponda.
- [ ] ➖ **I-95** Permite revisar/corregir el texto.
- [ ] ➖ **I-96** Exportar SRT funciona.
- [ ] ➖ **I-97** No sustituye automáticamente el subtítulo original.

## Edición de streams

Usar siempre una copia prescindible.

- [ ] ➖ **I-98** Entrar en modo edición.
- [ ] ➖ **I-99** Eliminar vídeo cuando la estructura resultante sea válida.
- [ ] ➖ **I-100** Eliminar pista de audio.
- [ ] ➖ **I-101** Eliminar subtítulo.
- [ ] ➖ **I-102** Añadir audio externo compatible.
- [ ] ➖ **I-103** Añadir subtítulo externo compatible.
- [ ] ➖ **I-104** Añadir vídeo externo compatible cuando proceda.
- [ ] ➖ **I-105** Reordenar vídeo.
- [ ] ➖ **I-106** Reordenar audio.
- [ ] ➖ **I-107** Reordenar subtítulos.
- [ ] ➖ **I-108** Cambiar título.
- [ ] ➖ **I-109** Cambiar idioma.
- [ ] ➖ **I-110** Cambiar default/disposition.
- [ ] ➖ **I-111** Elegir stream principal cuando el contenedor lo permita.
- [ ] ➖ **I-112** Undo del borrador funciona.
- [ ] ➖ **I-113** Redo del borrador funciona.

## Capítulos

- [ ] ➖ **I-114** Añadir capítulo.
- [ ] ➖ **I-115** Eliminar capítulo.
- [ ] ➖ **I-116** Renombrar capítulo.
- [ ] ➖ **I-117** Cambiar su posición temporal.
- [ ] ➖ **I-118** Timeline refleja cambios antes de ejecutar.

## Metadata

- [ ] ➖ **I-119** Editar tag permitido.
- [ ] ➖ **I-120** Editar metadata de stream permitida.
- [ ] ➖ **I-121** Tags desconocidos siguen visibles.
- [ ] ➖ **I-122** No convierte indiscriminadamente cualquier tag en editable.

## Attachments

- [ ] ➖ **I-123** Visualizar attachment.
- [ ] ➖ **I-124** Extraer attachment.
- [ ] ➖ **I-125** Eliminar attachment.
- [ ] ➖ **I-126** Añadir attachment externo compatible.
- [ ] ➖ **I-127** Editar nombre/MIME cuando corresponda.

## Carátulas

- [ ] ➖ **I-128** Visualizar carátula.
- [ ] ➖ **I-129** Extraer carátula.
- [ ] ➖ **I-130** Añadir carátula.
- [ ] ➖ **I-131** Sustituir carátula.
- [ ] ➖ **I-132** Eliminar carátula.
- [ ] ➖ **I-133** Resultado correcto en MKV.
- [ ] ➖ **I-134** Resultado correcto en MP4/MOV compatible.

## Ejecutar edición

- [ ] ➖ **I-135** Antes de ejecutar se puede revisar el plan.
- [ ] ➖ **I-136** Ejecutar genera un archivo nuevo.
- [ ] ➖ **I-137** El original permanece intacto.
- [ ] ➖ **I-138** El resultado contiene exactamente los streams previstos.
- [ ] ➖ **I-139** Audio/vídeo se mantienen por stream copy.
- [ ] ➖ **I-140** Una operación que necesitaría transcode audiovisual es rechazada, no recodificada a escondidas.
- [ ] ➖ **I-141** Conflicto de nombre no sobrescribe silenciosamente.
- [ ] ➖ **I-142** Cancelar edición funciona.
- [ ] ➖ **I-143** El archivo final abre correctamente después de la validación.

## Lotes

- [ ] ➖ **I-144** Seleccionar varios archivos.
- [ ] ➖ **I-145** Añadir carpeta.
- [ ] ➖ **I-146** Recorrer subcarpetas.
- [ ] ➖ **I-147** Controlar profundidad.
- [ ] ➖ **I-148** Incluir/excluir ocultos.
- [ ] ➖ **I-149** Aplicar filtros.
- [ ] ➖ **I-150** No seguir symlinks.
- [ ] ➖ **I-151** Deduplicar entradas.
- [ ] ➖ **I-152** Lote de inspección.
- [ ] ➖ **I-153** Lote de señal.
- [ ] ➖ **I-154** Lote de sonoridad.
- [ ] ➖ **I-155** Lote de espectrogramas.
- [ ] ➖ **I-156** Lote de informes.
- [ ] ➖ **I-157** Un archivo incompatible no detiene los demás.
- [ ] ➖ **I-158** Cancelar lote conserva únicamente resultados ya publicados correctamente.

## Reglas de edición por lotes

- [ ] ➖ **I-159** Crear conjunto de reglas.
- [ ] ➖ **I-160** Condición → acción funciona.
- [ ] ➖ **I-161** Preflight muestra qué ocurrirá.
- [ ] ➖ **I-162** Se puede revisar antes de ejecutar.
- [ ] ➖ **I-163** Una operación pesada ya activa impide empezar indebidamente el preflight.
- [ ] ➖ **I-164** Cancelar el preflight funciona.
- [ ] ➖ **I-165** Ejecutar edición secuencial funciona.

## Presets, favoritos e informes

- [ ] ➖ **I-166** Crear/usar preset de lote.
- [ ] ➖ **I-167** Restaurar preset.
- [ ] ➖ **I-168** Favorito de configuración funciona.
- [ ] ➖ **I-169** Favorito de reglas funciona.
- [ ] ➖ **I-170** Exportar informe TXT.
- [ ] ➖ **I-171** Exportar informe Markdown.
- [ ] ➖ **I-172** Exportar informe JSON.
- [ ] ➖ **I-173** El informe incluye la información técnica esperada.
- [ ] ➖ **I-174** Exportar informe no lanza análisis nuevos inesperadamente.

## Compatibilidad/rendimiento

- [ ] ➖ **I-175** Archivo largo no provoca un crecimiento absurdo de RAM.
- [ ] ➖ **I-176** Vídeo 4K puede inspeccionarse/reproducirse dentro de límites razonables.
- [ ] ➖ **I-177** HEVC.
- [ ] ➖ **I-178** AV1 si el FFmpeg instalado lo soporta.
- [ ] ➖ **I-179** VFR mantiene una timeline coherente.
- [ ] ➖ **I-180** HDR se puede inspeccionar/previsualizar sin tratarlo como monitor HDR de referencia.

---

# 10. Limpiador

## Análisis general

- [ ] ➖ **L-01** Pulsar «Analizar» inicia el análisis.
- [ ] ➖ **L-02** Se ve claramente que está trabajando.
- [ ] ➖ **L-03** Termina en un tiempo razonable.
- [ ] ➖ **L-04** Ya no se queda eternamente en «Inventariando aplicaciones».
- [ ] ➖ **L-05** Cancelar funciona.
- [ ] ➖ **L-06** Después de cancelar vuelve a estado normal.
- [ ] ➖ **L-07** Se puede volver a analizar después.

## Resumen

- [ ] ➖ **L-08** Muestra cobertura.
- [ ] ➖ **L-09** Muestra aplicaciones.
- [ ] ➖ **L-10** Muestra candidatos.
- [ ] ➖ **L-11** Muestra tamaño analizado.
- [ ] ➖ **L-12** Muestra selección segura potencial.
- [ ] ➖ **L-13** Muestra ubicaciones sin acceso cuando existen.

## Aplicaciones

- [ ] ➖ **L-14** Detecta apps de `/Applications`.
- [ ] ➖ **L-15** Detecta apps de `~/Applications` si existen.
- [ ] ➖ **L-16** Buscar una aplicación funciona.
- [ ] ➖ **L-17** Muestra nombre/ubicación correctamente.
- [ ] ➖ **L-18** Arrastrar una `.app` abre su análisis de desinstalación.
- [ ] ➖ **L-19** «Analizar desinstalación» no elimina nada.
- [ ] ➖ **L-20** Detecta asociados razonables de la app.
- [ ] ➖ **L-21** Datos persistentes aparecen pero no preseleccionados.
- [ ] ➖ **L-22** Si existe un desinstalador oficial, se ofrece.
- [ ] ➖ **L-23** Una app abierta recibe el tratamiento previsto antes de intentar retirarla.

## Residuos y selección segura

- [ ] ➖ **L-24** Muestra residuos probables.
- [ ] ➖ **L-25** Muestra asociaciones inciertas sin tratarlas como seguras.
- [ ] ➖ **L-26** Cachés regenerables elegibles pueden preseleccionarse.
- [ ] ➖ **L-27** Logs regenerables elegibles pueden preseleccionarse.
- [ ] ➖ **L-28** Preferences no se autoseleccionan.
- [ ] ➖ **L-29** Application Support no se autoselecciona.
- [ ] ➖ **L-30** Containers no se autoseleccionan.
- [ ] ➖ **L-31** Group Containers no se autoseleccionan.
- [ ] ➖ **L-32** «Conservar» desmarca inmediatamente el elemento.
- [ ] ➖ **L-33** «Conservar» impide volver a seleccionarlo indebidamente.
- [ ] ➖ **L-34** La decisión sigue presente tras volver a analizar.

## Desinstalación

- [ ] ➖ **L-35** Seleccionar la `.app` funciona.
- [ ] ➖ **L-36** «Seleccionar elementos seguros» mantiene seleccionada la `.app`.
- [ ] ➖ **L-37** Solo añade asociados regenerables seguros.
- [ ] ➖ **L-38** Desmarcar la `.app` desmarca sus asociados.
- [ ] ➖ **L-39** No se pueden volver a seleccionar asociados de esa desinstalación mientras la app esté desmarcada.
- [ ] ➖ **L-40** Antes de ejecutar aparece confirmación.
- [ ] ➖ **L-41** La confirmación muestra cantidad.
- [ ] ➖ **L-42** Muestra tamaño.
- [ ] ➖ **L-43** Muestra rutas.
- [ ] ➖ **L-44** Muestra modo de retirada.

## Papelera

Usar únicamente elementos que se puedan perder.

- [ ] ➖ **L-45** «Mover a Papelera» funciona.
- [ ] ➖ **L-46** El elemento termina realmente en la Papelera.
- [ ] ➖ **L-47** Resultado distingue retirados/omitidos/fallidos.
- [ ] ➖ **L-48** Después de limpiar renueva el análisis.
- [ ] ➖ **L-49** Después de limpiar la selección queda vacía.
- [ ] ➖ **L-50** «Deshacer» aparece solo si hubo movimientos recuperables.
- [ ] ➖ **L-51** Deshacer restaura correctamente.
- [ ] ➖ **L-52** No sobrescribe una ruta original que ahora esté ocupada.
- [ ] ➖ **L-53** Un Undo parcial mantiene pendientes los elementos que todavía podrían restaurarse.

## Borrado permanente

Con un elemento completamente prescindible:

- [ ] ➖ **L-54** Borrado permanente no está seleccionado por defecto.
- [ ] ➖ **L-55** Requiere confirmación.
- [ ] ➖ **L-56** Elimina el elemento.
- [ ] ➖ **L-57** No ofrece Undo.

## Xcode

Si Xcode está instalado:

- [ ] ➖ **L-58** Detecta datos regenerables correspondientes.
- [ ] ➖ **L-59** DerivedData/índices elegibles se clasifican correctamente.
- [ ] ➖ **L-60** Xcode Archives no se trata como caché normal autoseleccionable.

## Instaladores

- [ ] ➖ **L-61** Detecta `.dmg` antiguos.
- [ ] ➖ **L-62** Detecta `.pkg` antiguos.
- [ ] ➖ **L-63** Detecta `.xip` antiguos.
- [ ] ➖ **L-64** No considera automáticamente «seguro borrar» algo solo porque sea antiguo.
- [ ] ➖ **L-65** Una misma ubicación añadida por rutas solapadas no genera candidatos duplicados.

## Espacio

- [ ] ➖ **L-66** Explorador de Espacio abre.
- [ ] ➖ **L-67** Calcula tamaños.
- [ ] ➖ **L-68** La navegación jerárquica funciona.
- [ ] ➖ **L-69** No sigue symlinks.
- [ ] ➖ **L-70** El filtro de tamaño funciona.
- [ ] ➖ **L-71** Distingue «sin resultados por filtro» de «carpeta no analizada».

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
