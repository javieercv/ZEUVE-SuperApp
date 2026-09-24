# Privacidad y red del Descargador universal 0.7.3

## Reglas personalizadas por dominio

Al crear una plataforma personalizada, ZEUVE acepta un enlace como ayuda de entrada pero guarda solo el dominio normalizado. Se eliminan usuario, contraseña, puerto, ruta, parámetros y fragmento antes de persistir. La resolución posterior utiliza el origen estable de la página, no referencias multimedia firmadas ni hosts de CDN encontrados durante el análisis.

Los perfiles no contienen cookies, sesiones, credenciales, proxy, carpeta de salida ni identificadores exactos de pistas. Estas opciones continúan limitadas a la operación actual y mantienen las reglas generales de minimización.

## Cuándo se usa Internet

La red solo se activa tras una acción expresa de análisis, descarga, búsqueda histórica o importación de sesión desde navegador. El resto de ZEUVE continúa funcionando offline.

## Destinos de red

Cada operación contacta únicamente con la URL introducida, sus servidores multimedia necesarios y, cuando se solicita una búsqueda histórica, Wayback Machine. Los motores pueden seguir redirecciones necesarias del servicio. No existe telemetría, publicidad, analítica ni informe automático de errores.

## Sesiones y cookies

- Desactivadas por defecto.
- Se aceptan únicamente por acción del usuario.
- Una cabecera pegada se convierte también a un archivo Netscape temporal para que los motores aprobados puedan reutilizarla.
- Los temporales usan directorios 0700 y archivos 0600.
- La sesión temporal se elimina al sustituirla, cerrar la app o limpiar la operación.
- La opción «Recordar» utiliza el Llavero de macOS.
- No se registran nombres o valores de cookies, tokens, cabeceras, contraseñas o URLs firmadas.

Los enlaces concretos públicos de Instagram se analizan y descargan anónimamente incluso cuando existe una sesión temporal o recordada. La secuencia pública es `instaloader-zeuve` → `gallery-dl` → `yt-dlp` → descubrimiento genérico. ZEUVE no pasa `--cookies`, `--cookies-from-browser` ni una cabecera Cookie durante esos intentos. Solo el contenido confirmado como privado o restringido puede activar una sesión ya autorizada. Los mensajes ambiguos de login, rate limit o bloqueo del extractor no se consideran confirmación de privacidad.

Las URLs multimedia firmadas que devuelve la resolución específica de Instagram permanecen en memoria y se consumen mediante una sesión efímera. El nombre final usa el formato expuesto por el CDN y el `Content-Type` realmente recibido; no se guarda la URL firmada en historial, registros, presets o metadatos.

Los vídeos públicos de YouTube utilizan por defecto clientes públicos anónimos de yt-dlp y no leen cookies ni almacenes del navegador. La importación desde navegador solo se ejecuta cuando el usuario la activa expresamente para contenido realmente restringido y puede requerir permisos de macOS. yt-dlp lee entonces la sesión del navegador elegido durante esa operación, sin copiarla a ZEUVE ni conservar la selección en ajustes, presets, historial o registros. Un `cookies.txt` seleccionado manualmente tiene prioridad. ZEUVE no pide la contraseña.

Los enlaces públicos de TikTok se vuelven a resolver desde su página estable durante la descarga. `gallery-dl` puede probar varias rutas temporales del CDN; si falla o termina vacío, el respaldo con el `yt-dlp` incluido reutiliza únicamente la misma URL pública estable. Las URLs firmadas solo existen durante la operación y no se codifican en planes persistidos, historial, metadatos ni registros. Los registros del respaldo conservan solo el motor, cantidades, resultado y referencia técnica saneada.

Los dos motores sociales empaquetados con PyInstaller reciben una autorización de firma limitada a sus propios procesos para cargar el framework Python que extraen temporalmente. Esta excepción no se aplica a `ZEUVE.app`, no habilita red adicional y no cambia el acceso a archivos del usuario.

## Contenido adulto

El control está desactivado por defecto. Los dominios identificados se bloquean antes de descargar HTML, miniaturas o multimedia. El usuario debe activar explícitamente el permiso desde Ajustes. Los dominios adicionales se guardan localmente.

## Wayback Machine

La búsqueda histórica es manual y envía el nombre o URL pública del perfil a Internet Archive. Se realiza mediante una sesión `URLSession` efímera dedicada, sin caché ni almacenamiento persistente de cookies, con timeout de petición de 30 segundos y de recurso de 120 segundos. Se informa de que los resultados pueden ser incompletos y no se ejecutan comprobaciones automáticas en segundo plano.

## Navegador opcional

En 0.7.3 el fallback automatizado se encuentra temporalmente deshabilitado y no participa en el routing. Ajustes conserva una sección informativa heredada llamada «Navegador opcional», pero no ofrece un selector, instalador ni activación funcional del navegador. Se conserva únicamente la compatibilidad de lectura de la preferencia histórica, que se normaliza a desactivada. No se descarga, instala ni ejecuta un navegador automatizado y no cambia ninguna política de CAPTCHA, DRM o controles de acceso.

## Registros e historial

Los registros contienen fases, cantidades, motores, tiempos y errores técnicos saneados. El historial conserva identificadores canónicos y resultados, pero no URLs completas, cookies, sesiones o texto privado de publicaciones.


## Saneamiento interno 0.7.3

La reorganización de nombres, carpetas y responsabilidades no modifica la política de red ni privacidad. Continúan sin cambiar el routing, los argumentos de motores, la prioridad de sesiones, las restricciones DRM/CAPTCHA/paywall, la redacción de logs, la ausencia de telemetría y la prohibición de persistir URLs firmadas, cookies, tokens, cabeceras o credenciales.
