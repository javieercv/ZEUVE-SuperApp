# Informe de implementación — ZEUVE 0.7.0

## Resumen

Se ha ampliado el Conversor 0.6.0 sobre su arquitectura real. No se ha reescrito el módulo ni se han modificado los otros módulos salvo referencias de versión, registro compartido y documentación.

## Implementado

- categorías separadas para raster, vectorial, animación, audio, vídeo, documentos, hojas, presentaciones, PDF, texto, marcado, ebooks y datos;
- detección detallada y discrepancias de extensión;
- inspección estructural OOXML, OpenDocument y EPUB, también dentro de ZIP;
- matriz central y capacidades reales de FFmpeg;
- lotes mixtos dentro de una categoría;
- scripts y registro de LibreOffice, Pandoc, Calibre, Ghostscript, libx264 y libwebp;
- EPS, SVG, ebooks, Markdown/HTML y animaciones según motor;
- secuencia de imágenes a vídeo y vídeo a animación;
- copia de audio/vídeo cuando es compatible;
- tres políticas de metadatos;
- salida directa o subcarpeta, bookmarks y nombres seguros;
- protección cruzada frente a cualquier original del lote;
- ZIP preserve/flatten, límites, cifrado y limpieza de restos;
- cinco perfiles de calidad, migración de 0.6.0, preajustes y favoritas portables;
- progreso por elemento, paralelismo conservador y espacio estimado;
- validación específica antes de publicación;
- contraseña temporal para ZIP y PDF;
- diagnóstico ampliado y ayuda contextual;
- versión ZEUVE 0.7.0 build 21 y módulo Conversor 0.2.0.

## Implementación parcial

- Las opciones avanzadas cubren los parámetros que los builders actuales aplican, pero no todos los controles enumerados en el documento original.
- La política de metadatos es general y no permite elegir cada grupo por separado.
- El historial almacena la receta, pero la interfaz global todavía no ofrece crear una favorita directamente desde una entrada histórica.
- Las secuencias admiten orden natural y duración, pero no reordenación manual ni pista de audio.
- El diagnóstico muestra motores y capacidades; la autocomprobación sintética completa de cada formato queda pendiente del Mac con todos los motores.

## Fuera de alcance aprobado

- fuentes;
- modelos 3D.

## Pendiente del entorno macOS

- preparar y empaquetar los cuatro motores opcionales;
- verificar firma y Gatekeeper;
- compilar y abrir la `.app`;
- probar ImageIO, PDFKit, VideoToolbox, selectores, drag and drop, VoiceOver y modos visuales;
- ejecutar conversiones reales con LibreOffice, Pandoc, Calibre y Ghostscript.
