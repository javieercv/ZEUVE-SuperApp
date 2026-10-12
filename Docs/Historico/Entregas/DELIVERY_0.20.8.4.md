# Entrega — ZEUVE 0.20.8.4

12/10/2026. Marketing 0.20.8/revisión 4/build 78; Descargador 0.7.8; helper propio 4.15.3-zeuve.7, mismo upstream 4.15.3 y dependencias. Base remota sincronizada `3f499d8eab1ac7382066266454dac545cd9bcf3a`; publicación normal tras volver a comprobar el remoto, sin force-push.

La muestra de perfiles públicos completa sus vídeos/Reels mediante la consulta de publicación concreta ya incluida. Valida usuario, post e hijos, mantiene formatos/orden/carpetas y sesión opcional. La paginación no pierde fotos si falla reproducción; no vuelve a consultar vídeos de ventanas anteriores. Errores, bloqueos y cancelación conservan el contrato vigente.

487 Swift y 134 Python correctas, verificación completa, Release ARM64, motores y firma ad hoc. QA nativa desde perfil: 24→42 recursos (avatar, 34 fotos, cuatro Reels y tres vídeos), tres descargas reales válidas y repetición por @usuario con ejecutable final. D-39/D-41 pasan; checklist 637 OK, 0 fallidas, 2 parciales y 0 pendientes. D-11 y D-17 conservan su estado por exclusión de Stories activas/cuentas privadas y aplazamiento de Reddit.

El feed global anónimo sigue devolviendo 401. El catálogo mantiene aviso de muestra finita; esta entrega no promete todas las publicaciones del perfil. No se amplía la sesión previa ni se elude el bloqueo. Auditoría sin referencias firmadas persistidas, reset y cierre propios, Llavero ausente. Carpeta activa única; sin ZIP, DMG, nuevas dependencias o notarización.

[Implementación](../Implementacion/IMPLEMENTATION_REPORT_0.20.8.4.md), [investigación](../Implementacion/INSTAGRAM_PUBLIC_REELS_RESEARCH_20261012.md), [pruebas](../Pruebas/TEST_RESULTS_0.20.8.4.md) y [QA](../Pruebas/DOWNLOADER_QA_0.20.8.4_20261012.md).
