# Motores externos de ZEUVE — instantánea 0.20.4.0

Esta carpeta contiene los motores locales que ZEUVE puede empaquetar. `engines.json` es la fuente de verdad de la **instantánea actual**: no mantengas una lista paralela de motores/versiones en esta carpeta.

## Motores obligatorios actuales

`Resources/Engines/engines.json` marca como `required`:

- yt-dlp `2026.08.19`;
- Deno `2.9.0`;
- FFmpeg `8.1.2`;
- FFprobe `8.1.2`;
- gallery-dl `1.32.9`;
- instaloader-zeuve `4.15.3-zeuve.2`.

Pandoc continúa soportado por el Conversor como motor opcional cuando la preparación aprobada lo incorpora. La instantánea actual no contiene un ejecutable de Playwright; el helper de navegador no forma parte del routing efectivo del Descargador 0.7.3.

Calibre, Ghostscript y LibreOffice están retirados y no deben reintroducirse sin una nueva decisión de alcance.

## Preparación

En macOS 14+ Apple Silicon:

```bash
bash Scripts/prepare_engines_macos.sh
bash Scripts/verify_engines_macos.sh
```

La preparación usa versiones fijadas, valida artefactos, compila/prepara motores en staging y publica el conjunto solo después de superar verificaciones. Los motores sociales pueden requerir `prepare_social_engines_macos.sh` dentro del flujo correspondiente. Una compilación normal no debe descargar o actualizar motores silenciosamente.

Sesiones, cookies, cabeceras y credenciales nunca forman parte de esta carpeta ni de una entrega.

## Overrides del usuario

Las versiones instaladas manualmente por el usuario se guardan separadamente bajo `~/Library/Application Support/ZEUVE/Engines/`. La copia incluida en la app permanece intacta y puede restaurarse. Incluso una actualización estable muestra advertencia porque cambiar un motor puede alterar compatibilidad o resultados.

## Firma

La política operativa vive en `Scripts/sign_embedded_engines.sh`:

- yt-dlp conserva su firma oficial;
- Deno conserva su firma oficial y los entitlements JIT requeridos;
- FFmpeg y FFprobe se firman con la identidad de ZEUVE;
- gallery-dl e instaloader-zeuve se firman con la identidad de ZEUVE y los entitlements previstos para sus bundles PyInstaller;
- Pandoc se firma cuando está incluido como motor opcional.

`Scripts/verify_packaged_engines_macos.sh` verifica dinámicamente los motores registrados/empaquetados pertinentes; no asume un número fijo de cuatro ejecutables.

No copies binarios de Homebrew, MacPorts ni instalaciones locales no verificadas al conjunto empaquetado.
