# Entrega — ZEUVE 0.20.8.3

12/10/2026. Marketing 0.20.8/revisión 3/build 77. Descargador 0.7.7; adaptador propio Instaloader 4.15.3-zeuve.6, mismo upstream y dependencias. Trabajo desde base remota sincronizada `b2c4fa7fc3b5347b6e28bb136ad5ff886865190d` y publicación normal del resultado tras comprobar otra vez el remoto, sin force-push. Las dos comprobaciones de cierre no detectan commits remotos nuevos; no es necesaria integración adicional.

Los perfiles públicos y consultas bloqueadas muestran la sesión como opción plegada. El contenido protegido conserva el panel desplegado. El respaldo de inserción pública aprobado recupera una muestra de fotos con identidad/propietario/orden/formato verificados, sin cookies personales ni servicios terceros. Los avisos indican el límite de la muestra y la ausencia de reproducción de vídeos; no repite otro feed tras obtenerla.

Se corrige además un bloqueo de composición al desplazarse por el catálogo, conservando la cuadrícula perezosa y las opciones aprobadas. Biografía y advertencias únicas se conservan.

Pruebas: 486 Swift y 130 Python correctas; verificación completa, compilación Release real, motores y firma ad hoc comprobados. QA desde UI: 24→35 recursos únicos, dos JPEG descargados/verificados y presentación requerida de contenido protegido. Auditoría saneada sin coincidencias de URLs privadas/firmadas, Llavero ausente, reset QA y cierre de procesos propios.

D-40 pasa a OK; checklist 635 OK, 0 fallidas, 3 parciales, 1 pendiente de 639. D-39 sigue parcial porque no es el catálogo completo; D-41 queda pendiente por vídeos/Reels sin URL y D-11 por Story activa. Reddit online sigue aplazado. No se dispone de publicaciones privadas y no se simula su aceptación. No se amplía la sesión previa al perfil público.

La carpeta activa se mantiene como única copia vigente. Sin ZIP nuevo, distribución, DMG ni notarización. Las evidencias locales de QA conservan archivos de prueba, pero no se publican cookies, respuestas HTML ni URLs firmadas.

[Implementación](../Implementacion/IMPLEMENTATION_REPORT_0.20.8.3.md), [investigación](../Implementacion/INSTAGRAM_PUBLIC_ACCESS_RESEARCH_20261012.md), [pruebas](../Pruebas/TEST_RESULTS_0.20.8.3.md) y [QA nativa](../Pruebas/DOWNLOADER_QA_0.20.8.3_20261012.md).
