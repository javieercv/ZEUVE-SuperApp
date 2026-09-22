# Informe de implementación — ZEUVE 0.11.4

## Objetivo aprobado

Permitir analizar y descargar reels y publicaciones públicas de Instagram sin iniciar sesión, sin pegar cookies y sin leer cookies del navegador. La sesión debe reservarse para contenido cuya privacidad o necesidad de autenticación se haya confirmado.

## Implementación

- Los enlaces concretos de Instagram priorizan el yt-dlp 2026.08.19 incluido y conservan gallery-dl como respaldo.
- El análisis intenta primero ambos motores sin sesión, incluso si el usuario había configurado cookies para otros contenidos.
- Los fallos ambiguos de red, rate limit o redirección a login producen un error de contenido público no disponible, pero no solicitan autenticación.
- Solo las señales explícitas de cuenta, perfil o publicación privada habilitan el reintento autenticado y marcan el elemento para utilizar la sesión durante su descarga.
- La descarga vuelve a decidir la política por elemento y anula cookies de texto, archivo, navegador y cabecera para Instagram público.

## Compatibilidad y entrega

El cambio no modifica la política de sesión de YouTube, TikTok u otras plataformas. Los perfiles privados de Instagram siguen admitiendo las vías de sesión ya autorizadas. La aplicación queda en 0.11.4, build 40, con el módulo Descargador universal 0.6.8. Todo se ha editado dentro de la carpeta activa original; no se ha creado un ZIP ni una segunda carpeta del proyecto.
