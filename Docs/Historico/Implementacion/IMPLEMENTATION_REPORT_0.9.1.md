# Informe de implementación — ZEUVE 0.9.1

## Alcance aprobado

Esta entrega modifica únicamente el Descargador universal y su integración directa en Ajustes, documentación y pruebas. No añade motores, dependencias, APIs, telemetría ni navegación automatizada.

## Política por procedencia

Los modelos de análisis y descarga incorporan una procedencia explícita por elemento:

- `directContent`: URL concreta de vídeo, audio o colección introducida directamente;
- `pageDiscovered`: vídeo encontrado durante el análisis de una página web.

Los elementos directos mantienen formato, resolución, audio, HDR, selección exacta, subtítulos, metadatos, miniaturas y presets. Los encontrados en páginas ignoran esas opciones y usan el selector original `bestvideo*+bestaudio/best`, sin formato de unión forzado ni recodificación. En operaciones mixtas cada elemento conserva su propia política.

## Nombres

`YouTubeFilenamePolicy.pageDiscoveredBaseNames` sanea los títulos de los vídeos encontrados en páginas, retira sufijos técnicos repetitivos y crea nombres consecutivos. Cuando un título aparece varias veces, todos los resultados se numeran desde `(1)`, incluido el primero. El comando de yt-dlp usa el nombre fijo calculado y no añade el ID del extractor.

## Procedencia opcional

Se añaden tres opciones persistentes y modificables por operación, desactivadas por defecto:

- incrustar URL limpia, dominio e ID de página en el contenedor;
- añadir fecha de descarga;
- aplicar el atributo «De dónde» de macOS.

La inserción interna usa FFmpeg con `-map 0`, `-map_metadata 0` y `-c copy`. FFprobe verifica la presencia de la URL saneada antes de sustituir el temporal. Si el formato no lo admite, se conserva el vídeo descargado sin cambios y se añade una advertencia. No se crean archivos laterales JSON.

El atributo de macOS utiliza `com.apple.metadata:kMDItemWhereFroms` y es independiente de los metadatos internos. Un error de atributos extendidos no invalida la descarga.

## Privacidad

La procedencia se deriva siempre de la página introducida, nunca del MP4 temporal, manifiesto firmado o CDN. La normalización elimina seguimiento, tokens, firmas, caducidades, fragmentos y parámetros temporales conocidos. No se guardan cookies, cabeceras, credenciales de proxy ni comandos completos.

## Interfaz

Cuando solo hay vídeos de una página, se ocultan presets, modo vídeo/audio, resolución, formato, HDR, flujos exactos, subtítulos y archivos auxiliares. Permanecen disponibles carpeta, conflictos, agrupación, cookies, proxy, reintentos, fragmentos simultáneos, red local y registros.

En operaciones mixtas se muestran las opciones directas junto con un aviso de que solo afectan a los enlaces directos. Las opciones de procedencia aparecen en una tarjeta propia y también en Ajustes. Todas las opciones técnicas nuevas utilizan el componente compartido de ayuda contextual `(i)`.

## Compatibilidad

Los datos antiguos decodifican las nuevas opciones de procedencia como desactivadas. Los presets conservan estas opciones de la operación actual cuando se aplican, evitando que un preset antiguo las modifique silenciosamente.
