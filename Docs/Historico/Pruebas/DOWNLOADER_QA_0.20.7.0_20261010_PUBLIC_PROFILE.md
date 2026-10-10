# QA de perfil público adicional — 10/10/2026

El usuario aporta un perfil público con publicaciones y Reels para continuar los requisitos de catálogo pendientes. Base sincronizada `dc8fe5a14a785a15a4916b6fc82aeb606ad41a27`, sin cambios locales ni remotos nuevos. Misma app Debug 0.20.7.0/build 73 y datos QA aislados; sin correcciones de código ni motores. No se usa ni importa la sesión de Brave para este nuevo perfil. Item Instagram de ZEUVE en Llavero ausente antes de la prueba (solo consulta de existencia, exit 44).

El perfil se abre en navegador independiente sin sesión de Instagram: muestra Iniciar sesión/Registrarte, foto de perfil, pestañas Publicaciones/Reels, enlaces de publicaciones y Reels, dos destacadas y Mostrar más publicaciones. Existencia y contenido público confirmados; no se guardan títulos, datos biográficos, cookies, URLs firmadas ni multimedia en Git.

## Registro individual

- **D-34 — ❌:** Nuevo perfil público aportado por el usuario: navegador anónimo confirma foto, enlaces de publicaciones/Reels y destacadas; ZEUVE analiza sin sesión y termina con 0 elementos, «Activa más secciones» y descarga deshabilitada. Se mantiene fallo de catálogo/presentación, ahora con origen público accesible contrastado. Evidencia public-profile-result.txt; no se atribuye todavía la causa completa a la app o al bloqueo del extractor.

- **D-11 — ⚠️:** Contraste del mismo perfil: un enlace concreto de publicación pública resuelve 17 elementos por Catálogo de Instagram sin sesión; la cuadrícula muestra fotos y vídeo. No se realiza nueva descarga ni se acepta catálogo de perfil por este éxito. Todos los tipos de catálogo están activos en Ajustes (Fotos/Vídeos/Reels/Stories/Destacadas/Foto de perfil); el aviso «Activa más secciones» del perfil vacío no corresponde a filtros desactivados. Evidencias public-profile-concrete-post.txt y public-profile-catalog-settings.txt.

- **D-11 — ⚠️:** Segundo contraste del mismo perfil: enlace directo de Reel resuelve 1 elemento clasificado Reel, seleccionado y descargable, sin sesión. El log confirma elementos_unicos=17 para publicación mixta y =1 para Reel, mientras la consulta de perfil registra request_blocked y fallback vacío. Confirma rutas concretas operativas y bloqueo específico del recorrido de catálogo; no acepta D-40/D-41 del perfil por mostrar contenido desde enlaces independientes. Evidencia public-profile-concrete-reel.txt.

- **D-37 — ✅:** Contraste adicional con Reel del nuevo perfil: descarga desde UI sin sesión, 1 correcto/0 omitidos/0 fallidos y 1 archivo publicado bajo Instagram/perfil/Reels. FFprobe: H.264 720×1280/AAC, 23,635057 s, 5.573.473 bytes. Decodificación íntegra de vídeo/audio con FFmpeg incluido, exit 0; SHA-256 0797d638f27c0202929b2a296c14030dc5da9f93b1f1b6da64758ba9f7eca272. Se conserva aceptación de enlace concreto, no de listado de Reels del perfil (D-41). Evidencia public-profile-reel-download.txt.

## Resultado y punto de continuación

El perfil aportado sí sirve como fixture de publicaciones/Reels/foto: su contenido es visible anónimamente en navegador. No desbloquea, sin embargo, el recorrido de perfil de ZEUVE: el log del motor registra `request_blocked` con sesión aportada no y resultado 0; el fallback tampoco entrega catálogo utilizable. Las seis secciones están activadas. Por tanto, el consejo de activar secciones no explica este vacío. La publicación concreta resuelve 17 elementos y el Reel concreto se analiza, descarga y decodifica íntegramente sin sesión. No se afirma que toda consulta Instagram falle ni que el perfil esté vacío o sea privado.

La evidencia apunta a la consulta de perfil usada por los motores y a la presentación del fallo/fallback, no a un enlace inexistente ni a falta de publicaciones. Que un navegador pueda ver el perfil no demuestra que Instagram permita los mismos endpoints del extractor; no se atribuye todo el rechazo remoto a ZEUVE ni se evade ninguna limitación. No se cambia código, motores o comportamiento para obtener un resultado distinto.

**D-40/D-41/D-42/D-43/D-56 siguen sin ejecución efectiva**: sin catálogo no se comprueban sus secciones ni cursor/Cargar más. Mostrar publicaciones y un Reel mediante enlaces independientes no acepta su listado dentro del perfil. D-45/D-49–D-51 continúan bloqueadas por el panel de sesión ausente, fuera de este nuevo contraste anónimo. No hace falta pedir otro perfil simplemente por falta de contenido: este ya confirma el requisito de fixture público; sigue pendiente resolver el bloqueo del catálogo para continuar esas pruebas.

No se cambia el estado de ningún ID: **639 requisitos; 613 OK, 9 fallidos, 8 parciales, 9 pendientes; 630 ejecutados**. Se añaden regresiones/evidencia a D-34 (fallido), D-11 (parcial) y D-37 (OK), guardadas una por una. La nueva descarga no equivale a revalidación general en Release.

Cierre operativo: se descarta el resumen y se cierra la app normalmente, exit 0; no quedan app QA ni motores. Pestaña anónima creada para QA cerrada, Brave intacto. Sin importación de cookies ni item de Llavero (exit 44 antes y después). El Reel nuevo queda solo en QA, sumando 45 archivos publicados; no se elimina ni altera ninguno anterior. Se conservan capturas AX externas sin valores de TextEditor y metadata técnica, no logs brutos ni multimedia en Git.

Incidencia de control: el primer comando de verificación de vídeo no llegó a FFmpeg porque zsh interpretó el `?` del mapa de audio como patrón. Se repite con argumento citado y se completa la decodificación exit 0; no es un fallo de la descarga ni del motor.
