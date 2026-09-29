# CHECKLIST MANUAL DE ACEPTACIÓN DE ZEUVE

Estado acumulado al 29/09/2026 · ZEUVE 0.20.5.0 (marketing 0.20.5, build 71).

**639 pruebas: 366 ✅ OK · 6 ❌ fallidas · 5 ⚠️ parciales · 262 ➖ pendientes.** Ninguna marcada como no aplicable.

Leyenda: ✅ aceptación comprobada; ❌ fallo observado; ⚠️ aceptación parcial; ➖ todavía no validada. Una casilla marcada indica prueba ejecutada con resultado concluyente; el símbolo distingue OK de fallo. Los parciales y pendientes conservan casilla vacía. Los resultados de QA se realizaron sobre una copia Debug con datos aislados y archivos sintéticos; no certifican toda la distribución Release ni cualquier entrada posible.

Confirmación manual del usuario, 28/09/2026: **O-02, A-07, A-39 y A-46–A-48 funcionan**. Estos seis puntos se marcan OK por su confirmación, no como pruebas repetidas por el agente.

Resumen: General 40/40 OK; Historial 15/15 OK; Ajustes 17/18 OK y S-16 fallido; Organizador 49/50 OK y O-18 parcial; Descargador 44/80 OK, D-13 fallido, D-15/D-60 parciales y 33 pendientes; Analizador 75/75 OK. Conversor 53/63 OK, 4 fallos (C-14/C-15/C-20/C-46) y 2 parcial (C-11/C-48), Comparador 26/27 OK, Inspector 45/180 y Limpiador 0/75 todavía sin su batería completa; Privacidad transversal 2/16 OK (P-13/P-14).

El Descargador continúa pausado por decisión del usuario para separar limitaciones de Internet de fallos de producto. Primer bloque del Conversor: 11 puntos OK (C-01–C-06, C-41, C-43, C-59, C-60 y C-63), con PNG/JPEG/HEIC/TIFF/BMP, dimensiones, carpeta, copia segura, originales, conflictos e Historial comprobados. Se decodificaron 23 archivos publicados; todas las salidas conservaron 320×180 y los cinco originales conservaron sus hashes. C-62 quedó después comprobado OK con la opción activada y un reinicio real; la prueba inicial con la opción desactivada no era un fallo. C-42 y C-45 no se dan por validados por haber completado un lote de carpeta. El avance posterior se registra prueba a prueba justo debajo. No se ha corregido producto.

## Continuidad de pruebas — guardado individual

Desde el 28/09/2026 se actualiza este archivo inmediatamente al terminar cada ID de prueba, antes de iniciar el siguiente. Los intentos incompletos no se marcan OK. Los problemas de control se anotan separados de los fallos de producto.

**Punto de continuación: I-64 — cambios visuales sin decodificar.** Última prueba cerrada y guardada: I-63, ✅. La publicación remota sigue pendiente por falta de autenticación en GitHub; el guardado local no depende del push.

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
- [ ] ➖ **I-02** Arrastrar archivo.
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
- [ ] ➖ **I-22** Seek con la timeline.
- [x] ✅ **I-23** Seek hacia delante.
- [x] ✅ **I-24** Seek hacia atrás.
- [x] ✅ **I-25** Cambiar velocidad.
- [x] ✅ **I-26** 0,5× funciona.
- [x] ✅ **I-27** 1× funciona.
- [x] ✅ **I-28** 2× funciona.
- [ ] ➖ **I-29** Volumen funciona.
- [x] ✅ **I-30** Cambiar pista de audio conserva el instante.
- [x] ✅ **I-31** Cambiar pista mientras reproduce conserva Play.
- [x] ✅ **I-32** Cambiar pista estando pausado conserva Pausa.
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
- [x] ✅ **I-42** Fullscreen entra correctamente.
- [x] ✅ **I-43** Fullscreen sale correctamente.
- [ ] ➖ **I-44** Escalado de vídeo es correcto.
- [ ] ➖ **I-45** Aspect ratio se conserva.

## Subtítulos de preview

- [x] ✅ **I-46** Activar subtítulos SRT internos.
- [x] ✅ **I-47** Activar ASS/SSA.
- [x] ✅ **I-48** Los textos aparecen sincronizados.
- [x] ✅ **I-49** Cambiar pista de subtítulos funciona.
- [x] ✅ **I-50** Desactivar subtítulos funciona.
- [x] ✅ **I-51** Seek actualiza correctamente el subtítulo visible.

## Waveform/timeline

- [ ] ➖ **I-52** Se genera waveform.
- [ ] ➖ **I-53** Scrub sobre waveform mueve el playhead.
- [x] ✅ **I-54** Playhead de waveform y reproductor coincide.
- [x] ✅ **I-55** Zoom funciona.
- [x] ✅ **I-56** Pan funciona.
- [ ] ➖ **I-57** Capítulos aparecen en timeline cuando corresponde.
- [ ] ➖ **I-58** Overlays de análisis aparecen cuando están activados.

## Espectrograma

- [x] ✅ **I-59** Generar espectrograma.
- [x] ✅ **I-60** El resultado corresponde a la pista elegida.
- [ ] ➖ **I-61** El playhead coincide con reproductor/waveform.
- [ ] ➖ **I-62** Pulsar/scrub en espectrograma hace seek correctamente.
- [x] ✅ **I-63** Zoom/pan funciona.
- [ ] ➖ **I-64** Cambiar parámetros visuales reutilizables no vuelve a decodificar innecesariamente.
- [x] ✅ **I-65** Exportar espectrograma funciona.
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

- [x] ✅ **I-98** Entrar en modo edición.
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
