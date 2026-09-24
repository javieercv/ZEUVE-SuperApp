# Empaquetado y firma de motores

## Distribución actual

La estructura exacta debe coincidir con `Resources/Engines/engines.json`. En 0.20.4.0 incluye al menos:

```text
ZEUVE.app/Contents/Resources/Engines/
├── yt-dlp/yt-dlp_macos
├── yt-dlp/_internal/
├── deno/deno
├── ffmpeg/ffmpeg
├── ffmpeg/ffprobe
├── gallery-dl/gallery-dl
├── instaloader/instaloader-zeuve
├── licenses/
└── engines.json
```

No mantengas una lista documental distinta del registry real.

## Orden de preparación

1. Ejecutar `Scripts/prepare_engines_macos.sh` en Mac Apple Silicon.
2. Ejecutar `Scripts/verify_engines_macos.sh`.
3. Ejecutar tests/verificadores del proyecto.
4. Generar/verificar el proyecto Xcode.
5. Compilar.
6. Firmar y verificar motores anidados.
7. Verificar firma profunda de la aplicación.
8. Ejecutar QA manual en el Mac objetivo.
9. Notarizar únicamente cuando exista el flujo de distribución aprobado.

## Firma

`Scripts/sign_embedded_engines.sh` es la fuente operativa de esta política.

- `yt-dlp/yt-dlp_macos`: conserva la firma oficial de su distribución.
- `deno/deno`: conserva la firma oficial y los entitlements Hardened Runtime/JIT que necesita V8.
- `ffmpeg/ffmpeg` y `ffmpeg/ffprobe`: se firman con la identidad de ZEUVE.
- `gallery-dl/gallery-dl` e `instaloader/instaloader-zeuve`: se firman con ZEUVE y `social_engine.entitlements` por la naturaleza de sus bundles PyInstaller.
- Motores opcionales como Pandoc se omiten si no están presentes y solo se documentan como incluidos cuando el registry lo confirme.

`Scripts/verify_packaged_engines_macos.sh` verifica los ejecutables empaquetados pertinentes y ejecuta diagnósticos reales. La comprobación no está limitada a un número fijo de firmas.

La firma puede cambiar bytes/tamaño de los motores resignados. La integridad de origen se valida antes de firmar mediante la verificación de motores; el diagnóstico en ejecución no debe confundir una firma válida con un hash previo a firma.

## Dependencias dinámicas

`otool -L` solo debe mostrar componentes del sistema o librerías incluidas de forma resoluble dentro del paquete. Se rechazan dependencias no empaquetadas de Homebrew, MacPorts, `/usr/local` u otras instalaciones locales.

## App Sandbox

Permanece desactivado en la fase actual. Activarlo requiere una decisión específica y pruebas de bookmarks, cookies, procesos anidados, salida a carpetas y motores.

## Validación

La preparación, firma, Hardened Runtime y ejecución de binarios ARM64 deben comprobarse en macOS Apple Silicon. Las pruebas portables no sustituyen esa validación.
