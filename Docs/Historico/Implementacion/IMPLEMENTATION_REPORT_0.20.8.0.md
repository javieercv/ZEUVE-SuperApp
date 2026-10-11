# Implementación — ZEUVE 0.20.8.0

11/10/2026. Marketing 0.20.8, build 74; Descargador 0.7.4. Base remota comprobada: `36947e228f5d732da6a24a302fa8a3fc008101f9`, rama `main`, sin cambios locales iniciales ni divergencia.

## Alcance aprobado

Plan de corrección de las nueve pruebas fallidas y ocho parciales del Descargador y privacidad, aprobado por el usuario. El usuario pide aviso al terminar la implementación y las verificaciones automáticas, y reserva el inicio de las pruebas manuales reales a una indicación posterior. Reddit en línea continúa aplazado. No se ejecutan sesiones reales ni enlaces remotos durante esta implementación.

## Causas y cambios

- P-12: los diagnósticos de análisis, fallback y rendimiento pasan por una lista de campos estructurados; el texto libre de error se sustituye por categoría y referencia. Los mensajes de fallo publicados al usuario son seguros. El ayudante de Instagram emite avisos cerrados, sin excepciones remotas completas.
- D-13/D-24: el ordinal de gallery-dl se separa del número visible y de la identidad del recurso. La selección usa identidad y una sola coincidencia; `num=0` identifica el audio, no desactiva la selección. El nombre final conserva la extensión efectiva del motor. Auxiliares no se cuentan como multimedia.
- La validación consulta contenedor y pistas de FFprobe, ignora portadas como pista principal y exige contenido primario. Rechaza JPEG renombrado a MP3 y VTT como único resultado; acepta MP4 de solo audio y vídeo sin audio. Valida también después de incrustar metadatos y antes de publicar. Una salida inválida de gallery-dl en TikTok permite el respaldo en un workspace propio limpio.
- D-15/D-24/D-25: identidad estable para variantes de vídeo de X, preferencia por la mayor resolución conocida, conservación de recursos distintos y de la selección original. EroMe completa imágenes desde grupos multimedia concretos del HTML disponible y mantiene el orden del álbum; excluye avatares y posters de vídeo.
- D-47/D-46/D-48: cookies Netscape admiten caducidad vacía como cero sin modificar el archivo elegido. Formato inválido, archivo vacío y archivo inaccesible tienen causas diferenciadas; no se relaja la validación de campos.
- D-11/D-33/D-34/D-39/D-44: resultados vacíos de yt-dlp no cierran un fallback ni fabrican un vídeo. Perfiles conservan resultados parciales, disponibilidad y causa visible. Stories/destacadas llevan requisito de sesión por recurso; sus enlaces evitan el shortcode de publicaciones y el recorrido anónimo. Un cliente que vuelve a modo anónimo deja de anunciar sesión validada. Foto de perfil y recursos ya resueltos se emiten progresivamente antes de un fallo posterior de sección.
- D-22: reconocimiento de publicaciones concretas Tumblr en subdominio y forma `www.tumblr.com/blog/id`, conservando el rechazo de perfiles y rutas de navegación.
- D-17/D-23: timeout configurado por petición y presupuesto de 120 s por análisis/página de las plataformas afectadas, con cancelación de procesos y catálogo parcial cuando existe. No se afirma disponibilidad remota por detectar bloqueo o vacío. Los motores fijados carecen de extractor específico de Threads: no se añade otro motor ni una API alternativa en esta entrega.
- D-60: no se cambia la política de carpetas; su cobertura de destacadas depende del acceso real. Las cuatro combinaciones de carrusel conservan su evidencia anterior.

## Compatibilidad y límites

Campos nuevos de catálogo/plan son opcionales; compatibilidad de decodificación mantenida. YouTube conserva referencias de playlists planas y no recibe el presupuesto global de las plataformas sociales. Sin cambios de SQLite, permisos ni versiones upstream. Se reconstruye únicamente el adaptador propio `instaloader-zeuve 4.15.3-zeuve.3`, con Instaloader 4.15.3 y herramientas fijadas, y se actualizan su hash y tamaño reales.

Originales protegidos, argumentos separados, temporales propios, publicación segura y coordinación global conservados. No se genera ZIP ni otra carpeta versionada. La corrección de causas reproducibles no demuestra acceso autenticado efectivo ni cierre de una casilla manual.

Consulta [resultados](../Pruebas/TEST_RESULTS_0.20.8.0.md) y [entrega](../Entregas/DELIVERY_0.20.8.0.md).
