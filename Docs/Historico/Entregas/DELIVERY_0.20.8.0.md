# Entrega — ZEUVE 0.20.8.0

11/10/2026 · marketing 0.20.8/build 74 · Descargador 0.7.4 · instaloader-zeuve 4.15.3-zeuve.3. Otros módulos y versiones upstream permanecen iguales.

Correcciones aprobadas de privacidad, selección y validación multimedia, cookies Netscape, catálogos/fallbacks de Instagram, deduplicación de X, imágenes de EroMe, publicaciones Tumblr y límites de análisis social. Sin nuevas dependencias, permisos, motores upstream, esquema SQLite, ZIP ni carpeta versionada. Se mantiene el flujo de publicación y comprobación remota mediante commit normal.

Suites Swift/Python y verificadores completos pasan. Build Debug y Release reales pasan; motores empaquetados y firma local verificados. 117 pruebas del Descargador y 118 Python sin fallos. Al cierre de la implementación, la app Release está preparada sin iniciarla.

En ese momento la aceptación manual espera la indicación expresa del usuario. Checklist conservada: 639 pruebas, 613 OK, 9 fallidas, 8 parciales y 9 pendientes. No se certifica resolución de las restricciones remotas de Instagram/Threads por estas correcciones locales. Reddit en línea sigue aplazado; D-60 conserva la cobertura de carruseles y espera destacadas reales.

Consulta [implementación](../Implementacion/IMPLEMENTATION_REPORT_0.20.8.0.md) y [resultados automáticos y límites](../Pruebas/TEST_RESULTS_0.20.8.0.md).

## Estado posterior a la QA autorizada — 11/10/2026

El usuario autoriza las pruebas reales. La [QA nativa de Release](../Pruebas/DOWNLOADER_QA_0.20.8.0_20261011.md) deja 621 OK, 7 fallidas, 6 parciales y 5 pendientes; 634 pruebas ejecutadas de 639. Snapchat, EroMe, importación/guardado/reset de sesión y privacidad pasan en el alcance probado; persisten fallos y aparecen regresiones de SoundCloud y recuperación del Llavero. No hubo descarga privada exitosa y no se certifica aceptación completa. Esta continuación solo actualiza evidencias/documentación; conserva versión y binarios, sin ZIP.
