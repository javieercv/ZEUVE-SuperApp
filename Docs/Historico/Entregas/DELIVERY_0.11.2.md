# Entrega — ZEUVE 0.11.2

Fecha: 22 de agosto de 2026.

## Versión

- Aplicación: 0.11.1 → 0.11.2.
- Build interno: 37 → 38.
- Descargador universal: 0.6.5 → 0.6.6.

## Contenido

La entrega contiene el proyecto fuente completo, la corrección del flujo social, motores ARM64 de gallery-dl e instaloader-zeuve, pruebas de regresión, documentación actualizada y un caso real validado de TikTok.

## Comportamiento entregado

- YouTube continúa funcionando con su ruta anónima aprobada.
- TikTok usa gallery-dl como motor principal y descarga desde la URL pública estable, con fallbacks internos del CDN.
- Fotografías, vídeos y galerías interpretan el protocolo vigente de gallery-dl.
- Los motores sociales son obligatorios y se comprueban antes de compilar.
- No se persisten URLs firmadas, cookies, tokens ni cabeceras privadas.

## Compatibilidad

Se mantienen los formatos, presets, historial, sesiones expresas, temporales privados, validación multimedia y publicación segura existentes. La compatibilidad de cada sitio sigue dependiendo de sus cambios públicos y de los motores fijados.
