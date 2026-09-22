# Entrega — ZEUVE 0.15.2.0

Fecha: 9 de septiembre de 2026.

## Versiones

- ZEUVE: `0.15.2.0`.
- Build: `53`.
- Inspector multimedia: `0.3.2`.

## Estado

La sustitución de pista de audio es atómica dentro del servicio. La sesión anterior queda retirada y completamente cerrada antes del arranque siguiente; las peticiones antiguas pierden su ticket y no pueden detener ni publicar sobre la última selección.

La UI conserva el instante durante cambios rápidos y muestra un único estado **Cargando…** para la pista solicitada. Al confirmarse, solo esa pista muestra **Pausar**. Waveform, espectrograma y snapshots descartan resultados de generaciones anteriores.

La suite completa, la build Release firmada y el arnés real con el MKV multiaudio indicado pasan. La carpeta activa `ZEUVE_Swift` se ha actualizado en su sitio; no se ha creado otra versión ni un ZIP.

## Límites preservados

Sin cambios en dependencias, motores, red, privacidad, permisos, DSP, formatos, archivos originales, edición estructural ni otros módulos.
