# Matriz de compatibilidad — Conversor 0.7.0

La fuente de verdad ejecutable es `ConverterCompatibilityRegistry`. Esta tabla resume las familias principales; una pareja solo aparece en la interfaz si el motor y las capacidades reales están disponibles.

| Entrada | Salidas principales | Operación | Motor | Observaciones |
|---|---|---|---|---|
| PNG, JPEG, HEIC, TIFF, BMP | PNG, JPEG, HEIC, TIFF, BMP | Convertir | ImageIO | Puede cambiar perfil, alfa o metadatos según el destino. |
| Imágenes rasterizadas | PDF | Imágenes a PDF | PDFKit | Conserva el orden seleccionado. |
| PDF | PNG, JPEG, TIFF, BMP | PDF a imágenes | PDFKit | Rasteriza; DPI configurable. |
| PDF | TXT | PDF a texto | PDFKit | No incluye OCR. |
| GIF, WebP, APNG | GIF, WebP, APNG | Convertir animación | FFmpeg | Solo si FFmpeg declara codificador y muxer. |
| GIF, WebP, APNG | MP4, MOV, MKV, WebM | Animación a vídeo | FFmpeg | Recodificación generacional. |
| MP4, MOV, MKV, WebM, AVI | GIF, WebP, APNG | Vídeo a animación | FFmpeg | FPS, escala y calidad configurables. |
| Audio compatible | MP3, M4A/AAC, FLAC, WAV, Opus, OGG | Convertir | FFmpeg | Copia directa cuando el códec y contenedor lo permiten. |
| Vídeo compatible | MP4, MOV, MKV, WebM | Convertir/remux | FFmpeg | H.264 software mediante libx264; VideoToolbox solo cuando se elige y es compatible. |
| Vídeo | Audio | Extraer audio | FFmpeg | Selección de pista y stream copy compatible. |
| Audio | MP4, MOV, MKV | Audio a vídeo | FFmpeg | Fondo negro o imagen; sin forma de onda. |
| Imágenes | MP4, MOV, MKV, WebM | Secuencia a vídeo | FFmpeg | Orden natural; sin audio adicional en 0.7.0. |
| DOC, DOCX, ODT, RTF | DOCX, ODT, RTF, TXT, PDF | Convertir documento | LibreOffice | Puede perder macros, fuentes, comentarios y objetos. |
| XLS, XLSX, ODS, CSV | XLSX, ODS, CSV, PDF | Convertir hoja | LibreOffice | No se ofrecen cruces a Word o PowerPoint. |
| PPT, PPTX, ODP | PPTX, ODP, PDF | Convertir presentación | LibreOffice | Puede perder animaciones, transiciones y fuentes. |
| TXT, Markdown, HTML, RTF, DOCX, ODT | TXT, Markdown, HTML, RTF, DOCX, ODT, EPUB | Texto y marcado | Pandoc | La fidelidad depende del formato de origen y destino. |
| EPUB, MOBI, AZW3, FB2 | EPUB, MOBI, AZW3, FB2, HTML, TXT, PDF | Ebook | Calibre | Puede cambiar maquetación, fuentes y metadatos. |
| SVG | PDF | Vectorial | LibreOffice | Puede conservar vector; filtros y fuentes pueden variar. |
| EPS | PDF, PNG, JPEG, TIFF, BMP | Vectorial/raster | Ghostscript | PDF intenta conservar vector; raster pierde la naturaleza vectorial. |

## Capacidades FFmpeg obligatorias tras preparar motores

- `libx264`;
- `libwebp` y `libwebp_anim`;
- `apng`;
- `h264_videotoolbox` y `hevc_videotoolbox`;
- `prores_ks`;
- muxers APNG y WebP;
- filtros `scale`, `fps`, `palettegen`, `paletteuse` y `loop`.

libx265 no está aprobado ni incluido.
