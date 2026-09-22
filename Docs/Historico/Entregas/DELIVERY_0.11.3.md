# Entrega — ZEUVE 0.11.3

Fecha: 22 de agosto de 2026.

## Versión

- Aplicación: 0.11.2 → 0.11.3.
- Build interno: 38 → 39.
- Descargador universal: 0.6.6 → 0.6.7.

## Contenido

La entrega contiene el proyecto fuente completo, los recursos y motores ya presentes en 0.11.2, la corrección del flujo de descarga de TikTok, pruebas de regresión y documentación actualizada. No se ha sustituido ni ampliado ningún binario de motor.

## Comportamiento entregado

- gallery-dl conserva la prioridad y sus fallbacks internos del CDN.
- El código de salida del motor no basta para declarar éxito: debe existir un archivo candidato regular y no vacío.
- Un fallo o resultado vacío de gallery-dl activa un respaldo limpio con el yt-dlp incluido y la URL pública estable.
- Si el respaldo tampoco produce un archivo, no se publica ningún resto y la interfaz muestra el fallo completo con referencia y acceso a registros.
- Las demás plataformas, formatos, presets, historial, sesiones expresas, temporales privados, validación multimedia y publicación segura mantienen su comportamiento anterior.

## Compatibilidad y validación final

La entrega está preparada para macOS 14 o posterior en Apple Silicon. La compilación Swift/Xcode, la firma, la apertura y la descarga real deben completarse en ese entorno; no se declaran superadas desde Linux.
