# Conversor universal 0.3.0 — ZEUVE 0.20.5.0

## Identidad

- Identificador: `com.zeuve.universal-converter`.
- Versión del módulo: `0.3.0`.
- ZEUVE mínimo declarado: `0.7.0`.
- Funcionamiento local; no declara acceso de red.

## Alcance

El Conversor procesa localmente imágenes rasterizadas y vectoriales compatibles, animaciones, audio, vídeo, PDF, texto, marcado, datos CSV/JSON/XML, carpetas y ZIP. Pandoc se conserva para conversiones entre TXT, Markdown y HTML.

ZEUVE 0.11.0 elimina completamente Calibre y Ghostscript. Por tanto, el Conversor ya no admite conversiones de libros electrónicos ni de EPS. Los formatos EPUB, MOBI, AZW/AZW3, FB2 y EPS siguen reconociéndose para mostrar un rechazo claro y evitar que se interpreten como archivos genéricos. El Organizador conserva su clasificación de ebooks.

Tampoco se admiten como entrada ni salida los formatos ofimáticos retirados en 0.7.3:

- Word: `.doc` y `.docx`;
- Excel: `.xls` y `.xlsx`;
- PowerPoint: `.ppt` y `.pptx`;
- OpenDocument: `.odt`, `.ods` y `.odp`;
- RTF: `.rtf`.

CSV permanece disponible como formato de datos y no depende de Excel ni de LibreOffice.

## Operaciones implementadas

- Imágenes: PNG, JPEG, HEIC, TIFF y BMP mediante ImageIO.
- Animaciones: GIF, WebP y APNG mediante FFmpeg cuando sus capacidades están presentes.
- Audio: MP3, M4A/AAC, FLAC, WAV, Opus y OGG.
- Vídeo: MP4, MOV, MKV, WebM y AVI como entrada; salidas según compatibilidad real.
- Vídeo a audio, audio a vídeo, fotogramas, animaciones y secuencias de imágenes.
- Imágenes a PDF, PDF a imágenes y PDF a texto.
- TXT, Markdown y HTML mediante Pandoc según la pareja admitida.
- CSV, JSON y XML como datos reconocidos; una operación al mismo formato puede publicarse mediante copia segura.

SVG se conserva como imagen vectorial, pero no se ofrece una ruta dependiente de LibreOffice. EPS se reconoce y se rechaza como no compatible.

## Motores

`ConverterCompatibilityRegistry` solo ofrece rutas cuya disponibilidad está confirmada. Los motores externos base del Conversor son FFmpeg/FFprobe. Pandoc continúa soportado como motor opcional cuando la preparación vigente lo incorpora. ImageIO y PDFKit son capacidades nativas del sistema.

Calibre y Ghostscript no figuran en `engines.json`, no se localizan en ejecución, no se descargan en la preparación y no se firman ni empaquetan.

## Seguridad y archivos

- Sin shell ni argumentos concatenados.
- Procesos iniciados mediante `posix_spawn` en grupos propios.
- Contraseñas únicamente en memoria para ZIP y PDF compatibles.
- Los originales se abren en lectura y nunca se sustituyen sin autorización.
- Los resultados normales se generan en temporales, se validan y se publican de forma segura.
- Vídeo a fotogramas usa una carpeta visible controlada en el destino para evitar una copia completa final y conserva resultados incompletos según la decisión aprobada.
- Los formatos retirados dentro de un ZIP se rechazan y no se extraen para convertirlos.

## CSV

CSV se mantiene como formato genérico de datos:

- se detecta por extensión o estructura textual;
- puede incluirse en escaneos de archivos, carpetas y ZIP;
- se conserva en las enumeraciones y categorías del Conversor;
- continúa utilizándose para el archivo opcional `tiempos.csv` de extracción de fotogramas.

## Limitaciones

- Sin conversión de EPUB, MOBI, AZW/AZW3 o FB2.
- Sin conversión de EPS o PostScript.
- Sin soporte ofimático ni PDF a documento editable.
- Sin OCR.
- La reordenación manual de secuencias de imágenes no está implementada.
- La experiencia SwiftUI/AppKit, ImageIO, PDFKit, VideoToolbox, firma y apertura de la aplicación requieren validación final en macOS Apple Silicon.

## Conversión real de vídeo y fotogramas

En modo simple, seleccionar una salida de vídeo implica recodificar la pista de vídeo. Para MP4 con códec automático se utiliza H.264 mediante libx264, manteniendo resolución y FPS originales salvo que el usuario los cambie. La opción de copia rápida sin recodificar solo aparece en modo avanzado y está desactivada por defecto.

La extracción crea inmediatamente en el destino una carpeta visible con sufijo `Procesando`. Al completar, la carpeta se renombra al nombre definitivo en el mismo volumen. Si se cancela o falla, ZEUVE valida el último fotograma, conserva los archivos completos y cambia el nombre a `Incompleto`. `tiempos.csv` se construye durante la misma ejecución de FFmpeg.

## Persistencia secundaria y carpetas recordadas

El Conversor reutiliza desde `ZEUVECore` la mecánica de bookmark y acceso `security-scoped`, pero mantiene su store, clave persistente, validación de carpeta y política de publicación. Si una conversión termina correctamente y falla únicamente el guardado del historial, los resultados siguen siendo válidos y se muestra un aviso; el fallo no convierte la conversión en fallida ni elimina resultados. El log correspondiente contiene solo el tipo técnico del error.

## Organización interna de fuentes — Fase 4

El antiguo archivo monolítico `UniversalConverterModels.swift` se sustituye por fuentes agrupadas por formatos, operaciones, ajustes, opciones de operación, presets, entradas, planificación, resultados y progreso. Los nombres y visibilidad pública de los modelos permanecen estables, así como las claves `Codable`, migraciones y archivos portables ya existentes.

`FFmpegProgressSupport.swift` contiene el recolector de diagnóstico y el monitor de progreso que antes residían al final de `UniversalConverterExecutionService.swift`. La extracción no cambia órdenes de FFmpeg, parsing de progreso, ejecución, validación, publicación, temporales ni cancelación.

`UniversalConverterViewModel` y el núcleo de `UniversalConverterExecutionService` se revisaron y se mantienen cohesionados: no se reparten responsabilidades estrechamente acopladas solo para reducir el tamaño de archivo.

## Integración FFprobe compartida — ZEUVE 0.13.0

Desde ZEUVE 0.13.0, el Conversor universal ya no mantiene un parser FFprobe propio. La inspección técnica necesaria para planificación y ejecución se obtiene mediante `ZEUVEEngines/MediaInspection`, compartida con Inspector multimedia.

La migración es deliberadamente no funcional: no cambia la interfaz del Conversor, sus formatos admitidos, códecs, presets, valores por defecto, planner, decisiones de remux/recodificación, publicación, historial, privacidad ni cancelación. El antiguo `MediaProbe.swift` se elimina únicamente después de migrar sus consumidores; las utilidades generales que no pertenecían a FFprobe permanecen separadas para conservar el comportamiento existente.

`MediaInspectionService` se limita a ejecutar FFprobe de forma segura y a transformar su JSON en un modelo técnico común. No conoce presets, UI ni decisiones de conversión. El Conversor sigue siendo el único responsable de decidir cuándo una operación requiere transformación audiovisual.
