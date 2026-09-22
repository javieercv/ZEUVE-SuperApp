# Informe de implementación — ZEUVE 0.7.3

## Objetivo
Retirar completamente LibreOffice y todos los formatos ofimáticos del Conversor, conservando CSV como formato genérico de datos.

## Cambios realizados
- Eliminados el constructor y la ruta de ejecución de LibreOffice.
- Eliminado LibreOffice de `engines.json`, preparación, verificación, firma y empaquetado.
- Eliminadas las categorías y enumeraciones de Word, Excel, PowerPoint, OpenDocument y RTF del Conversor.
- Añadido rechazo explícito de estas extensiones, también dentro de ZIP.
- Conservados CSV, JSON y XML como datos.
- Pandoc queda limitado a TXT, Markdown, HTML y EPUB.
- Retirada la conversión SVG a PDF dependiente de LibreOffice.
- El Organizador no se ha modificado.
- Actualizados versión, pruebas y documentación activa.
