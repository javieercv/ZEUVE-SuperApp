# Informe de implementación — ZEUVE 0.9.2

Fecha: 4 de agosto de 2026.

## Objetivo

Reducir el tiempo real empleado por el Descargador universal cuando un vídeo no procede de YouTube y ha sido descubierto al analizar una página. La corrección no retrasa ni maquilla el estado «Descargando»: elimina trabajo repetido, aumenta el paralelismo útil en contenidos segmentados y evita copiar de nuevo archivos completos al publicarlos en Descargas.

## Cambios implementados

### Reutilización de la referencia ya resuelta

El parser conserva temporalmente la URL directa del archivo, el manifiesto HLS/DASH, el protocolo, la extensión, la caducidad y las cabeceras necesarias devueltas por yt-dlp. `YouTubeDownloadItem` recibe esta referencia y `YouTubeDownloadService` la utiliza directamente al iniciar la descarga.

La URL estable de la página permanece como respaldo. Si la referencia efímera ha caducado o falla, el workspace propio se limpia y se vuelve a resolver únicamente ese vídeo. YouTube y los enlaces directos mantienen su flujo anterior.

### Privacidad de URLs y cabeceras

`YouTubeResolvedMediaReference` implementa una codificación deliberadamente incompleta: la URL multimedia y las cabeceras existen solo en memoria y no forman parte del JSON codificado. No se guardan en ajustes, presets, historial o registros. Las cabeceras `Cookie` y `Proxy-Authorization` no se aceptan desde la respuesta analizada; cookies y proxy continúan usando los mecanismos aprobados por operación.

Los argumentos visibles se redactan para ocultar cookies, proxy y todas las cabeceras añadidas.

### HLS/DASH adaptativo

Se incorpora `YouTubeAdaptiveFragmentPolicy`. Los vídeos segmentados descubiertos en páginas comienzan con 16 fragmentos simultáneos. Si yt-dlp informa de limitación, timeout, reinicio de conexión o fallo de fragmentos, el intento se repite de forma segura con 8, 4 y finalmente 1. Un éxito fija el techo estable para los siguientes vídeos de la misma operación.

La opción está activa por defecto, puede desactivarse y dispone de ayuda contextual tanto en la operación como en Ajustes. Al desactivarla se conserva el control manual existente.

### Publicación sin segunda copia en el mismo volumen

`YouTubeOutputPublisher` determina si el temporal y la carpeta de salida pertenecen al mismo volumen. Cuando coinciden, mueve el archivo a un nombre temporal oculto y después al nombre final; ambas operaciones son renombrados del sistema de archivos y no vuelven a leer y escribir todo el vídeo.

Cuando no puede demostrarse que sea el mismo volumen, mantiene la copia segura anterior, valida el tamaño y publica mediante staging. Las políticas de renombrar, omitir y reemplazar confirmado permanecen intactas.

### Menos comprobaciones repetidas

La validación FFprobe realizada al incrustar procedencia comprueba también la duración multimedia. Los archivos que ya superaron esa comprobación no se vuelven a validar inmediatamente.

### Progreso y diagnóstico

Se añaden fases diferenciadas de conexión, inserción de procedencia y verificación. Los logs locales de rendimiento registran duración, bytes, tiempo hasta el primer byte, número de fragmentos y método de publicación, sin incluir URLs firmadas ni cabeceras.

## Compatibilidad

- Sin nuevas dependencias, APIs o motores.
- Sin cambios en el funcionamiento aprobado de YouTube.
- Sin cambios en la calidad original de los vídeos encontrados en páginas.
- Ajustes antiguos sin el nuevo campo se decodifican con aceleración adaptativa activada.
- El identificador del módulo permanece `com.zeuve.universal-downloader`.

## Archivos principales

Nuevos:

- `Sources/YouTubeDownloaderModule/Operations/YouTubeAdaptiveFragmentPolicy.swift`
- `Docs/IMPLEMENTATION_REPORT_0.9.2.md`
- `Docs/TEST_RESULTS_0.9.2.md`
- `Docs/DELIVERY_0.9.2.md`

Modificados:

- modelos, parser, análisis, comandos, descarga, temporales, publicación y metadatos del Descargador universal;
- ViewModel, vista, Ajustes y ayuda contextual;
- pruebas Swift y Python relacionadas;
- manifiesto, versión, proyecto Xcode, scripts de generación y verificación;
- README, changelog, decisiones y documentación principal.

## Fuera de alcance

No se añade navegador automatizado, no se rastrean subpáginas, no se elude DRM y no se modifica el servidor del que procede el vídeo. La velocidad final también depende de la capacidad y límites de dicho servidor.
