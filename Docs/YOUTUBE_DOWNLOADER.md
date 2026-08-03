# Descargador de YouTube 0.4.0

## Identidad del módulo

- ID: `com.zeuve.youtube-downloader`
- Nombre: Descargador de YouTube
- Tecnología: `mixed`
- Modo: `builtIn`
- API de módulos: 1.0
- Versión mínima de ZEUVE: 0.2.0

## Flujo de uso

1. Introducir uno o varios enlaces.
2. Validar y eliminar duplicados.
3. Analizar sin iniciar la descarga.
4. Revisar vídeo, playlist, formatos, subtítulos y disponibilidad.
5. Elegir modo simple o avanzado.
6. Seleccionar elementos, carpeta, nombre y opciones.
7. Revisar el resumen.
8. Descargar con progreso real y cancelación.
9. Consultar el resumen, historial y carpeta de salida.

## Análisis

El análisis utiliza yt-dlp con salida JSON estructurada. Para playlists grandes se solicita una secuencia plana e incremental. No se cargan miniaturas ni formatos completos de todos los elementos. El usuario puede cancelar el análisis.

Los directos activos o futuros aparecen con una explicación y no pueden añadirse al plan. Los directos finalizados se tratan como vídeo normal cuando yt-dlp permite acceder a ellos.

## Descarga

Las URLs se procesan secuencialmente. Un fallo aislado se registra y no detiene el resto cuando continuar es seguro. El módulo utiliza el coordinador global, por lo que otro módulo pesado no puede comenzar simultáneamente.

### Modo simple

- Vídeo o solo audio.
- Mejor calidad o resolución máxima.
- Formato de vídeo Automático, MP4, MKV o WebM; MP4 es el valor predeterminado.
- Formato de audio MP3, M4A, FLAC, WAV, Opus o flujo original; MP3 es el valor predeterminado.
- Para MP3, bitrate seleccionable de 128, 192, 256 o 320 kbps; 320 kbps es el valor predeterminado.
- Carpeta de salida y nombre seguro; Título es el nombre predeterminado.

### Modo avanzado

- Streams exactos de vídeo y audio.
- Resolución, FPS, codec, HDR/SDR y contenedor.
- Audio original, M4A, MP3, FLAC, WAV u Opus, con bitrate MP3 configurable.
- Subtítulos manuales o automáticos, idioma, conversión e inserción.
- Metadatos, miniatura, descripción, capítulos y fechas.
- Proxy, reintentos, timeout, fragmentos y límite de velocidad.

No existe un campo de argumentos personalizados de yt-dlp.

## Playlists

- Vista previa.
- Selección individual.
- Selección por intervalo.
- Preservación del orden.
- Numeración opcional.
- Carpeta por playlist.
- Continuación tras elementos no disponibles.
- Resumen de correctos, omitidos, fallidos y cancelados.

La lista SwiftUI es virtualizada y el parser conserva únicamente el fragmento de línea pendiente, no toda la salida.

## Temporales y resultados

Cada elemento usa un espacio de trabajo propio con marcador de propiedad. yt-dlp descarga dentro de ese espacio. FFprobe valida los archivos multimedia antes de publicarlos. Los archivos auxiliares se publican junto con el resultado y los `.part` quedan excluidos.

Ante conflictos:

- renombrar automáticamente es el valor predeterminado;
- omitir conserva el archivo existente;
- reemplazar solo se utiliza después de confirmación explícita.

## Historial

El historial guarda:

- título;
- IDs canónicos;
- tipo de contenido;
- modo y resumen de formato;
- contadores;
- duración;
- cancelación;
- referencias técnicas.

No guarda URLs completas, cookies, tokens, cabeceras, proxy con credenciales ni comandos.

## Ajustes del módulo

La configuración persistente se administra únicamente desde:

```text
Ajustes > Descargador de YouTube
```

La sección dispone de tres apartados:

- **Predeterminados:** formato, calidad, nombre, metadatos, subtítulos y red para operaciones nuevas.
- **Presets:** creación, edición, favoritos, duplicado, eliminación y restauración.
- **Diagnóstico:** estado de yt-dlp, Deno, FFmpeg y FFprobe y comprobación manual forzada.

Dentro del Descargador no hay una rueda de ajustes ni botones independientes de configuración. Solo permanece un selector rápido para aplicar un preset a la operación actual. El proxy, las cookies y las selecciones exactas de pistas siguen siendo opciones por operación y no se guardan como valores generales.

## Presets incluidos

- Mejor calidad compatible.
- Vídeo 1080p.
- Vídeo 720p.
- Audio M4A.
- Audio MP3 320 kbps.
- Lista de reproducción completa.
- Vídeo con subtítulos en español.

Cada preset tiene versión de esquema, UUID, nombre, configuración, favorito y fecha de modificación. No puede contener secretos ni argumentos libres.

## Ayuda contextual

Las opciones técnicas muestran un icono `info.circle`. Al pulsarlo se abre una explicación en español sobre el efecto de la opción y, cuando corresponde, una recomendación. Se cubren resolución, formato de vídeo, formato y calidad de audio, flujos exactos, metadatos, subtítulos, proxy, reintentos, fragmentos simultáneos, cookies, nombres y conflictos.

El componente es compartido con el Organizador y Ajustes, funciona en claro y oscuro y ofrece una etiqueta accesible para VoiceOver.

## Diagnóstico

Muestra en español:

- nombre y versión esperada;
- arquitectura;
- integridad;
- permisos;
- versión detectada;
- dependencias dinámicas;
- archivo o licencia ausente;
- fallo de ejecución.

## Limitaciones de la versión

- Solo YouTube.
- Sin descarga de directos activos o futuros.
- Sin cookies directas de navegador.
- Sin DRM.
- Sin actualización automática.
- Los cambios de YouTube pueden requerir una nueva versión de ZEUVE con motores actualizados.
