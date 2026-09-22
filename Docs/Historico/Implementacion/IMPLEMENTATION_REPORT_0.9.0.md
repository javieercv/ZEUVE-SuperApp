# Informe de implementación — ZEUVE 0.9.0

Fecha: 4 de agosto de 2026.

## Resumen

El módulo específico de YouTube se ha convertido en **Descargador universal 0.5.0**. Conserva los motores, la publicación segura, los temporales, los presets, el historial y la cola global existentes, pero amplía el análisis a URLs de distintas plataformas, archivos multimedia directos, colecciones y páginas web concretas con varios vídeos.

## Identidad y migración

- Nuevo identificador: `com.zeuve.universal-downloader`.
- Identificador heredado de lectura: `com.zeuve.youtube-downloader`.
- ZEUVE: 0.8.0 → 0.9.0.
- Build: 27 → 28.
- Módulo: 0.4.1 → 0.5.0.

Los ajustes y el modo avanzado consultan las claves antiguas cuando las nuevas todavía no existen y guardan el valor normalizado bajo las claves universales. Presets y bookmark de salida realizan la misma migración. El historial global presenta las operaciones anteriores con el nombre e icono del Descargador universal y el filtro del módulo reúne ambos identificadores.

## Análisis universal

Se ha sustituido la validación cerrada de dominios de YouTube por una validación de URL universal:

- HTTPS público admitido por defecto.
- HTTP, localhost y rangos privados solo mediante una opción avanzada expresa.
- Canonicalización específica de YouTube conservada para no romper identificadores anteriores.
- Normalización genérica y clave estable para el resto de URLs.

El análisis combina:

1. yt-dlp sobre la URL original.
2. Inspección HTML de la página exacta cuando corresponde.
3. Detección en `video`, `source`, `iframe`, Open Graph/Twitter, JSON-LD y URLs MP4, WebM, MOV, HLS o DASH.
4. Análisis secuencial de cada candidato adicional mediante yt-dlp.
5. Fusión y deduplicación antes de mostrar la selección.

No se siguen enlaces internos y no se ha añadido navegador automatizado, API o dependencia externa.

## Duplicados e historial

- Los duplicados seguros se eliminan únicamente dentro del análisis actual y antes de descargar.
- No se descarga un duplicado para borrarlo después.
- Las coincidencias aproximadas por título y duración se marcan como **Posible duplicado** y permanecen seleccionables.
- Los identificadores encontrados en el historial aparecen como **Ya descargado**, inicialmente desmarcados, pero pueden seleccionarse otra vez.
- El historial no se usa como bloqueo ni como deduplicación automática entre ejecuciones.

## Cookies, red y registros

- `cookies.txt` se valida como archivo Netscape y se filtra por dominio, ruta, seguridad y caducidad durante la inspección HTML.
- La inspección usa una sesión efímera sin caché ni almacén global de cookies.
- El proxy continúa siendo una opción por operación y sus credenciales solo viven en memoria.
- El primer log se escribe al comenzar el análisis, antes de resolver motores.
- Las URLs de registro se sanean y no se guardan cookies, tokens, cabeceras privadas o credenciales.
- Se añade **Abrir carpeta de registros** a la interfaz.

## Interfaz

- Nombre visible actualizado a Descargador universal en navegación, dashboard, menú, Ajustes e historial.
- Texto de entrada adaptado a enlaces individuales, colecciones y páginas con varios vídeos.
- Servicio o dominio visible en los resultados.
- Contadores de duplicados omitidos.
- Estados **Posible duplicado** y **Ya descargado anteriormente**.
- Opción avanzada para HTTP y red local.
- Se elimina `AsyncImage` para que la vista no abra una conexión remota independiente a la miniatura.
- Los errores clasificados se muestran con una explicación útil.

## Descarga y nombres

La descarga mantiene el flujo aprobado: operaciones secuenciales, argumentos separados, temporales propios, FFprobe, publicación atómica, conflictos seguros, cancelación y limpieza verificada.

Se corrige la plantilla **Lista, índice y título**: ahora crea una carpeta basada en el nombre de la colección y no genera exactamente el mismo patrón que **Índice y título**.

## Archivos principales modificados o añadidos

- `Sources/YouTubeDownloaderModule/Models/YouTubeModels.swift`.
- `Sources/YouTubeDownloaderModule/Validation/YouTubeURLValidator.swift`.
- `Sources/YouTubeDownloaderModule/Validation/UniversalURLNormalizer.swift`.
- `Sources/YouTubeDownloaderModule/Validation/NetscapeCookieFile.swift`.
- `Sources/YouTubeDownloaderModule/Discovery/UniversalPageDiscovery.swift`.
- `Sources/YouTubeDownloaderModule/Parsing/YouTubeAnalysisParser.swift`.
- `Sources/YouTubeDownloaderModule/Operations/YouTubeAnalysisService.swift`.
- Servicios de presets, bookmarks, historial, comandos y errores del módulo.
- Vistas, ViewModel, Ajustes, navegación e historial global de `ZEUVEApp`.
- Manifiesto, pruebas, scripts de verificación, proyecto Xcode, versión, changelog y documentación.

No se han eliminado motores, módulos existentes ni funciones aprobadas no relacionadas.

## Validación realizada

- 33 pruebas específicas del Descargador universal superadas.
- Suite completa: 132 pruebas XCTest y 45 pruebas Swift Testing, 177 en total, sin fallos.
- 26 pruebas Python de scripts y políticas superadas.
- Target `YouTubeDownloaderModule` compilado correctamente en Release.
- Manifiestos, documentación y proyecto Xcode regenerado y validados.
- La compilación Release completa de todos los targets fue interrumpida por el límite temporal del entorno; no se presenta como superada.
- La aplicación no se compiló ni abrió de forma nativa en macOS Apple Silicon en este entorno.
