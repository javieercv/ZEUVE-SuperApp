# Compilación para macOS — ZEUVE 0.7.5

## Entorno obligatorio

- Mac Apple Silicon ARM64.
- macOS 14 Sonoma o posterior.
- Xcode con Swift 6 y Command Line Tools seleccionadas.
- Conexión a Internet únicamente durante la preparación explícita de motores.

No se utiliza Homebrew. SQLite y `libarchive` proceden del SDK/sistema. El usuario final no debe instalar Python, librerías ni motores manualmente.

## 1. Preparar motores

La copia fuente incluye yt-dlp, Deno, FFmpeg y FFprobe ya registrados. Pandoc, Calibre y Ghostscript aparecen como motores opcionales **no proporcionados** hasta ejecutar la preparación en un Mac ARM64.

```bash
xcode-select -p
./Scripts/prepare_engines_macos.sh
./Scripts/verify_engines_macos.sh
```

`prepare_engines_macos.sh` trabaja en un directorio temporal independiente y publica `Resources/Engines` solo después de superar la verificación. El script:

- descarga artefactos con versiones y SHA-256 fijados;
- preserva la aplicación oficial completa de Calibre 9.11.0 con su firma;
- incorpora Pandoc 3.10;
- compila Ghostscript 10.07.1 para ARM64 y conserva sus recursos locales;
- compila libopus 1.5.2, libmp3lame 3.100, x264 r3222 y libwebp 1.6.0 de forma estática;
- compila FFmpeg/FFprobe 8.1.2 con libx264, libwebp, VideoToolbox y ProRes;
- mantiene libx265 excluido;
- desactiva la red propia de FFmpeg;
- copia licencias y avisos;
- genera `engines.json` con rutas, versiones, arquitecturas, tamaños y hashes reales;
- restaura el conjunto anterior si la publicación o la verificación final fallan.

`Scripts/static_pkg_config.py` lee únicamente archivos `.pc` del prefijo temporal. No consulta `/opt/homebrew`, `/usr/local` ni instalaciones globales.

## 2. Ejecutar pruebas y verificaciones

```bash
./Scripts/run_tests.sh
./Scripts/verify_project.sh
```

Para comprobar únicamente SwiftPM:

```bash
swift test
swift build -c release
```

## 3. Generar el proyecto Xcode

```bash
python3 Scripts/generate_xcode_project.py
```

El proyecto generado:

- fija arquitectura `arm64` y macOS 14;
- utiliza Swift 6 y concurrencia estricta;
- activa Hardened Runtime y mantiene App Sandbox desactivado;
- copia `Resources/Engines` como carpeta de recursos;
- conserva las firmas de yt-dlp y Calibre;
- firma Deno, FFmpeg, FFprobe, Pandoc y Ghostscript con la identidad de ZEUVE cuando están presentes;
- ejecuta la verificación del paquete resultante durante el build.

## 4. Compilar

```bash
./Scripts/build_macos.sh Debug
./Scripts/build_macos.sh Release
```

Los resultados se generan en `build/DerivedData`.

## 5. Abrir y comprobar

```bash
open build/DerivedData/Build/Products/Release/ZEUVE.app
```

Antes de considerar validada la versión 0.7.0 deben comprobarse en un Mac Apple Silicon:

- apertura normal y Gatekeeper;
- firma e integridad de todos los motores preparados;
- selectores nativos, arrastrar y soltar, bookmarks y carpetas de salida;
- ImageIO, PDFKit y VideoToolbox;
- Pandoc, Calibre y Ghostscript con archivos sintéticos pequeños;
- progreso, cancelación, procesos hijos y ausencia de huérfanos;
- vista previa, nombres, colisiones, ZIP, historial, preajustes y favoritas;
- teclado, VoiceOver, modo claro y modo oscuro.

No debe afirmarse que estas integraciones están validadas a partir de una compilación Linux.

## Firma y notarización

`Scripts/sign_embedded_engines.sh` aplica una política explícita:

- conserva y verifica las firmas originales de yt-dlp y Calibre;
- firma Deno, FFmpeg, FFprobe, Pandoc y Ghostscript cuando están presentes;
- llama a `Scripts/verify_packaged_engines_macos.sh` sobre los recursos ya copiados en la aplicación.

No se utiliza `codesign --deep` como sustituto de esta política. La identidad de distribución, notarización y creación de DMG dependen de las credenciales del propietario.

## Empaquetado del proyecto

```bash
python3 Scripts/package_release.py
```

El ZIP excluye `.build`, `.engine-build`, `build`, `dist`, DerivedData, cachés, registros, temporales, estado local de Xcode y metadatos del sistema.

## Instalación de x264

Se utiliza `make install-lib-static`, que incluye las cabeceras mediante `install-lib-dev`. No se utiliza `install-headers` porque no existe en el Makefile de la revisión fijada.
