# Motores externos de ZEUVE

Esta carpeta contiene los motores locales que ZEUVE puede incluir dentro de la aplicación. No se descargan durante el uso normal y el usuario final no debe instalar dependencias del sistema.

La copia de desarrollo conserva solo los motores obligatorios del Descargador y conversor multimedia. Pandoc, gallery-dl, instaloader-zeuve, playwright-browser, LibreOffice, Calibre y Ghostscript están retirados del paquete principal para mantener el tamaño acotado.

En macOS 14 o posterior sobre ARM64:

```bash
bash Scripts/prepare_engines_macos.sh
bash Scripts/verify_engines_macos.sh
```

La preparación general:

- usa versiones fijadas y artefactos locales verificados cuando corresponde;
- verifica los artefactos aprobados antes de publicarlos;
- compila FFmpeg/FFprobe 8.1.2 con los codecs aprobados;
- genera `engines.json` con rutas, versiones, hashes, tamaños, licencias y disponibilidad reales;
- publica el conjunto solo después de superar la verificación completa;
- no prepara motores opcionales durante una compilación normal.

Las sesiones, cookies y cabeceras nunca forman parte de esta carpeta ni del ZIP de entrega.

Las versiones actualizadas por el usuario se almacenan separadamente bajo `~/Library/Application Support/ZEUVE/Engines/`. La copia incluida en la aplicación no se modifica y puede restaurarse. Incluso una actualización estable muestra una advertencia porque puede cambiar compatibilidad o comportamiento.

Durante la firma, yt-dlp conserva su firma oficial. Deno, FFmpeg y FFprobe se firman explícitamente con la identidad de ZEUVE cuando están presentes.

No copies ejecutables de Homebrew, MacPorts ni instalaciones locales no verificadas.
