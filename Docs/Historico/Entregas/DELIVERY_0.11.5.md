# Entrega — ZEUVE 0.11.5

## Estado

La carpeta activa `ZEUVE_Swift` contiene el código fuente de ZEUVE 0.11.5, build interno 41, y Descargador universal 0.6.9. Se mantiene una única copia activa y no se entrega ningún ZIP.

## Contenido

- Ruta específica anónima de Instagram mediante `instaloader-zeuve 4.15.3-zeuve.2`.
- Fallbacks existentes `gallery-dl`, `yt-dlp` y descubrimiento genérico conservados.
- Descarga completa de fotos, vídeos, Reels y carruseles, incluido contenido mixto.
- Política «Automático por plataforma» individual por elemento.
- YouTube MP3 320 por defecto; demás plataformas en formato original de máxima calidad.
- Opciones manuales «Vídeo» y «Solo audio» conservadas.
- Manifiestos, hashes, documentación y pruebas actualizados.
- La aplicación Release fue compilada y validada durante la entrega original. La limpieza local autorizada posterior eliminó `build`, `.build` y `DerivedData`; por tanto, el producto compilado ya no está presente y debe regenerarse antes de utilizarlo de nuevo.

## Privacidad

Las rutas públicas de Instagram no reciben una sesión aunque exista una guardada. Solo una confirmación explícita de privacidad permite el reintento autenticado. Las URLs firmadas del CDN permanecen en memoria y no se escriben en historial, registros o metadatos.
