# Continuación de QA del Descargador — 10/10/2026

## Alcance

Petición del usuario: «prueba todo lo que puedas probar». Base remota sincronizada `2bf0f823b4b14950882587f81c350d8555154ef5`, árbol limpio. App Debug existente ZEUVE 0.20.7.0/build 73; ejecutable SHA-256 `3bd73c91ebba276a8b76f606b6b2bb51223e65395fe580eb3a2809bf6cb568fe`, debug dylib `19b5726c9ea0fe4c12af004a162df7a4f99dab5e3f0b3d38f3eb051985853a3e`. Sin recompilar, sin modificar producto, motores, versión ni preferencias personales.

Datos nuevos aislados mediante `ZEUVE_DATA_DIR` en `QA-descargador-20261010.pb47Av/Data`, archivos y capturas externos al repositorio. Se reutilizan los enlaces públicos aportados el 09/10 y se añaden dos emisiones públicas de NASA enlazadas por su página oficial. No se importan cookies/sesiones, no se lee el Llavero ni cookies/almacenamiento de autenticación del navegador, no se eluden bloqueos ni restricciones. Control nativo AppleScript/System Events autorizado. Los resultados Debug no certifican toda la distribución Release.

## Registro individual

- **D-34 — ❌:** Reintento nativo del perfil L04 en datos nuevos, sin sesión: análisis termina con 0 elementos y consejo «Activa más secciones», sin catálogo utilizable. Se mantiene fallo de resolución/presentación; no se atribuye todo el rechazo a ZEUVE ni se certifica disponibilidad del origen. Evidencia `profile-result.txt`; D-40–D-43/D-56 siguen sin ejecutarse.

- **D-18 — ✅:** Nueva descarga del clip público L14 desde UI en sesión limpia: 1 correcto/0 fallidos; `Twitch/bubble.mp4` publicado. FFprobe confirma H.264/AAC y 5,007 s; decodificación íntegra exit 0. Cerrar resumen deja UI disponible sin aviso heredado de Reddit. Aceptación acotada al clip aportado, no a cualquier VOD. Evidencia `twitch-analysis/plan/result/clean.txt`.

- **D-38 — ✅:** Contrastadas visualmente las diez imágenes de L07 en el carrusel público original, recorriendo Siguiente hasta desaparecer en la décima, frente a los diez JPEG publicados el 09/10 con índices 01–10. Orden coincidente: Luna; objetos sobre madera; tablet/libros/cámara; ilustración unicornio; niña/gafas; astronauta ilustrado; diario/foto; niño/oso; dibujo de equipaje; astronauta flotante. Complementa catálogo nativo de diez tarjetas ya probado; no se deduce el orden solo de los nombres. Sin login ni importación de cookies; capturas del navegador visibles en este chat.

- **D-34 — ❌:** Contraste independiente del mismo perfil en navegador sin login: la página pública muestra nasa, foto, Publicaciones y enlaces de reels/carruseles; no se importa esa sesión de navegador en ZEUVE. Confirma que el perfil existe y es visible públicamente en ese recorrido, pero no demuestra acceso idéntico para endpoints del motor. `request_blocked` de la app y ausencia de mensaje útil siguen sin resolver.

- **D-17 — ⚠️:** L13 reintentado desde UI: el análisis acaba sin multimedia compatible alrededor de 180 s; al comprobar a los 189 s la operación ya había terminado y Cancelar no existía. Se cierra el aviso y no se publica ningún archivo de esta entrada. El clic tardío de cancelación es un incidente de control, no una cancelación efectiva. El vídeo L12 conserva su aceptación previa. Contraste público en navegador: Reddit muestra «Prove your humanity» y reCAPTCHA; no se resuelve ni elude. Esto limita la comprobación del origen, pero no demuestra que el CAPTCHA sea la causa exacta del timeout del motor. Se mantiene parcial.

- **D-60 — ⚠️:** Configuración plataforma/perfil OFF y subcarpeta multi ON probada desde Ajustes nativos: L07 publica 10 JPEG en Downloads/Publicación - CGadBvyJNix, sin Instagram/nasa/Publicaciones. UI 10 correctos/0 fallidos. El clic de control por ordinal alcanzó Descargar, no el selector esperado; la carpeta era la salida QA ya comprobada, sin originales afectados. Evidencia folders-off-on-ready/folder-picker.txt. Se mantiene parcial hasta restantes combinaciones y destacadas.

- **D-60 — ⚠️:** Segunda combinación real: plataforma/perfil OFF y subcarpeta multi OFF. L07 publica 10 JPEG en Downloads/CGadBvyJNix (queda activa la opción general «Crear una carpeta para la lista»), no directamente en la raíz. UI 10 correctos/0 fallidos; se conservan los 10 de la combinación anterior en su subcarpeta, sin sobrescritura. Evidencia folders-off-off-ready/result.txt. Queda combinación ON/OFF y contenido de destacadas.

- **D-60 — ⚠️:** Tercera combinación real ON/OFF: L07 publica 10 JPEG en Downloads/Instagram/nasa/Publicaciones, sin subcarpeta de publicación; UI 10 correctos/0 fallidos. ON/ON ya probado el 09/10 en Instagram/nasa/Publicaciones/Publicación - CGadBvyJNix. Quedan cubiertas las cuatro combinaciones de estos dos ajustes con fotos de carrusel; destacadas no disponibles y requisito completo conserva parcial. Evidencia folders-on-off-ready/result.txt.

- **D-73 — ⚠️:** Primer caso programado oficial NASA (13/10, enlace publicado en nasa.gov/live y navegador «La emisión comenzará en 2 días»): formato /live/f8FE2R7esZ0 rechazado inmediatamente con explicación explícita de emisiones activas/programadas y repeticiones normales; Analizar deshabilitado, ningún archivo. Se prueba ahora la URL canónica /watch del mismo ID para verificar detección por estado, no solo por ruta. Evidencia scheduled-live-url.txt. No se importan sesiones del navegador.

- **D-73 — ⚠️:** Mismo programado en /watch?v=f8FE2R7esZ0: yt-dlp detecta «This live event will begin in 2 days»; termina sin catálogo/descarga tras fallbacks. Rechazo efectivo, aunque UI reemplaza la causa por «No se ha podido extraer contenido multimedia compatible» (YT-EBA5A209CDC2583B). Ajustes abierto recibió además aviso titulado «No se ha podido guardar el ajuste» con texto de análisis: incongruencia de presentación observada, no fallo demostrado de persistencia. Evidencias scheduled-watch-result/main.txt. Queda directo activo.

- **D-73 — ✅:** Directo activo oficial NASA awQzjn72bI0 comprobado desde listado oficial y navegador («En directo», usuarios viéndolo ahora), luego analizado en ZEUVE sin sesión: identifica emisión en directo, avisa «no puede descargarse en esta versión», 0 seleccionados y Descargar deshabilitado. Junto al programado f8FE2R7esZ0 cubre ambas ramas; no se publica archivo. Se conserva nota de mensaje genérico del programado y aviso incongruente de Ajustes. Evidencia active-live-result.txt. Enlaces públicos adicionales obtenidos de https://www.nasa.gov/live/, no fuentes privadas.

- **P-12 — ⚠️:** Auditoría de logs de esta sesión aislada tras tráfico real: 115 entradas, sin marcador sessionid= ni referencias a importación de cookies; no se usaron credenciales. Persiste 1 mensaje de error con URL Google de query técnica (fallback del programado), no prueba de filtración de una sesión aportada. Sin ensayo con canarios/credenciales y sin sesión autenticada no se certifica redacción completa; se mantiene parcial. Archivos QA privados fuera del repositorio, no se publica el log bruto.


- **D-74 — ⚠️:** Repetición L20 vuelve a analizarse: 6:22:51, 35 formatos, emisión finalizada admitida. Descarga original iniciada con estimación UI 867,6 MB; temporal f401 supera 1.286.883.351 bytes sin finalizar. Se cancela desde UI para acotar disco/tráfico: resumen «Descarga cancelada», 0 correctos/0 fallidos, controles recuperados. Se conserva discrepancia de estimación como observación (no tamaño final conocido). Aún no hay repetición completa publicada; se intentará formato explícito más ligero. Evidencia replay-ready/download-progress/cancel.txt.

- **D-74 — ⚠️:** Después de cancelar, se elige modo Vídeo: «Mejor disponible» estima 20,95 GB frente a 867,6 MB en Automático/Original para el mismo contenido. Se abre el menú de resolución; macOS bloquea la sesión y el control pierde acceso a la ventana al intentar 360p. No se selecciona ni se inicia la descarga ligera; este impedimento es del control, no un nuevo fallo de ZEUVE. Proceso app vivo, sin motores; punto de continuación: elegir 360p y confirmar plan antes de descargar. Cancelación previa eliminó automáticamente los ~1,3 GB temporales propios, conservando las salidas publicadas.

## Comprobaciones complementarias

- `./Scripts/run_tests.sh`: finaliza con exit 0; suites Swift sin fallos y 115 pruebas Python correctas. Se observan advertencias Swift 6 de captura de tipos Vision no Sendable en `BitmapSubtitleOCRService.swift`; no se corrigen ni se confunden con fallos de ejecución. Esta batería complementa, no sustituye, la aceptación manual.
- Treinta JPEG de las tres combinaciones nuevas de carpetas: SHA-256 idéntico a los diez correspondientes del 09/10; cada combinación suma 1.718.817 bytes. No se eliminan las salidas anteriores.


## Cierre y límites

Estado final: **639 IDs, 611 OK, 6 fallidas, 7 parciales, 15 pendientes; 624 ejecutadas**. Se cierran D-18, D-38 y D-73. No se cambia código, producto, versión, motores ni preferencias personales. Los seis fallos anteriores D-13/D-15/D-22/D-23/D-24/D-34 siguen registrados; solo D-34 se reintenta en esta ronda, no se presentan los demás como revalidados hoy.

Parciales: D-11/D-33/D-39 dependen del perfil Instagram que no devuelve catálogo; D-17 conserva límite de galería Reddit; D-60 cubre los cuatro pares de ajustes con carrusel, pero no destacadas; D-74 no publica la repetición completa; P-12 no prueba credenciales/canarios. Pendientes: D-25 sin enlace EroMe aportado; D-40–D-43/D-56 sin catálogo/paginación de perfil; D-44–D-51/P-11 sin sesión de prueba válida, cuya importación no queda autorizada por permisos generales sobre el ordenador.

Observaciones nuevas sin corregir: estimación 867,6 MB para Original frente a 20,95 GB en Vídeo/Mejor disponible y temporal que supera la primera estimación; causa exacta no diagnosticada. Mensaje de emisión programada se degrada a error genérico al agotarse fallbacks. Con Ajustes abierto, aviso de análisis aparece con título de guardado de ajuste; no demuestra fallo al guardar.

MacOS confirma sesión bloqueada (`CGSSessionScreenIsLocked=Yes`) al perder acceso al menú de resolución; no se intenta desbloquear ni eludir el sistema. App QA se cierra normalmente mediante evento Quit al bundle exacto (exit 0), sin controles de la pantalla bloqueada; no quedan app QA ni motores. Los dos ajustes de carpetas del catálogo quedan restaurados ON/ON en datos QA. La selección de operación Vídeo/Mejor disponible no llegó a iniciar otra descarga. Para retomar D-74: analizar L20, elegir Vídeo/360p, confirmar tamaño y salida QA, descargar y verificar duración/pistas/decodificación antes de aceptar.

Evidencia local: `/Users/javiercv/.codex/visualizations/2026/10/09/01a1201b-d804-7c71-b3e1-6afa41a55be7/QA-descargador-20261010.pb47Av`. Conserva 31 archivos multimedia publicados (30 JPEG y un MP4 Twitch), más estados AX/captura de continuidad; no se publican estos archivos ni logs brutos en Git. El selector de carpeta no utilizado dejó una carpeta QA vacía `Folders-OFF-ON`, sin efecto en producto. La caché de yt-dlp observada es la común de ZEUVE; no se presenta como totalmente aislada ni se elimina.

Incidencias del control (no fallos de ZEUVE): serialización inicial del helper; wrapper AppleScript de saltos de línea corregido; ruta FFmpeg corregida; cancelación de Reddit intentada después de acabar; clic por ordinal que alcanzó Descargar en vez del selector, sobre salida QA segura; selección de fila de Ajustes corregida; pérdida de ventana al bloquearse macOS. Ninguno cuenta como fallo adicional de aceptación.

Verificaciones documentales: `Scripts/verify/documentation.py` y `Scripts/validate_module_docs.py` correctos. Base remota inicial y comprobación final anterior a publicación coinciden en `2bf0f823b4b14950882587f81c350d8555154ef5`; no hay cambios remotos que integrar.
