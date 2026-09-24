# Limpiador — privacidad y archivos

## Principio de autorización

El Limpiador es la excepción de mantenimiento aprobada a la regla general de “solo ubicaciones elegidas”, pero la excepción se aplica únicamente al **análisis** de ubicaciones locales concretas y documentadas.

**Poder analizar no equivale a poder eliminar.**

Toda eliminación sigue esta secuencia: descubrimiento → análisis → plan visible → selección explícita → revalidación → ejecución → verificación.

Los permisos de manifiesto `scanLocalStorage` y `removeLocalItems` describen estas dos capacidades de forma separada. No amplían los permisos de los demás módulos.

## Procesamiento local

El Limpiador no declara `networkAccess`, no contiene clientes HTTP, no descarga reglas y no envía inventarios, rutas ni resultados. No usa telemetría, analytics ni cloud.

El inventario SQLite, decisiones `Conservar` y Undo permanecen en el almacenamiento local de ZEUVE. El historial global registra resultados agregados y no necesita cientos de rutas privadas en su payload visible.

## Rutas inspeccionadas

V1 puede leer de forma dirigida ubicaciones como `~/Library/Caches`, `Logs`, `Preferences`, `Application Support`, `Containers`, `Group Containers`, `Saved Application State`, `Application Scripts`, `LaunchAgents`, y los equivalentes de inicio en `/Library` cuando son accesibles. No recorre indiscriminadamente `/System`.

El inventario de aplicaciones usa `/Applications`, `~/Applications`, `NSWorkspace`, Spotlight verificado y ubicaciones adicionales expresamente configuradas.

## Full Disk Access

ZEUVE no presupone Acceso total al disco. Una ruta inaccesible reduce la cobertura y debe mostrarse como análisis parcial; ausencia de acceso nunca se interpreta como ausencia de residuos. La UI puede abrir el apartado de privacidad de Ajustes del Sistema, pero ZEUVE no concede permisos por sí mismo.

Una búsqueda Spotlight incompleta también reduce la cobertura. En ese caso el inventario histórico conserva su estado anterior y los elementos de aplicaciones previamente instaladas se tratan de forma conservadora en la asociación. La ausencia de una app en un análisis parcial no demuestra que se haya desinstalado.

## Enlaces simbólicos

Los recorridos recursivos no siguen symlinks. Si el propio enlace es candidato, la operación se aplica al enlace y nunca a su destino.

## Datos persistentes y compartidos

Preferences, Application Support, Containers, Group Containers, bases de datos, partidas, documentos, configuraciones y plugins se consideran potencialmente persistentes. No forman parte de la selección automática segura.

Los App Groups compartidos por otra aplicación instalada se bloquean. Si una aplicación estaba en un volumen externo actualmente ausente, se clasifica como `Aplicación actualmente no disponible` y sus datos no se convierten automáticamente en residuos.

## Papelera, permanente y revalidación

Papelera es el default. Borrado permanente es una preferencia explícita, no tiene Undo y nunca se presenta como secure erase. Justo antes de cada operación se vuelve a comprobar el objeto mediante fingerprint y guardas; un cambio produce `Omitido por seguridad` sin hacer fallar necesariamente todo el lote.

## Privilegios

V1 no usa `sudo`, `/bin/sh`, `SMJobBless`, XPC root ni helper privilegiado. Los elementos que requieren administrador se informan y se omiten.
