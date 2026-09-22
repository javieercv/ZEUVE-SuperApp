# Seguridad y privacidad — ZEUVE 0.20.0.0

## Limpiador 0.1.0 — excepción de mantenimiento controlada

El permiso `scanLocalStorage` permite inspeccionar únicamente las ubicaciones de mantenimiento documentadas; `removeLocalItems` declara la capacidad separada de ejecutar un plan aprobado. Esta excepción no cambia la regla de archivos de los demás módulos.

Toda retirada requiere descubrimiento, plan visible, selección explícita y revalidación. Los scans no siguen symlinks; los App Groups compartidos y datos persistentes no se autoseleccionan; un volumen externo ausente no convierte sus datos en residuos. El Limpiador no usa red, shell, `sudo`, helper privilegiado ni secure erase. Papelera es el default y Undo no sobrescribe rutas ocupadas.

## Inspector multimedia 0.7.0 — privacidad, memoria y archivos

El Inspector continúa sin permiso de red. Preview, análisis, OCR, reglas y edición se ejecutan localmente con motores/frameworks aprobados; no existen APIs web, telemetría, modelos remotos ni subida de multimedia.

Los originales se abren en lectura y cualquier edición sigue el flujo workspace temporal → operación → FFprobe → publicación segura. Vídeos, audios, subtítulos, attachments y carátulas externos quedan fingerprintados antes de ejecutar. No hay overwrite silencioso ni fallback a transcode.

El preview de vídeo procesa frames incrementalmente con buffers duros y generaciones cancelables. Los frames, PCM e imágenes OCR no se persisten fuera del workspace efímero. Al cambiar/cerrar una sesión se cancelan procesos y resultados obsoletos antes de aceptar la nueva generación.

No se registran rutas completas, frames, PCM, texto OCR/subtítulos, metadata completa, títulos privados ni listas de archivos. Favoritos y rule sets solo guardan configuración; los informes schema 3 siguen excluyendo rutas, fingerprints, IDs internos y texto OCR. La enumeración de carpetas no sigue symlinks y la limpieza solo elimina temporales propiedad de ZEUVE.

## Principios globales

- Sin telemetría, analítica, publicidad ni crash reporting externo.
- Sin comprobaciones automáticas de actualización.
- Sin subida automática de logs.
- App Sandbox desactivado en 0.7.0; Hardened Runtime activado.
- Configuración, historial y registros únicamente locales.

## Red

El Organizador, el Analizador de chats y el Conversor universal no utilizan Internet durante su uso.

El Descargador solo inicia conexiones cuando el usuario pulsa **Analizar** o **Descargar**. Puede comunicarse con YouTube, `youtu.be`, servidores de miniaturas y dominios de entrega como `googlevideo`. La infraestructura concreta puede cambiar por decisión de YouTube.

ZEUVE no contacta con servidores de analítica, publicidad, actualización, logs ni APIs ajenas a la operación.

FFmpeg se compila con su acceso de red desactivado. yt-dlp recibe `--no-update`, `--ignore-config`, `--cache-dir` con una carpeta local privada de ZEUVE y rutas explícitas de Deno y FFmpeg.

## URLs y argumentos

- Se aceptan URLs HTTPS públicas compatibles; HTTP y rangos privados requieren una autorización avanzada expresa.
- Se rechazan `file:`, esquemas desconocidos y entradas malformadas.
- No se ejecuta `/bin/sh`.
- Todos los argumentos se pasan por separado.
- No existe un campo de argumentos personalizados.
- Los valores no confiables se validan y la URL queda después de `--`.

## Motores

- Rutas relativas seguras dentro de `Resources/Engines`.
- Resolución de enlaces simbólicos antes de aceptar una ruta.
- SHA-256 y tamaño verificados durante la preparación y antes del empaquetado.
- En ejecución no se comparan tamaño ni SHA-256 porque la firma de macOS modifica el binario; se comprueban existencia, licencia, permisos, arquitectura, dependencias, lanzamiento y versión.
- Licencia o aviso asociado obligatorio.
- Dependencias dinámicas limitadas a componentes del sistema o archivos incluidos.
- Firma explícita de motores: se conservan las firmas oficiales de yt-dlp y Deno; Deno mantiene las autorizaciones JIT que necesita V8. FFmpeg y FFprobe se firman con la identidad de ZEUVE.
- Verificación de firma, arranque de `yt-dlp --version` y evaluación real de JavaScript con Deno sobre los ejecutables ya incluidos en la aplicación.

## Procesos

Cada ejecución crea un grupo POSIX independiente con `posix_spawn`. La cancelación actúa sobre el grupo completo, no solo sobre el proceso padre. Se utiliza SIGTERM, espera limitada y SIGKILL como último recurso. Cancelar la `Task` Swift propietaria de `ExternalProcessRunner.run()` activa también esta terminación del grupo; el cierre de ZEUVE solicita la terminación de todos los grupos registrados.

## Cookies y proxy

- Cookies desactivadas por defecto.
- `cookies.txt` o sesión temporal del navegador únicamente por elección expresa del usuario.
- No se copia a Application Support.
- No se almacena su ruta ni contenido.
- No aparece en historial, logs, mensajes ni comandos visibles.
- No se leen bases de Safari, Chrome u otros navegadores en la ruta pública predeterminada.
- Proxy desactivado por defecto y limitado a la operación actual.
- Usuario y contraseña permanecen en memoria y no se guardan.
- Un enlace concreto público de Instagram ignora cualquier sesión disponible durante análisis y descarga; solo un elemento marcado como autenticado puede recibir cookies.

## Instagram público anónimo 0.11.5

- `instaloader-zeuve 4.15.3-zeuve.2` recibe primero el shortcode público sin cookies; `gallery-dl` y `yt-dlp` quedan como respaldos anónimos.
- Si existe una sesión guardada, ZEUVE realiza primero el intento anónimo y no reutiliza la sesión cuando ese intento funciona.
- Un mensaje ambiguo de login o límite no abre automáticamente el flujo de autenticación. Solo señales explícitas de cuenta o perfil privado permiten solicitar una sesión.
- Las URLs firmadas del CDN permanecen en memoria durante la operación y no se escriben en historial, registros o metadatos.

## Historial, logs y JSON

Se conservan únicamente título, ID canónico, tipo, ajustes no sensibles, resultado y referencias técnicas. No se guardan:

- URL completa;
- URLs firmadas de medios;
- parámetros temporales;
- cookies;
- tokens;
- cabeceras;
- credenciales de proxy;
- líneas de comando completas.

Los JSON nativos de información de yt-dlp están desactivados. ZEUVE genera documentos sanitizados con un esquema propio y sin URLs.

`LocalLogger` mantiene únicamente sus JSONL con nombre `zeuve-AAAA-MM-DD.jsonl`, aplica 30 días de retención y un máximo global de 50 MiB, y usa permisos 0700 para la carpeta y 0600 para los archivos cuando el sistema lo permite. La limpieza no elimina otros archivos presentes en la carpeta de logs. Los módulos no deben añadir rutas completas del usuario a metadatos de log salvo necesidad técnica explícitamente aprobada.

## Temporales y publicación

- Cada operación tiene UUID y marcador de propiedad.
- yt-dlp no escribe directamente sobre resultados existentes.
- `.part` y `.ytdl` no se publican.
- FFprobe valida resultados multimedia.
- Las copias entre volúmenes pasan por un nombre temporal en destino.
- Renombrar automáticamente es la opción predeterminada.
- Reemplazar exige confirmación expresa.
- La limpieza verifica la propiedad y no borra archivos ajenos.

## Organizador

Mantiene sus protecciones anteriores: no sigue enlaces simbólicos, no recorre paquetes, valida vista previa, no sobrescribe, revierte movimientos y comprueba huellas antes de deshacer.


## Descargador universal 0.5.2

- La URL se valida antes de cualquier conexión. HTTPS público es el valor predeterminado; HTTP y rangos privados requieren autorización avanzada expresa.
- La página se solicita con una sesión efímera, sin caché ni almacén global de cookies.
- La inspección HTML tiene un límite estructural de 16 MB y no extrae ni descarga todos los recursos de la página.
- Los candidatos se normalizan y deduplican antes de entrar en la cola; no se descargan duplicados seguros para eliminarlos después.
- Las coincidencias no concluyentes nunca se descartan automáticamente.
- `cookies.txt` debe tener formato Netscape y permanece en lectura durante la operación.
- URLs, tokens, cabeceras privadas y credenciales se sane­an o excluyen de logs e historial.
- Las miniaturas remotas no se cargan desde la vista mediante una conexión independiente.
- Los resultados se descargan en temporales propios, se validan con FFprobe y se publican de forma segura.
- Las URLs multimedia firmadas y cabeceras resueltas se mantienen solo en memoria, no se codifican y no se registran; solo se usan para evitar una segunda resolución del mismo vídeo.
- Los reintentos adaptativos limpian exclusivamente el workspace identificado de la operación.
- La publicación en el mismo volumen utiliza movimientos atómicos; la copia entre volúmenes conserva staging, validación de tamaño y política de conflictos.
- No se elude DRM ni se ejecutan scripts arbitrarios de una página dentro de ZEUVE.
- Los vídeos descubiertos en páginas ignoran cualquier preset o ajuste de conversión y se descargan sin recodificación; solo puede realizarse unión o remultiplexado de los flujos originales.
- La procedencia es voluntaria y está desactivada por defecto. Solo utiliza la URL saneada de la página y nunca la URL firmada del medio.
- La inserción de procedencia usa copia directa de streams; si el contenedor no la admite, se conserva el archivo original y se registra una advertencia.
- El atributo «De dónde» se escribe únicamente cuando el usuario lo activa y puede fallar en sistemas de archivos que no admitan atributos extendidos.

## Descargador universal 0.10.0

- El contenido adulto se bloquea antes del análisis y de cargar miniaturas salvo activación expresa desde Ajustes.
- Las sesiones de Instagram se usan temporalmente por defecto. Si el usuario decide recordarlas, se guardan en el Llavero de macOS y nunca en ajustes, historial, logs, presets o diagnósticos.
- El usuario puede pegar una cabecera Cookie, pegar o seleccionar cookies.txt, o autorizar una importación puntual desde un navegador compatible. ZEUVE no solicita la contraseña.
- Los perfiles privados solo se procesan cuando la sesión aportada ya tiene acceso; no se intentan eludir controles de privacidad, pagos, CAPTCHA o DRM.
- Las URLs multimedia firmadas y las cabeceras resueltas permanecen en memoria y temporales privados; la procedencia opcional usa una URL saneada.
- Los motores actualizados se instalan fuera del paquete original, se validan antes de activarse y pueden restaurarse a la versión incluida. La advertencia se muestra también para versiones estables.
- La búsqueda Wayback de avatares antiguos es manual, comunica el nombre de usuario al servicio de archivo elegido y no garantiza resultados.
- El navegador automatizado no se incluye en el paquete principal y solo puede activarse como componente opcional instalado expresamente.

## Restablecimiento global de ajustes 0.12.3

- La restauración global no borra la base SQLite ni el historial y no recorre ni modifica archivos del usuario.
- La sesión de Instagram que el usuario hubiera pedido recordar se elimina expresamente del Llavero de macOS; no se exporta ni se copia a otra ubicación.
- Los bookmarks persistidos de carpetas de salida del Descargador y del Conversor se eliminan durante el restablecimiento global sin borrar ni modificar las carpetas o archivos a los que apuntaban. Un fallo puntual de resolución durante el uso normal conserva el bookmark para evitar perder una preferencia válida por un error transitorio.
- La codificación/resolución de esos bookmarks y el ciclo `security-scoped` usan infraestructura común de `ZEUVECore`; cada módulo conserva su clave, validación y política de salida. No se amplían permisos ni se comparten rutas entre módulos.
- Si falla únicamente el guardado del historial después de completar una operación, el log asociado conserva solo el tipo técnico del error; no añade rutas, nombres de archivos, URLs, contenido tratado, tokens ni credenciales.
- Presets, preajustes, favoritas, perfiles personalizados y carpetas recientes se conservan porque son contenido/configuración creada expresamente por el usuario, no secretos que deban eliminarse al volver a valores de fábrica.
- La acción queda deshabilitada durante operaciones activas para evitar cambios de configuración debajo de un proceso pesado.

## Respaldo de TikTok 0.11.3

- `gallery-dl` y el respaldo `yt-dlp` trabajan únicamente dentro del workspace identificado de la operación.
- Antes del respaldo se eliminan los resultados parciales del primer intento mediante la limpieza segura del workspace; nunca se mezclan salidas de ambos motores.
- El respaldo reutiliza la URL pública estable de TikTok y no persiste URLs firmadas del CDN, cookies, cabeceras privadas ni argumentos completos.
- Un intento solo puede avanzar a validación y publicación si ha generado al menos un archivo regular no vacío. Si ambos motores fallan, no se publica ningún resto.
- Los registros conservan identificador canónico, motor, código de salida, cantidad de archivos y referencia técnica saneada, pero no la salida cruda del motor ni secretos.

## Analizador de chats

- No declara ni utiliza acceso a red.
- Los archivos seleccionados se abren en lectura y se verifican mediante huella antes de procesarlos.
- Los adjuntos se clasifican por marcador, ruta, extensión o etiqueta HTML; no se abren ni decodifican.
- Las rutas ZIP se normalizan y se rechazan rutas absolutas, `..`, enlaces simbólicos, cifrado y entradas duplicadas.
- Se aplican límites estructurales de entradas, tamaño total del ZIP, relación de compresión, páginas y mensajes. El archivo de conversación no tiene límite de tamaño por defecto; el usuario puede activar uno independiente desde Ajustes.
- Los enlaces externos de Instagram se clasifican como enlaces y nunca se consultan.
- La base SQLite es la fuente principal de los mensajes durante la sesión; la base y la carpeta temporal están excluidas de copias de seguridad y se eliminan al cerrar la sesión.
- La limpieza exige el marcador `.zeuve-chat-operation`; sin él se rechaza la eliminación.
- Historial y logs solo guardan datos agregados y códigos técnicos.
- La suite permanente usa exclusivamente conversaciones sintéticas. Los archivos reales aportados para reproducir esta corrección solo se procesaron temporalmente y no forman parte del proyecto ni de la entrega.

## Conversor universal

- Los originales se validan por huella antes de ejecutar y nunca se publican sobre sí mismos.
- Los temporales incluyen marcador de propiedad y solo se eliminan dentro de su raíz verificada.
- Los ZIP rechazan traversal, rutas absolutas, enlaces, duplicados y límites estructurales sospechosos. Los ZIP cifrados requieren una contraseña temporal que permanece solo en memoria y se excluye de ajustes, preajustes, historial y registros.
- Deno conserva su firma oficial; FFmpeg, FFprobe y Pandoc se firman con ZEUVE cuando están presentes. Calibre y Ghostscript están retirados.


## Motores documentales y gráficos aprobados en 0.7.0

- Pandoc recibe argumentos separados y rutas locales controladas; no se ejecuta una shell.
- Ghostscript no se incluye, registra, prepara, firma ni ejecuta.
- FFmpeg se compila sin acceso de red, con libx264 y libwebp estáticos; libx265 no se incorpora.
- Los motores opcionales ausentes no se presentan como disponibles. La aplicación no los descarga ni solicita una instalación del sistema.
- Calibre no forma parte de la aplicación ni de sus motores aprobados.

## Contraseñas del Conversor

- ZIP y PDF admiten contraseña únicamente durante la operación.
- La contraseña se mantiene en memoria, se limpia al sustituir la fuente, terminar o cancelar y no se guarda en historial, favoritas, preajustes, ajustes ni logs.
- La interfaz permite mostrarla temporalmente, pero nunca la incluye en detalles técnicos copiables.
- Los documentos ofimáticos protegidos no se declaran compatibles mientras no exista una vía headless segura y probada.


## Fotogramas visibles y resultados incompletos 0.7.5

La carpeta visible de fotogramas es una excepción controlada a la publicación temporal interna: se crea únicamente dentro de la carpeta de salida seleccionada, usa un nombre `Procesando` y contiene un marcador oculto con el UUID de la operación. El registro privado correspondiente permanece dentro del workspace de ZEUVE.

Al cancelar o fallar, ZEUVE no elimina los fotogramas válidos. Comprueba el último archivo y solo lo retira si está vacío, dañado o no corresponde al formato solicitado; después renombra el conjunto como `Incompleto` y marca `tiempos.csv` como parcial. En un cierre inesperado, la recuperación exige registros y UUID coherentes antes de tocar la carpeta. No se recorren ni renombran carpetas ajenas que no estén demostrablemente asociadas a una operación de ZEUVE.

La conversión real de vídeo continúa generándose en temporales internos y se valida antes de publicarse. El modo simple no utiliza copia de vídeo; el remux solo se permite mediante una opción avanzada explícita.

## Comparador de seguidores de Instagram 0.8.0

- No utiliza `URLSession`, contenido web, cookies, tokens, credenciales, APIs ni procesos externos.
- Solo abre una URL pública de perfil después de que el usuario pulse expresamente «Abrir en Instagram».
- Los archivos seleccionados se abren con acceso de seguridad durante la inspección o el análisis y no se convierten en permisos persistentes.
- La inspección ZIP normaliza rutas y rechaza traversal, rutas absolutas, enlaces simbólicos, cifrado, entradas duplicadas y conflictos que solo difieren por mayúsculas.
- Se aplican límites de entradas, profundidad, tamaño declarado, tamaño de JSON relevante y relación de compresión.
- El ZIP no se extrae completo; únicamente se leen `following.json` y los `followers_<número>.json` pertenecientes a la misma exportación.
- Los originales se mantienen en lectura y nunca se renombran, mueven ni reescriben.
- Los resultados y consultas permanecen en memoria. El historial guarda solo cantidades, tipo de entrada, duración, estado, advertencias e indicador de exportación.
- TXT y CSV se generan primero como archivo temporal propio y se publican en la ubicación elegida. La interfaz nativa solicita confirmación antes de sustituir un archivo existente.
- La cancelación no devuelve ni persiste listas parciales.

## Inspector multimedia — garantías 0.13.0

- Procesamiento totalmente local y manifiesto sin `networkAccess`.
- FFprobe/FFmpeg se resuelven desde el registro de motores existente y se ejecutan con `ExternalProcessRunner`, nunca mediante shell.
- El original se inspecciona y edita conceptualmente en lectura; la operación real escribe solo en un workspace temporal propio y publica un archivo nuevo.
- Se rechaza como destino cualquier path canónicamente equivalente al original o a una entrada externa protegida; también se rechazan originales de edición que sean symlinks.
- Original y entradas externas llevan `FileFingerprint` y se vuelven a comprobar antes de ejecutar.
- La publicación usa staging y conflicto seguro; un output parcial o no validado no se publica.
- Cancelar remux/espectrograma termina el proceso asociado y limpia solo temporales identificables como propios.
- Historial de remux/PNG no contiene rutas, nombres, tags, títulos/idiomas de pistas, PCM ni matrices espectrales.
- El espectrograma mantiene PCM y columnas en memoria transitoria y acotada; no persiste caches espectrales privadas.
- Spek se estudió únicamente como referencia pública clean-room: no se incorpora código, binarios, wxWidgets ni componentes GPL.


## Inspector multimedia — saneamiento 0.13.1.0

Los cambios del espectrograma permanecen totalmente locales. La nueva rasterización usa únicamente memoria transitoria y no crea cache persistente; el buffer se libera con el resultado/vista y el PNG continúa publicándose mediante staging seguro. No se añaden rutas a logs, red, dependencias, permisos ni persistencia de PCM/matrices espectrales.

## Inspector multimedia — rendimiento 0.13.2.0

- La caché espectral vive únicamente en memoria, se limita a cuatro entradas y 64 MiB y se invalida cuando cambia el fingerprint del archivo.
- No se persisten PCM, matrices, nombres ni rutas; los diagnósticos internos contienen solo contadores y duraciones.
- `posix_spawn` limpia la máscara de señales del hijo para que `SIGTERM`/`SIGINT` no queden bloqueadas por herencia. La cancelación sigue actuando sobre el grupo completo y espera su recolección.
- El PCM se consume por bloques, conserva como máximo tres bytes residuales y no crea temporales en disco.


## Inspector multimedia — previsualización 0.14.0.0

La previsualización de audio es completamente local y de solo lectura. Utiliza el FFmpeg empaquetado con argumentos separados, nunca `/bin/sh`, y salida PCM por pipe. La cola PCM es temporal/acotada y no se persiste. Reproducir no genera historial ni resultados permanentes.

Las fuentes externas del draft se vuelven a verificar mediante `FileFingerprint` antes de reproducir. Cambiar/cerrar archivo, descartar edición o iniciar publicación detiene el reproductor. No se registran rutas completas, PCM, títulos privados ni metadata en logs. No se añade red ni dependencia externa.

## Inspector multimedia — waveform, sonoridad e informes 0.15.0.0

- Waveform y sonoridad son análisis locales. No añaden red, APIs, telemetría ni motores.
- La waveform procesa PCM de forma incremental y acotada; no guarda PCM ni la envolvente en disco. Su caché es únicamente temporal en memoria y está ligada al fingerprint/stream.
- La sonoridad usa `OperationCoordinator` al recorrer una pista completa. Desde 0.15.7.0 puede iniciarse automáticamente únicamente cuando FFprobe detecta exactamente una pista de audio; con varias pistas requiere acción explícita. La cancelación termina el proceso FFmpeg gestionado.
- Los cambios de archivo verifican borradores pendientes y detienen preview/análisis auxiliares antes de liberar la sesión.
- El informe técnico se exporta solo a una ubicación seleccionada por el usuario, mediante temporal propio y publicación segura. El payload no incluye ruta completa del origen, fingerprint ni identificadores internos de preview.
- Los ajustes del Inspector se guardan localmente mediante `SettingsRepository`; no crean superficies de configuración independientes ni contienen contenido multimedia privado.

## Inspector multimedia — preview 0.15.1.0

La corrección de cambio de pista/seek no amplía permisos. Sigue utilizando el FFmpeg empaquetado con argumentos separados y `-map` del stream solicitado, sin shell ni red. La serialización de operaciones evita que un stop antiguo afecte a una fuente nueva; no se persisten posiciones, PCM, rutas completas ni contenido de waveform.

En 0.15.2.0 la limpieza trabaja con referencias capturadas de la sesión retirada, por lo que una finalización tardía no puede detener una fuente posterior. No se añaden permisos, red, persistencia, dependencias ni cambios sobre los archivos de usuario.

## Reproductor del Inspector 0.15.3.0

La continuidad Play/Pausa no cambia la frontera de seguridad. Una sustitución pausada conserva únicamente contexto efímero en memoria y no arranca FFmpeg/AVAudioEngine hasta la reanudación. No se crean archivos, no se modifica el original, no se persisten rutas/PCM/estado de reproducción, no se añade red y no cambian permisos ni motores.

## Controles del Inspector 0.15.4.0

La centralización de identidad/estado de los botones solo opera sobre identificadores efímeros ya existentes en memoria. No añade persistencia, rutas, contenido multimedia, procesos, permisos, red ni escritura de archivos.


## Controles del Inspector 0.15.5.0

La corrección solo cambia cómo el ViewModel asocia un identificador efímero de fuente con un botón durante estados de carga o reproducción. No añade persistencia, procesos, rutas, datos multimedia, red, permisos ni escrituras. `MultimediaAudioPreviewService` y la protección de archivos permanecen sin cambios.


## Identidad de filas del Inspector 0.15.6.0

La estabilización de las filas del Inspector es exclusivamente memoria de proceso. Los UUID de `MediaEditableTrack` no se persisten, no se registran y no salen del equipo. No se añaden red, archivos temporales, telemetría ni cambios sobre el original.


## Inspector multimedia — análisis automático mono-pista 0.15.7.0

La automatización no amplía permisos ni fronteras de privacidad. FFprobe, espectrograma y sonoridad siguen ejecutándose localmente con los motores empaquetados, argumentos separados y sin shell, red, APIs, telemetría ni persistencia de PCM/datos espectrales.

La cadena automática no escribe sobre el original ni publica archivos. Espectrograma y sonoridad siguen reservando `OperationCoordinator` de forma secuencial, nunca simultánea. Una identidad efímera de sesión y la cancelación de las tareas impiden iniciar la sonoridad de un archivo después de que esa sesión haya sido cancelada o sustituida.


## Inspector multimedia — timeline compartido 0.15.8.0

El zoom/pan de waveform y espectrograma opera exclusivamente sobre modelos ya residentes en memoria. Navegar no crea procesos externos adicionales, no escribe archivos, no persiste posiciones/chapters y no añade red, APIs, telemetría, permisos ni dependencias.

La waveform sigue derivándose de PCM incremental local producido por el FFmpeg empaquetado, pero conserva únicamente una envolvente acotada de hasta 65.536 buckets; el PCM completo nunca se retiene. Los capítulos proceden de la inspección FFprobe ya disponible y se muestran en lectura. No se modifica el original ni se autoriza edición de capítulos.

## Análisis de señal 0.15.9.0

El análisis de silencios/posible clipping se ejecuta íntegramente en local con el FFmpeg empaquetado. El PCM `float32` se consume por streaming y no se persiste ni se conserva completo en memoria. Se valida el fingerprint de la fuente antes y después, se usan argumentos separados y `OperationCoordinator`, y la cancelación termina el proceso y descarta resultados parciales. No se añaden red, APIs, telemetría, dependencias ni escrituras sobre el original.

## Sonoridad temporal, A/B e informes 0.16.0.0

La sonoridad temporal no abre un proceso adicional: deriva de la ejecución local EBU R128 ya necesaria para la sonoridad global. Solo se conservan valores numéricos LUFS acotados en memoria; no se guarda PCM ni se persiste la serie. La vista temporal no accede a red ni a archivos por sí misma.

A/B reutiliza una única sesión de `MultimediaAudioPreviewService`. Los identificadores de fuente son efímeros y no se escriben en historial/informes. La sustitución valida las fuentes mediante las garantías de fingerprint existentes; no crea archivos, no modifica originales y no reserva dos decodificadores paralelos.

El informe JSON schema 2 serializa únicamente información técnica y resultados derivados aprobados. Se mantiene la prohibición expresa de exportar rutas completas, fingerprints, `sourceID`, tokens, cabeceras o contenido PCM. TXT/Markdown limitan además la enumeración de eventos para evitar volcados innecesarios.

## Protección de la edición estructural 0.17.0.0

- Los capítulos se generan en FFmetadata dentro de un workspace propiedad de la operación y se eliminan al terminar o cancelar.
- Los attachments externos deben ser archivos regulares, no symlinks, y conservar su fingerprint entre planificación, ejecución y publicación.
- La extracción de attachments nunca escribe FFmpeg directamente sobre el destino final: usa temporal, validación y publicación con resolución de conflictos.
- Los nombres, títulos y valores de metadata del usuario no se incorporan a logs ni al historial; el historial conserva solo contadores agregados.
- No se añaden red, APIs, telemetría, dependencias ni motores.


## Seguridad de lotes y presets 0.18.0.0

- Cada archivo de la cola se fingerprinta al añadirlo y vuelve a comprobarse antes de procesarlo. Los symlinks no se aceptan como entradas del lote.
- Toda publicación de informes o PNG recibe la lista completa de originales del lote como rutas protegidas; un resultado nunca puede sobrescribir silenciosamente otro original de la selección.
- Los presets no almacenan rutas, carpetas de salida, nombres de archivos ni listas privadas. La clave `multimediaInspector.batchPresets.v1` contiene únicamente parámetros de comportamiento.
- El historial registra un resumen agregado del lote (contadores y duración), nunca nombres, rutas, metadata privada ni resultados LUFS por archivo.
- Cancelar detiene la fase pesada actual, limpia solo temporales propios y conserva resultados de elementos ya publicados correctamente.
- No se añade red, telemetría, API, motor externo ni dependencia. La personalización no puede desactivar fingerprints, validación, publicación segura, protección del original ni `OperationCoordinator`.

## Ayuda contextual del Inspector 0.18.1.0

Los popovers de ayuda son estado de presentación local: no lanzan FFmpeg/FFprobe, no acceden a red, no leen archivos adicionales, no guardan metadata ni rutas, no invalidan cachés y no escriben historial. Los textos viven en código de UI y reutilizan el componente compartido.
