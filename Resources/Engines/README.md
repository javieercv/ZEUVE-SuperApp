# Motores externos de ZEUVE

Esta carpeta contiene los motores locales que ZEUVE puede incluir dentro de la aplicación. No se descargan durante el uso normal y el usuario final no debe instalar nada manualmente.

La copia de desarrollo incluye los motores obligatorios del Descargador. Los motores opcionales del Conversor —Pandoc, Calibre y Ghostscript— aparecen registrados en `engines.json` con tamaño cero y una huella nula hasta que se preparen realmente en un Mac Apple Silicon. LibreOffice y los formatos ofimáticos fueron retirados en ZEUVE 0.7.3.

En un Mac Apple Silicon con macOS 14 o posterior, ejecuta:

```bash
bash Scripts/prepare_engines_macos.sh
bash Scripts/verify_engines_macos.sh
```

El script de preparación:

- descarga únicamente las versiones fijadas;
- verifica los SHA-256 antes de usar cada archivo;
- conserva completa y con su firma oficial la aplicación de Calibre;
- incorpora Pandoc para TXT, Markdown, HTML y EPUB;
- compila Ghostscript para EPS;
- compila FFmpeg y FFprobe 8.1.2 con libmp3lame, libopus, libx264 y libwebp estáticos, además de VideoToolbox;
- genera `engines.json` con hashes, tamaños, licencias e integridad de los paquetes reales;
- publica el nuevo conjunto solo después de superar la verificación completa.

Durante la firma de la aplicación, yt-dlp y Calibre conservan sus firmas oficiales. Deno, FFmpeg, FFprobe, Pandoc y Ghostscript se firman con la identidad de ZEUVE.

No copies ejecutables de Homebrew, MacPorts ni instalaciones locales: los scripts rechazan dependencias externas no incluidas.
