# Entrega — ZEUVE 0.20.8.2

11/10/2026 · Base remota actualizada `4c95ab1911ef32bd60a01dfe61a083e33aeacdcc`. Marketing 0.20.8/revisión 2/build 76; Descargador 0.7.6; instaloader-zeuve 4.15.3-zeuve.5, upstream 4.15.3.

Continuación aprobada de perfiles Instagram y aprobación expresa de la inserción pública de Threads. [Investigación](../Implementacion/INSTAGRAM_THREADS_RESEARCH_20261011.md), [implementación](../Implementacion/IMPLEMENTATION_REPORT_0.20.8.2.md), [verificación](../Pruebas/TEST_RESULTS_0.20.8.2.md) y [QA nativa](../Pruebas/DOWNLOADER_QA_0.20.8.2_20261011.md).

Verificación completa y Release con firma/motores empaquetados comprobadas. Ocho IDs pasan a OK, cuatro archivos decodificados sin error y carga de 24→48 elementos distintos. Checklist: **634 OK, 0 fallidas, 3 parciales y 2 pendientes; 637 ejecutadas de 639**.

Fuera de Reddit quedan cuatro IDs abiertos: D-11 (Stories activas), D-39 (perfil público solo encabezado/avatar), D-40 (publicaciones) y D-41 (Reels). Metadata/feed públicos continúan rechazados con 401; no se presenta el avatar como perfil completo. La sesión se limita al objetivo privado original; no se prueban publicaciones privadas. Reddit D-17 permanece aplazado.

Privacidad contrastada frente a siete valores de cookies/nueve variantes y 67 URLs privadas: cero coincidencias en datos/logs/historial/stdout, con el alcance del informe. Reset QA, Llavero sin item, copias propias de secretos eliminadas y app cerrada; originales y sesión de Brave conservados. No nueva carpeta versionada, ZIP ni notarización. Publicación mediante commit normal tras comprobar otra vez el remoto y verificación del commit publicado.
