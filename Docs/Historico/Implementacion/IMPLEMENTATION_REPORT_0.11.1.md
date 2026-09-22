# Informe de implementación — ZEUVE 0.11.1

Fecha: 21 de agosto de 2026.

## Objetivo aprobado

Restaurar la descarga de vídeos públicos de YouTube sin que el usuario tenga que activar una sesión de Safari, Chrome u otro navegador, usando el enlace `https://www.youtube.com/watch?v=BM1evFP2fds` como caso real de regresión.

## Causa comprobada

El análisis anónimo terminaba correctamente, pero la transferencia completa con el cliente predeterminado de yt-dlp recibía HTTP 403. Además, el plan conservaba una URL multimedia firmada de `googlevideo` obtenida durante el análisis y podía intentar reutilizarla en la descarga. El clasificador convertía cualquier 403 o aviso de PO token en una petición de sesión del navegador, aunque el vídeo fuese público.

## Cambios realizados

- Análisis y descarga de YouTube sin sesión añaden automáticamente `youtube:player_client=web_embedded,web_safari`.
- Cuando existe una sesión elegida expresamente, ZEUVE mantiene el comportamiento privado y no impone la cadena anónima.
- La descarga anónima vuelve a resolver el enlace estable de YouTube en lugar de reutilizar la URL multimedia firmada del análisis.
- HTTP 403 se clasifica como rechazo de red y los avisos de PO token como ausencia de formato público compatible; ninguno exige por sí solo una sesión.
- Se añaden regresiones para análisis, descarga, otras plataformas, sesiones expresas y mensajes de error.
- Deno conserva su firma oficial y sus autorizaciones Hardened Runtime para JIT. La fase de empaquetado restaura la copia oficial incluso en compilaciones incrementales y ejecuta JavaScript real antes de aceptar el paquete.
- La compilación por Terminal parte de un producto limpio y verifica la firma profunda final de `ZEUVE.app`.
- ZEUVE se eleva a 0.11.1, build 37, y el Descargador universal a 0.6.5.

## Privacidad y dependencias

La ruta predeterminada no lee cookies ni almacenes del navegador. No se incorporan motores, servicios, plugins, APIs, proxies, tokens externos ni telemetría. Las sesiones permanecen como una opción manual para contenido que confirme una restricción real.
