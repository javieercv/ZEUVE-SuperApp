# Huellas de motores — ZEUVE 0.2.4

Fecha: 2 de julio de 2026.

## yt-dlp 2026.06.09

Artefacto oficial aprobado: `yt-dlp_macos.zip`.

- SHA-256 del ZIP oficial: `62a3108d7c37090107f0bb9a2369b953b35e43f4bc76ab0ea87e4ab593c23ec7`.
- SHA-256 del ejecutable raíz extraído `yt-dlp_macos`: `4eefb498e76f8a425bec30ba3ee2079b01542ca39ca1fb61b79966450794cc13`.
- Tamaño del ejecutable raíz extraído: `12143200` bytes.
- SHA-256 determinista del árbol descomprimido completo: `18d76939eb25aedd470fe03a2efaced1b3532dda33426477a9bf9e757584be49`.
- Tamaño acumulado del árbol descomprimido: `125261318` bytes en `143` archivos.
- Arquitectura declarada: universal `arm64` + `x86_64`.

El paquete descomprimido incluye la carpeta `_internal`, necesaria para ejecutar yt-dlp sin utilizar Python instalado en el Mac. `Resources/Engines/engines.json` registra la huella del ejecutable raíz y los scripts verifican también que la carpeta interna exista.

## Otros motores

Deno 2.9.0, FFmpeg 8.1.2 y FFprobe 8.1.2 se conservan de la versión recibida. Sus huellas vigentes se registran en `Resources/Engines/engines.json`. La verificación completa de arquitectura, versión, dependencias y firma debe ejecutarse en macOS Apple Silicon.
