# Seguridad y privacidad — ZEUVE 0.7.5

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

- Solo se aceptan HTTPS y hosts de YouTube aprobados.
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
- Firma explícita de motores: se conserva la firma oficial de yt-dlp y se firman Deno, FFmpeg y FFprobe con la identidad de ZEUVE.
- Verificación de firma y arranque de `yt-dlp --version` sobre el ejecutable ya incluido en la aplicación.

## Procesos

Cada ejecución crea un grupo POSIX independiente con `posix_spawn`. La cancelación actúa sobre el grupo completo, no solo sobre el proceso padre. Se utiliza SIGTERM, espera limitada y SIGKILL como último recurso. El cierre de ZEUVE solicita la terminación de todos los grupos registrados.

## Cookies y proxy

- Cookies desactivadas por defecto.
- Solo `cookies.txt` seleccionado manualmente.
- No se copia a Application Support.
- No se almacena su ruta ni contenido.
- No aparece en historial, logs, mensajes ni comandos visibles.
- No se leen bases de Safari, Chrome o Firefox.
- Proxy desactivado por defecto y limitado a la operación actual.
- Usuario y contraseña permanecen en memoria y no se guardan.

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


## Analizador de chats

- No declara ni utiliza acceso a red.
- Los archivos seleccionados se abren en lectura y se verifican mediante huella antes de procesarlos.
- Los adjuntos se clasifican por marcador, ruta, extensión o etiqueta HTML; no se abren ni decodifican.
- Las rutas ZIP se normalizan y se rechazan rutas absolutas, `..`, enlaces simbólicos, cifrado y entradas duplicadas.
- Se aplican límites estructurales de entradas, tamaño total del ZIP, relación de compresión, páginas y mensajes. El archivo de conversación no tiene límite de tamaño por defecto; el usuario puede activar uno independiente desde Ajustes.
- Los enlaces externos de Instagram se clasifican como enlaces y nunca se consultan.
- La base y la carpeta temporal están excluidas de copias de seguridad y se eliminan al cerrar la sesión.
- La limpieza exige el marcador `.zeuve-chat-operation`; sin él se rechaza la eliminación.
- Historial y logs solo guardan datos agregados y códigos técnicos.
- La suite permanente usa exclusivamente conversaciones sintéticas. Los archivos reales aportados para reproducir esta corrección solo se procesaron temporalmente y no forman parte del proyecto ni de la entrega.

## Conversor universal

- Los originales se validan por huella antes de ejecutar y nunca se publican sobre sí mismos.
- Los temporales incluyen marcador de propiedad y solo se eliminan dentro de su raíz verificada.
- Los ZIP rechazan traversal, rutas absolutas, enlaces, duplicados y límites estructurales sospechosos. Los ZIP cifrados requieren una contraseña temporal que permanece solo en memoria y se excluye de ajustes, preajustes, historial y registros.
- La firma oficial de Calibre se conserva; Deno, FFmpeg, FFprobe, Pandoc y Ghostscript se firman con ZEUVE cuando están presentes.


## Motores documentales y gráficos aprobados en 0.7.0

- Pandoc y Calibre reciben argumentos separados y rutas locales controladas; no se ejecuta una shell.
- Ghostscript utiliza `-dSAFER`, desactiva búsquedas inseguras y recibe `GS_LIB` apuntando exclusivamente a sus recursos empaquetados.
- FFmpeg se compila sin acceso de red, con libx264 y libwebp estáticos; libx265 no se incorpora.
- Los motores opcionales ausentes no se presentan como disponibles. La aplicación no los descarga ni solicita una instalación del sistema.
- Calibre conserva su aplicación completa para evitar romper firmas, recursos o frameworks internos.

## Contraseñas del Conversor

- ZIP y PDF admiten contraseña únicamente durante la operación.
- La contraseña se mantiene en memoria, se limpia al sustituir la fuente, terminar o cancelar y no se guarda en historial, favoritas, preajustes, ajustes ni logs.
- La interfaz permite mostrarla temporalmente, pero nunca la incluye en detalles técnicos copiables.
- Los documentos ofimáticos protegidos no se declaran compatibles mientras no exista una vía headless segura y probada.


## Fotogramas visibles y resultados incompletos 0.7.5

La carpeta visible de fotogramas es una excepción controlada a la publicación temporal interna: se crea únicamente dentro de la carpeta de salida seleccionada, usa un nombre `Procesando` y contiene un marcador oculto con el UUID de la operación. El registro privado correspondiente permanece dentro del workspace de ZEUVE.

Al cancelar o fallar, ZEUVE no elimina los fotogramas válidos. Comprueba el último archivo y solo lo retira si está vacío, dañado o no corresponde al formato solicitado; después renombra el conjunto como `Incompleto` y marca `tiempos.csv` como parcial. En un cierre inesperado, la recuperación exige registros y UUID coherentes antes de tocar la carpeta. No se recorren ni renombran carpetas ajenas que no estén demostrablemente asociadas a una operación de ZEUVE.

La conversión real de vídeo continúa generándose en temporales internos y se valida antes de publicarse. El modo simple no utiliza copia de vídeo; el remux solo se permite mediante una opción avanzada explícita.
