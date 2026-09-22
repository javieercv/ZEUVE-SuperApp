# Informe de implementación — ZEUVE 0.16.0.0

Fecha: 20 de septiembre de 2026.

## Objetivo

Corregir los fallos de build directo desde Xcode detectados en la copia activa de ZEUVE 0.16.0.0 sin cambiar comportamiento de producto, arquitectura, privacidad, red, dependencias ni motores.

## Corrección aplicada

Se restauró el bit ejecutable de los scripts `Scripts/*.sh` y de los ejecutables obligatorios incluidos en `Resources/Engines/`: `yt-dlp_macos`, `deno`, `ffmpeg`, `ffprobe`, `gallery-dl` e `instaloader-zeuve`.

Además, `Scripts/sign_embedded_engines.sh` ahora trata una copia empaquetada existente pero sin permiso de ejecución como un estado reparable. La fase de firma comprueba existencia, restaura desde `Resources/Engines` cuando el contenido o el permiso ejecutable no coinciden y solo después valida `-x`. Para los motores que se firman localmente, aplica `chmod +x` en el bundle cuando la fuente es ejecutable.

## Alcance

No se añadieron dependencias, APIs, acceso de red, telemetría, cambios de UI ni cambios funcionales en módulos. La corrección se limita a la infraestructura de compilación/empaquetado local y mantiene la política existente de firmas: yt-dlp y Deno conservan sus firmas oficiales, mientras los motores simples se firman en la fase aprobada.

## Versionado

- ZEUVE: `0.16.0.0`.
- Build: `61`.
- Marketing version Xcode: `0.16.0`.
