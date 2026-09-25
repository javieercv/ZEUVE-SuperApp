# Seguridad y privacidad — ZEUVE 0.20.5.0

## Principio general

ZEUVE minimiza datos, acceso y persistencia. No incluye telemetría, analítica ni anuncios. Una función que no necesita red debe seguir siendo local; una función con red debe limitarla a la operación solicitada.

## Red

El Descargador universal es la principal superficie de red en uso normal y declara `networkAccess`. La preparación de motores puede usar red durante desarrollo, pero no es un comportamiento silencioso de la app instalada. Los demás módulos actuales trabajan localmente salvo apertura explícita de recursos externos mediante APIs del sistema cuando su permiso lo contempla.

No se añaden comprobaciones automáticas de actualizaciones de motores ni descargas en segundo plano.

## Sesiones, cookies y secretos

Cookies, tokens, cabeceras privadas y credenciales no deben persistirse en logs, historial, presets o favoritos. La importación de sesión del navegador solo puede ocurrir tras acción expresa y para un flujo que la admita. ZEUVE no solicita contraseñas ni intenta evadir controles de acceso.

## Procesos externos

Los motores se ejecutan con executable y argumentos separados/validados mediante infraestructura aprobada. Está prohibido usar `/bin/sh` o construir comandos interpolados con datos del usuario. La cancelación debe terminar procesos y grupos sin dejar tareas huérfanas.

## Motores y firma

`Resources/Engines/engines.json` es la fuente de la instantánea empaquetable actual. Los motores obligatorios son yt-dlp, Deno, FFmpeg, FFprobe, gallery-dl e instaloader-zeuve. Pandoc puede ser opcional. Deno conserva su firma oficial y entitlements JIT; las políticas concretas de firma y verificación están en `Docs/Motores/` y scripts de build.

Calibre, Ghostscript y LibreOffice están retirados y no deben reaparecer por dependencia accidental.

## Archivos originales

Regla general: leer originales y producir salidas nuevas. Cuando una operación necesite modificar la disposición de archivos —por ejemplo Organizador o Limpiador— debe ser precisamente la función aprobada y debe ofrecer plan/revisión, conflictos, cancelación y protecciones específicas.

Para resultados nuevos:

- usar temporales propiedad de la operación;
- revalidar fingerprints/entradas cuando proceda;
- no seguir symlinks de forma que amplíe silenciosamente el alcance;
- resolver conflictos antes de publicar;
- no sobrescribir silenciosamente;
- limpiar solo temporales verificablemente propios.

## Excepciones aprobadas de alcance local

El Limpiador declara `scanLocalStorage` y puede **analizar** ubicaciones locales documentadas aunque no hayan sido seleccionadas una a una. Esa excepción no autoriza a modificar. Eliminar/mover exige `removeLocalItems` y la secuencia descubrimiento → análisis → plan visible → selección explícita → revalidación → ejecución. Si inventario o decisiones «Conservar» no pueden leerse de forma fiable, el plan se detiene en vez de asumir que esas protecciones no existen.

El Organizador mueve originales porque esa es su función explícita, siempre desde la carpeta escogida/arrastrada y después de planificar las operaciones.

## Historial, logs y ajustes

- Logs: diagnósticos mínimos; no URLs firmadas completas, headers, tokens, cookies, listas privadas o contenido sensible.
- Historial: estado, contadores y metadata operativa mínima; evitar rutas y contenido innecesarios.
- Ajustes: preferencias técnicas y de UX, no secretos.
- Favoritos/presets: configuración reutilizable, no rutas privadas salvo una decisión específica y justificada.

## Bookmarks y acceso persistente

Los módulos que declaran `persistentFolderAccess` pueden conservar acceso a carpetas expresamente autorizadas según el mecanismo aprobado. Un fallo del entorno de bookmarks debe distinguirse de una ruta realmente ausente; no se debe ampliar acceso como workaround.

## Archivos comprimidos

Las importaciones deben impedir path traversal, rutas absolutas, colisiones normalizadas y expansiones inseguras. Para datasets grandes deben usarse límites y procesamiento incremental cuando proceda.

## Privacidad por módulo

- Organizador: local; mueve archivos elegidos, sin red.
- Descargador: red explícita; sesiones minimizadas y controladas.
- Analizador de chats: contenido local; no registrar mensajes.
- Conversor: local; salidas seguras y originales intactos.
- Comparador Instagram: procesa la exportación local, sin login ni scraping.
- Inspector: análisis/preview/edición local; OCR no entra en logs/informes como contenido textual.
- Limpiador: análisis local amplio pero conservador; eliminación siempre explícita/revalidada.

## Plataforma

La app usa Hardened Runtime. No está dentro de App Sandbox en 0.20.5.0; por ello las protecciones de alcance, validación, permisos internos y UI no pueden delegarse al sandbox.
