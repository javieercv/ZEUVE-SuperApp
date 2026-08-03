# Decisiones aprobadas de ZEUVE

Fecha de consolidación: 30 de julio de 2026. Actualizado para ZEUVE 0.7.5.

## Plataforma
- Aplicación nativa para macOS.
- Apple Silicon ARM64.
- macOS 14 Sonoma como versión mínima inicial.
- No se prepara todavía una versión para Windows, Linux o Mac Intel.

## Interfaz
- Diseño minimalista, coherente y con estilo macOS.
- Toda la interfaz visible estará en español.
- Modo claro, oscuro o según el sistema.
- Las herramientas ofrecerán modos simple y avanzado cuando tenga sentido.


## Interfaz y ayuda contextual 0.3.0
- Las opciones técnicas o ambiguas muestran un icono nativo `info.circle` junto a su nombre.
- Al pulsarlo se abre una explicación en español sencillo con consecuencias y recomendación cuando corresponda.
- El componente es común, accesible mediante teclado y VoiceOver, y compatible con los modos claro y oscuro.
- El sistema se aplica al Descargador, Organizador y Ajustes, y deberá reutilizarse en módulos futuros.
- No se añaden iconos informativos a acciones completamente evidentes para evitar ruido visual.


## Ajustes centralizados 0.4.0
- Todos los ajustes persistentes se administran desde el apartado general Ajustes.
- Ajustes ofrece una sección General y una sección propia para cada módulo configurable.
- El Organizador y el Descargador no muestran ruedas ni botones independientes de configuración.
- Las opciones de la operación actual permanecen dentro de la herramienta; los valores predeterminados se guardan en Ajustes.
- El Descargador conserva un selector rápido de presets, pero la creación, edición, eliminación y restauración se realiza en Ajustes > Descargador de YouTube > Presets.
- El diagnóstico de motores se encuentra únicamente en Ajustes > Descargador de YouTube > Diagnóstico.
- Cambiar valores predeterminados no modifica silenciosamente operaciones ya preparadas o en curso.
- Los módulos futuros deben integrarse en este mismo sistema y no crear ajustes independientes sin aprobación.

## Valores predeterminados del Descargador 0.3.0
- Vídeo: contenedor MP4 por defecto; en modo simple también se puede elegir Automático, MKV o WebM.
- Audio: MP3 por defecto.
- MP3: 320 kbps por defecto, con opciones 128, 192, 256 y 320 kbps visibles solo al seleccionar MP3.
- Nombre de archivo: Título por defecto, sin añadir el ID.
- Los presets antiguos mantienen sus valores y se migran al esquema 2 sin perder configuraciones.

## Arquitectura
- Swift 6 es la base del núcleo y de la aplicación.
- SwiftUI es la base visual y AppKit cubre integraciones avanzadas de macOS.
- Python, Rust u otros lenguajes pueden utilizarse de forma aislada cuando sean la mejor solución, pero ningún módulo aprobado actualmente depende de una instalación de Python del usuario.
- No se utiliza Flask, pywebview, Electron ni un servidor localhost como base.
- Solo puede ejecutarse una operación pesada principal a la vez.
- Los motores reutilizables se integran mediante `ZEUVEEngines`; la lógica específica permanece dentro de cada módulo.

## Módulos
- ZEUVE se diseña desde el inicio como una plataforma modular.
- Los módulos oficiales utilizan manifiestos, permisos, capacidades y una API versionada.
- La importación de módulos por el usuario se implementará en una versión futura.
- Los módulos externos deberán ejecutarse aislados y comunicarse mediante contratos estables.
- Los módulos nuevos deben seguir la documentación de `Docs/` y partir siempre del ZIP más reciente.
- ZEUVE 0.7.5 incluye el Organizador, el Descargador de YouTube, el Analizador de chats y el Conversor universal.

## Persistencia e historial
- SQLite local sin dependencias Swift externas.
- Ajustes, historial y presets se guardan localmente.
- El historial global se dirige por `moduleID` y obtiene nombre e icono desde el registro de módulos.
- Cada módulo puede aportar su presentador de detalles sin acoplar la vista global a una lista cerrada.

## Privacidad
- Sin telemetría, analítica, publicidad ni comprobaciones automáticas de actualización.
- Procesamiento offline siempre que la función lo permita.
- El Organizador no utiliza Internet.
- El Descargador solo utiliza Internet tras una acción expresa de análisis o descarga.
- No se guardan URLs completas por defecto, URLs firmadas de googlevideo, cookies, tokens, cabeceras ni credenciales.
- Los logs aplican la misma política de minimización.

## Descargador de YouTube 0.4.1
- Identificador: `com.zeuve.youtube-downloader`.
- Tecnología: `mixed`; modo: `builtIn`.
- Múltiples URLs secuenciales, sin descargas pesadas simultáneas.
- Diagnóstico de motores reutilizado durante la sesión, con actualización manual forzada y invalidación si cambian los archivos.
- Caché local privada de yt-dlp en `~/Library/Caches/ZEUVE/yt-dlp`.
- Directos activos o futuros se detectan y no se descargan; los finalizados se tratan como vídeo cuando sea posible.
- Cookies desactivadas por defecto y solo mediante selección manual de `cookies.txt`.
- Proxy opcional por operación; credenciales únicamente en memoria y sin Keychain en esta versión.
- Sin campo de argumentos personalizados de yt-dlp.
- Playlists sin límite arbitrario, con carga incremental y análisis detallado solo cuando sea necesario.
- La carpeta de salida se recuerda mediante bookmarks de seguridad y se vuelve a solicitar si el bookmark no puede resolverse.

## Analizador de chats 0.1.6 (ZEUVE 0.7.4)
- Identificador: `com.zeuve.chat-analyzer`; tecnología `swift`; modo `builtIn`.
- Procesamiento completamente offline de ZIP o TXT de WhatsApp, ZIP completos de Instagram, ZIP de una sola conversación y entradas avanzadas compatibles.
- Se analiza como máximo un chat lógico de WhatsApp y una conversación de Instagram por operación.
- Instagram se cataloga antes de analizar y procesa únicamente la conversación seleccionada. Si solo existe una, queda seleccionada automáticamente sin iniciar el análisis.
- `libarchive` del SDK/sistema se utiliza mediante un puente C mínimo; no se añade un paquete Swift externo.
- SQLite temporal es la fuente de almacenamiento auxiliar y se elimina al cerrar, cancelar o sustituir el análisis.
- Zona horaria predeterminada: California → España. Fechas numéricas ambiguas: día/mes/año.
- Mensajes del sistema se importan y cuentan en totales, pero se excluyen de perfiles y respuestas.
- Multimedia clásica: imagen, vídeo, audio y sticker; los nombres de sticker de WhatsApp prevalecen sobre la extensión WEBP y la definición puede configurarse desde Ajustes.
- Conversaciones predeterminadas: pausa de 3 horas, calculadas sobre la cronología completa y filtradas después.
- Respuestas predeterminadas: ventana máxima de 24 horas; puede elegirse sin límite dentro de la conversación.
- Fusiones, búsquedas y análisis son temporales y no se guardan.
- El historial almacena solo cantidades, plataformas, duración, estado y advertencias.
- Los archivos originales se abren en lectura y los adjuntos no se abren ni se decodifican. En un TXT directo se muestran como no comprobados, no como faltantes.
- El archivo de conversación no tiene límite de tamaño por defecto y se procesa progresivamente cuando el formato lo permite. El usuario puede activar un límite persistente desde Ajustes. Las protecciones estructurales del ZIP siguen siendo obligatorias.
- `Analizar otro chat` cierra la sesión temporal, limpia las fuentes y vuelve inmediatamente a la pantalla inicial del Analizador.
- `Cerrar análisis` cierra la sesión temporal, conserva las fuentes seleccionadas y vuelve inmediatamente a la pantalla inicial del Analizador.
- El cambio entre importación y resultados observa directamente el estado del Analizador y no depende de salir del módulo para actualizarse.
- Las nueve pestañas de resultados incluyen ayuda contextual general y explicaciones específicas en métricas, gráficos, opciones y columnas no evidentes.
- Las estadísticas derivadas se calculan fuera del hilo principal y se publican como instantáneas inmutables para mantener fluida la interfaz.
- Cada pestaña pesada se calcula solo al abrirse y reutiliza su caché mientras no cambien el chat, los filtros, las fusiones o los ajustes de los que depende.
- Los cambios rápidos cancelan cálculos obsoletos y una revisión interna impide publicar resultados pertenecientes a un estado anterior.
- Los filtros esperan brevemente antes de recalcular y la búsqueda aplica una espera de 200 ms; cambiar de página o contexto reutiliza el índice de coincidencias.
- Mientras se actualizan estadísticas se conserva el último resultado válido y se muestra un indicador discreto; nunca se presentan resultados parciales como definitivos.
- Cambiar una opción analítica invalida únicamente las secciones relacionadas y no reconstruye innecesariamente el resumen o los filtros básicos.
- Todos los gráficos de resultados son interactivos mediante hover: muestran el dato exacto y su fecha, periodo, hora o categoría sin requerir clic.
- El tooltip sigue la posición del cursor, cambia automáticamente de lado cerca de los bordes y permanece dentro del área visible del gráfico o mapa de calor.
- En gráficos comparativos el tooltip presenta todas las series visibles y el total conjunto del instante o categoría seleccionado.
- La interacción visual consume únicamente las instantáneas en caché, no recalcula estadísticas ni modifica filtros, mensajes o archivos.
- El mapa de calor utiliza el mismo criterio de resaltado y tooltip que los gráficos de líneas y barras.

## Conversor universal 0.2.2 (ZEUVE 0.7.5)
- Identificador: `com.zeuve.universal-converter`; versión del módulo `0.2.2`; tecnología `mixed`; modo `builtIn`.
- Procesamiento offline de imágenes rasterizadas y vectoriales, animaciones, audio, vídeo, PDF, texto, marcado, datos, libros electrónicos, carpetas y ZIP, limitado siempre a las capacidades realmente disponibles.
- Los lotes pueden mezclar formatos concretos de una misma categoría si todos admiten la operación, salida y ajustes comunes; no se mezclan categorías incompatibles.
- La detección combina extensión, firma, UTI, MIME, estructura contenedora y datos del motor. Una discrepancia queda visible y la extensión nunca prevalece automáticamente sobre evidencia fiable del contenido.
- La matriz central de compatibilidad decide qué conversiones se muestran y registra motor, pérdida, recodificación, copia directa, opciones, limitaciones y disponibilidad.
- Los ZIP se catalogan sin extracción completa, admiten conservar o aplanar estructura y aplican límites configurables de entradas, tamaño, profundidad y relación de compresión.
- Todos los originales se abren en lectura. Antes de publicar, cada salida se compara contra todas las rutas originales del lote y se valida con el motor correspondiente.
- La publicación utiliza temporales y sustitución atómica. La política predeterminada es renombrar; sin prefijo se usa `nombre - converted.ext` y después numeración segura.
- Los preajustes oficiales son Bajo, Medio, Alto, Máxima calidad y Personalizado; Máxima calidad es el valor predeterminado. Las favoritas, preajustes y ajustes portables no guardan entradas, contraseñas ni recursos privados.
- Los metadatos disponen de tres políticas: conservar compatibles, conservar esenciales y eliminar. No se copia contenido activo o peligroso.
- El paralelismo automático es conservador: las operaciones pesadas se serializan y solo las tareas nativas o de copia seguras pueden usar concurrencia limitada. El valor manual está acotado entre 1 y 8.
- Se admite contraseña local para ZIP y PDF compatible con PDFKit. Los formatos ofimáticos se retiraron completamente del Conversor en 0.7.3; CSV permanece como formato genérico de datos.
- Fuentes y modelos 3D quedan fuera de alcance en 0.7.0 por decisión aprobada.
- La experiencia nativa, VoiceOver, ImageIO, PDFKit, VideoToolbox, firma y apertura de la app requieren validación final en macOS Apple Silicon.
- En modo simple, una conversión de vídeo siempre recodifica la pista de vídeo; MP4 automático utiliza H.264. La copia rápida/remux solo puede activarse expresamente en modo avanzado y está desactivada por defecto.
- Los ajustes predeterminados anteriores migran a recodificación real. El preajuste oficial `Vídeo MP4 compatible` también se actualiza, mientras que los preajustes personalizados no se modifican silenciosamente.
- Vídeo → fotogramas escribe directamente en una carpeta visible `Procesando` dentro del destino. Al completar se renombra sin copiar todo el árbol; al cancelar, fallar o recuperar un cierre inesperado se conservan los fotogramas válidos en una carpeta `Incompleto`.
- PNG permanece sin pérdida y utiliza compresión nivel 3 con predictor Up. `tiempos.csv` se crea durante la misma ejecución de FFmpeg y el progreso informa del número real de fotogramas.

## Motores aprobados para 0.7.0
- yt-dlp 2026.06.09 mediante la distribución oficial descomprimida para macOS.
- Deno 2.9.0 oficial para macOS ARM64.
- FFmpeg y FFprobe 8.1.2 compilados para ARM64 con libmp3lame, libopus, libx264 y libwebp estáticos, VideoToolbox y Apple ProRes.
- libx264 está aprobado para H.264 por software. libx265 permanece expresamente excluido.
- Pandoc 3.10 para conversiones de texto y marcado.
- Calibre 9.11.0 para libros electrónicos, integrado como aplicación completa y con su firma oficial conservada.
- Ghostscript 10.07.1 para EPS y flujos PostScript aprobados, ejecutado con modo seguro y recursos locales.
- Ningún motor se descarga durante el uso. Los motores opcionales se consideran `no proporcionados` hasta que `prepare_engines_macos.sh` los genere o copie y registre hashes y tamaños reales.
- No se utiliza Python del sistema, Homebrew, descarga dinámica de componentes, `--remote-components` ni actualización automática.
- Los motores se almacenan una sola vez bajo `Resources/Engines/` y `engines.json` registra versión, arquitectura, SHA-256, procedencia, licencia, función, diagnóstico, tamaño y obligatoriedad.
- SHA-256 y tamaño se verifican durante la preparación y antes del empaquetado. Tras firmar, el diagnóstico comprueba existencia, licencia, permisos, arquitectura, dependencias, lanzamiento y versión sin exigir el hash anterior a `codesign`.

## Simplificación del Conversor 0.7.3
- LibreOffice se elimina por completo del código, registro de motores, preparación, diagnóstico, firma y empaquetado.
- El Conversor deja de admitir Word, Excel, PowerPoint, OpenDocument y RTF como entrada o salida.
- CSV se conserva como formato genérico de datos y para salidas auxiliares.
- El Organizador mantiene sus reglas de clasificación de extensiones porque no convierte ni abre esos formatos.

## Optimización de rendimiento 0.7.4
- El Descargador y el Conversor comparten el registro y la caché de diagnóstico de motores; la caché se invalida si cambian los archivos y la actualización manual forzada se mantiene.
- El Analizador crea el índice normalizado de búsqueda únicamente al utilizar la búsqueda. El índice es temporal, compacto, local y se elimina al cerrar o sustituir la sesión.
- Los índices de búsqueda pequeños se mantienen en memoria y los excepcionalmente grandes utilizan un archivo temporal mapeado dentro del espacio privado de la sesión.
- La caché de búsqueda no altera los criterios, resultados, filtros ni expresiones regulares; si no puede construirse, se conserva la búsqueda directa anterior.
- La escritura de mensajes en SQLite temporal reutiliza una sentencia preparada dentro de una transacción.
- Las actualizaciones muy frecuentes de yt-dlp y FFmpeg se agrupan conservando siempre el último valor y publicando inmediatamente cambios finales, errores y fases.
- El Conversor reutiliza el escáner mientras sus límites no cambien y calcula una sola vez el conjunto de rutas originales protegidas.
- Los rankings analíticos costosos se preparan con la instantánea y no se ordenan de nuevo por cada redibujado.
- La limpieza de temporales y la lectura del historial se realizan fuera del hilo principal; el historial incorpora un índice SQLite global por fecha.

## Procesos y cancelación
- No se utiliza `/bin/sh` ni interpolación de comandos.
- Los argumentos se pasan separados y validados.
- Cada motor se inicia con `posix_spawn` en un grupo de procesos independiente del proceso principal.
- La cancelación envía primero SIGTERM, espera un tiempo limitado y usa SIGKILL solo como último recurso.
- Se espera la terminación y se comprueba que no queden descendientes.
- El cierre de ZEUVE termina los grupos registrados.

## Archivos
- No se sobrescriben resultados sin autorización expresa.
- La opción predeterminada ante conflictos es renombrar automáticamente.
- yt-dlp escribe únicamente en temporales controlados por la operación.
- Los `.part` no se publican.
- Los resultados se verifican antes de moverse y las copias entre volúmenes usan un nombre temporal en destino antes del renombrado final.
- La limpieza solo elimina archivos que pertenecen de forma verificable a la operación.

## Distribución y seguridad
- App Sandbox permanece desactivado en 0.7.0.
- Hardened Runtime permanece activado.
- Se conservan las firmas oficiales de `yt-dlp` y Calibre; Deno, FFmpeg, FFprobe, Pandoc y Ghostscript se firman de forma explícita con la identidad de ZEUVE cuando están presentes.
- Sandbox requiere una prueba técnica específica posterior.
- No se incorporan binarios arbitrarios cuando el entorno no permite generar y verificar los binarios ARM64 aprobados.

## Desarrollo y entrega
- Antes de implementar cambios se presenta un plan y se espera aprobación.
- No se refactorizan ni modifican partes no solicitadas.
- Cada entrega incluye proyecto completo, ZIP limpio, pruebas, documentación, versión, changelog e informes.
- No se afirma que una app se ha compilado o abierto sin haberlo comprobado realmente.

## Corrección de preparación de motores 0.7.1
- La licencia de Calibre 9.11.0 se obtiene desde el archivo oficial `LICENSE` del tag fijado cuando no está incluida dentro de `Calibre.app`.
- Se elimina la referencia inexistente a `COPYING`, que devolvía HTTP 404 y detenía la preparación antes de FFmpeg, Ghostscript y la publicación final de `Resources/Engines`.
