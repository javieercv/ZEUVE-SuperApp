# Resultados de pruebas — ZEUVE 0.20.1.0

## Automatización

- `swift test --jobs 1`: PASS; Inspector multimedia 121 pruebas, 0 fallos.
- Regresiones Python específicas: 18/18, PASS.
- Verificador del Inspector y parseo de 80 fuentes de ZEUVEApp: PASS.
- `Scripts/verify_app_macos.sh`: PASS; build Xcode Debug ARM64, motores empaquetados y firma local.

La cobertura nueva incluye resolver de controles/ownership, pausa, estados obsoletos, silencio, tono, ruido de banda completa, low-pass conocido, bajo dominante, gap espectral, cobertura temporal y agrupación/truncado de anomalías.

## Archivos reales

Se registraron huellas SHA-256 de `plane2.mp4`, el MP3 y el WAV indicados para QA. Esta sesión no declara interacción manual completa de todos los controles; las garantías funcionales se apoyan en regresiones deterministas y build real de la app.
