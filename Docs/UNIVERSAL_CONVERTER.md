# Conversor universal — ZEUVE 0.7.5

## Alcance

El Conversor procesa localmente imágenes rasterizadas y vectoriales, animaciones, audio, vídeo, PDF, texto, marcado, datos CSV/JSON/XML, libros electrónicos, carpetas y ZIP. ZEUVE 0.7.3 elimina completamente LibreOffice y el soporte ofimático del Conversor.

No se admiten como entrada ni salida:

- Word: `.doc` y `.docx`;
- Excel: `.xls` y `.xlsx`;
- PowerPoint: `.ppt` y `.pptx`;
- OpenDocument: `.odt`, `.ods` y `.odp`;
- RTF: `.rtf`.

Estos archivos se rechazan con un mensaje claro y no se interpretan como ZIP genéricos. CSV permanece disponible como formato de datos y no depende de Excel ni de LibreOffice.

## Operaciones implementadas

- Imágenes: PNG, JPEG, HEIC, TIFF y BMP mediante ImageIO.
- Animaciones: GIF, WebP y APNG mediante FFmpeg cuando sus capacidades están presentes.
- Audio: MP3, M4A/AAC, FLAC, WAV, Opus y OGG.
- Vídeo: MP4, MOV, MKV, WebM y AVI como entrada; salidas según compatibilidad real.
- Vídeo a audio, audio a vídeo, fotogramas, animaciones y secuencias de imágenes.
- Imágenes a PDF, PDF a imágenes y PDF a texto.
- TXT, Markdown, HTML y EPUB mediante Pandoc según la pareja admitida.
- EPUB, MOBI, AZW3 y FB2 mediante Calibre.
- EPS a PDF o raster mediante Ghostscript.
- CSV, JSON y XML como datos reconocidos; una operación al mismo formato puede publicarse mediante copia segura.

SVG se conserva como imagen vectorial, pero la ruta SVG a PDF que dependía de LibreOffice ha sido retirada.

## Motores

`ConverterCompatibilityRegistry` solo ofrece rutas cuya disponibilidad está confirmada. Los motores externos actuales son FFmpeg/FFprobe, Pandoc, Calibre y Ghostscript. ImageIO y PDFKit son capacidades nativas del sistema.

LibreOffice no figura en `engines.json`, no se localiza en ejecución, no se descarga en la preparación y no se firma ni empaqueta.

## Seguridad y archivos

- Sin shell ni argumentos concatenados.
- Procesos iniciados mediante `posix_spawn` en grupos propios.
- Ghostscript usa modo seguro y recursos internos.
- Contraseñas únicamente en memoria para ZIP y PDF compatibles.
- Los originales se abren en lectura y nunca se sustituyen sin autorización.
- Los resultados normales se generan en temporales, se validan y se publican de forma segura. Vídeo → fotogramas usa una carpeta visible controlada en el destino para evitar una copia completa final y conserva resultados incompletos según la decisión aprobada.
- Los archivos ofimáticos dentro de un ZIP también se rechazan y no se extraen para convertirlos.

## CSV

CSV se mantiene como formato genérico de datos:

- se detecta por extensión o estructura textual;
- puede incluirse en escaneos de archivos, carpetas y ZIP;
- se conserva en las enumeraciones y categorías del Conversor;
- continúa utilizándose para el archivo opcional `tiempos.csv` de extracción de fotogramas.

No se ofrece conversión CSV ↔ Excel porque Excel ya no forma parte del Conversor.

## Limitaciones

- No existe soporte ofimático ni PDF a documento editable.
- No hay OCR.
- La reordenación manual de secuencias de imágenes no está implementada.
- La experiencia SwiftUI/AppKit, ImageIO, PDFKit, VideoToolbox, firma y apertura de la aplicación requieren validación final en macOS Apple Silicon.

## Optimización interna 0.7.4

El escáner de entradas permanece vivo durante la sesión del módulo y reutiliza resultados mientras no cambien archivos, contraseñas o límites estructurales. La ejecución calcula una sola vez las rutas canónicas de todos los originales protegidos y actualiza el progreso mediante estados incrementales agrupados, sin reducir las validaciones ni alterar la publicación atómica.


## Conversión real de vídeo y fotogramas 0.7.5

### Vídeo a MP4 y otros contenedores

En modo simple, seleccionar una salida de vídeo implica recodificar la pista de vídeo. Para MP4 con códec automático se utiliza H.264 mediante libx264, manteniendo resolución y FPS originales salvo que el usuario los cambie. La pista de audio puede conservarse sin recodificar cuando el contenedor la admite, porque esto no impide que la conversión de vídeo sea real.

La opción **Copia rápida sin recodificar el vídeo** solo aparece en modo avanzado y está desactivada por defecto. Cuando se activa y las pistas son compatibles, ZEUVE puede hacer remux; la vista previa lo identifica como copia rápida y la ayuda aclara que no reduce tamaño ni cambia calidad. Los ajustes almacenados por versiones anteriores migran al nuevo valor predeterminado; los preajustes personalizados se conservan sin alterarlos silenciosamente.

Tras una recodificación, FFprobe comprueba que existe una pista de vídeo y que el códec coincide con H.264, HEVC o ProRes según la elección. Una conversión real no garantiza un archivo menor: el tamaño depende del material original y del preajuste, y Máxima calidad prioriza fidelidad.

### Vídeo a fotogramas

La extracción crea inmediatamente en el destino una carpeta visible con sufijo `Procesando`. Los archivos aparecen dentro durante la operación. Al completar, la carpeta se renombra al nombre definitivo en el mismo volumen, evitando la antigua copia completa y la duplicación temporal de almacenamiento.

Si se cancela o falla, ZEUVE valida el último fotograma, conserva los archivos completos y cambia el nombre a `Incompleto`. `tiempos.csv` pasa a `tiempos_parcial.csv`. Si la aplicación o el Mac se cierran inesperadamente, el registro privado del workspace permite recuperar esa carpeta al iniciar el Conversor de nuevo.

PNG continúa siendo sin pérdida y utiliza nivel de compresión 3 con predictor Up. El CSV se construye durante la misma ejecución de FFmpeg a partir de `showinfo=checksum=0`, por lo que ya no requiere una segunda pasada completa de FFprobe. El progreso presenta fase, porcentaje cuando es fiable y número real de fotogramas generados.
