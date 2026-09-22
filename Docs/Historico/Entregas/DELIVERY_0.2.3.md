# Entrega — ZEUVE 0.2.3

Fecha: 2 de julio de 2026.

## 1. Resumen

Se ha corregido la política de firma que podía impedir el arranque de yt-dlp tras compilar ZEUVE. El ejecutable oficial de yt-dlp conserva ahora su firma original, mientras que Deno, FFmpeg y FFprobe continúan firmándose con la identidad de ZEUVE. La compilación incorpora una comprobación de arranque de `yt-dlp --version` y el diagnóstico muestra el error técnico real cuando un motor falla.

## 2. Estado

Implementación completada en el código fuente.

Pendiente de validación final en macOS Apple Silicon porque el entorno de trabajo no dispone de Xcode, `codesign` ni capacidad de abrir `ZEUVE.app`.

## 3. Cambios principales

### Firma y empaquetado

- `Scripts/sign_embedded_engines.sh` separa los motores según su política de firma.
- yt-dlp no se vuelve a firmar.
- Deno, FFmpeg y FFprobe se firman con Hardened Runtime.
- Nuevo `Scripts/verify_packaged_engines_macos.sh`:
  - valida la firma de los cuatro ejecutables;
  - ejecuta `yt-dlp --version` dentro de la aplicación;
  - detiene la compilación y muestra la salida real si falla.
- `Scripts/build_macos.sh` repite la verificación después de finalizar `xcodebuild`.

### Diagnóstico

- `EngineDiagnostic` incorpora `technicalDetails` con decodificación compatible con diagnósticos anteriores.
- Los fallos conservan código de salida, señal, `stdout` y `stderr`.
- La interfaz muestra un desplegable “Detalles técnicos” con texto seleccionable.
- La salida de cada stream se limita para evitar cargar cantidades excesivas en la ventana.

### Versión

- Versión anterior: 0.2.2, build 8.
- Versión nueva: 0.2.3, build 9.
- Motivo: corrección de error de empaquetado y mejora diagnóstica asociada.

## 4. Pruebas

- 62 pruebas Swift superadas.
- 11 pruebas Python superadas.
- Proyecto Xcode regenerado.
- Validaciones de versión, manifiestos, scripts y documentación incorporadas.
- Motores originales comparados y conservados sin cambios.

Los resultados y limitaciones se detallan en `Docs/TEST_RESULTS_0.2.3.md`.

## 5. Archivos modificados

- `Scripts/sign_embedded_engines.sh`: conserva la firma de yt-dlp y firma los otros motores.
- `Scripts/build_macos.sh`: verificación posterior a Xcode.
- `Scripts/verify_project.sh`: regresiones y versión 0.2.3.
- `Scripts/generate_xcode_project.py`: versión 0.2.3, build 9.
- `Sources/ZEUVEEngines/EngineModels.swift`: detalles técnicos compatibles.
- `Sources/ZEUVEEngines/EngineDiagnostics.swift`: captura del fallo real.
- `Sources/ZEUVEApp/YouTubeDownloader/YouTubeDownloaderView.swift`: desplegable técnico.
- `Sources/ZEUVEApp/SettingsView.swift`: versión visible.
- Manifiesto, prueba de manifiesto y mensaje versionado del módulo de YouTube.
- Proyecto Xcode, README, decisiones, historial y documentación relacionada.

## 6. Archivos nuevos

- `Scripts/verify_packaged_engines_macos.sh`.
- `Tests/ScriptTests/test_engine_signing_policy.py`.
- `Docs/TEST_RESULTS_0.2.3.md`.
- `Docs/DELIVERY_0.2.3.md`.

## 7. Archivos eliminados

Ninguno.

## 8. Limitaciones

- La causa propuesta queda corregida en el proceso de firma, pero debe confirmarse compilando y ejecutando en macOS.
- La firma original del yt-dlp oficial debe superar `codesign --verify` después de copiarse a la aplicación; si no lo hace, la compilación fallará de forma explícita y mostrará el motivo.
- No se ha realizado una descarga real ni se ha comprobado Gatekeeper.
- No se han añadido dependencias, APIs, telemetría ni conexiones nuevas.
