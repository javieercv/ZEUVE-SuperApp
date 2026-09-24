# Motores del Descargador universal

## Registro compartido

Los motores se almacenan bajo `Resources/Engines` y se describen en `engines.json`. FFmpeg y FFprobe no pertenecen exclusivamente al módulo del Descargador universal y podrán reutilizarse por el Conversor universal.

## Versiones fijadas

| Motor | Versión | Arquitectura | Procedencia | Función |
|---|---:|---|---|---|
| yt-dlp | 2026.08.19 | Universal macOS | Distribución oficial descomprimida | Análisis y descarga |
| Deno | 2.9.0 | ARM64 macOS | Ejecutable oficial | Runtime JavaScript requerido por yt-dlp |
| FFmpeg | 8.1.2 | ARM64 macOS | Compilación reproducible | Unión, remux, audio, metadatos y subtítulos |
| FFprobe | 8.1.2 | ARM64 macOS | Misma compilación | Validación multimedia |
| gallery-dl | 1.32.9 | ARM64 macOS | PyPI, binario reproducible | Redes sociales, galerías y fallbacks multimedia |
| instaloader-zeuve | 4.15.3-zeuve.2 | ARM64 macOS | Instaloader con adaptador ZEUVE | Publicaciones directas y catálogo de Instagram |
| libmp3lame | 3.100 | ARM64 estático | Fuentes oficiales | Codificación MP3 |
| libopus | 1.5.2 | ARM64 estático | Fuentes oficiales | Codificación Opus |

## Uso por yt-dlp

La aplicación proporciona siempre rutas explícitas:

```text
--js-runtimes deno:/ruta/incluida/deno
--ffmpeg-location /ruta/incluida/ffmpeg
```

También añade `--ignore-config`, `--no-update`, `--cache-dir` con una carpeta local privada de ZEUVE y desactiva la generación de JSON nativo de información.

Para YouTube público sin sesión, análisis y descarga añaden:

```text
--extractor-args youtube:player_client=web_embedded,web_safari
```

Esta cadena usa únicamente clientes incluidos en yt-dlp. No instala componentes remotos, no obtiene tokens de terceros y permite que `web_safari` actúe como respaldo HLS. La descarga vuelve a partir del enlace estable de YouTube para evitar reutilizar una URL multimedia firmada del análisis.

Para enlaces concretos públicos de Instagram, `instaloader-zeuve` se ejecuta primero sin cookies y enumera todos los nodos del contenido. `gallery-dl` y yt-dlp 2026.08.19 permanecen como respaldos anónimos. Una sesión solo se añade al elemento cuando se ha confirmado contenido privado.

No se utiliza:

- Python del sistema;
- Homebrew;
- `--remote-components`;
- descarga dinámica de `yt-dlp-ejs`;
- actualización automática;
- búsqueda de motores mediante `PATH`.

## Perfil de FFmpeg

La compilación aprobada:

- es ARM64;
- es estática respecto a libmp3lame y libopus;
- desactiva la red propia de FFmpeg;
- incluye FFmpeg y FFprobe;
- incluye libx264 y no incluye libx265;
- permite copia de streams, unión, remux, AAC/M4A, MP3, Opus, FLAC, WAV/PCM, metadatos, miniaturas, capítulos y subtítulos.

Se conservan los codecs y contenedores internos habituales de FFmpeg para un perfil equilibrado, sin añadir bibliotecas externas pesadas no aprobadas.

## `engines.json`

Cada entrada contiene:

- nombre;
- ejecutable;
- ruta relativa;
- versión;
- arquitectura;
- SHA-256;
- procedencia;
- archivo de licencia;
- función;
- argumentos de diagnóstico;
- tamaño;
- estado obligatorio u opcional.

El manifiesto final se genera después de producir los ejecutables, de modo que los hashes y tamaños corresponden a los archivos preparados antes de la firma de macOS. Estos valores se conservan para verificación de desarrollo y empaquetado, pero no se comparan en tiempo de ejecución porque `codesign` modifica los bytes y el tamaño del ejecutable.

## Firma dentro de la aplicación

El ejecutable raíz y los componentes internos de la distribución oficial descomprimida de yt-dlp conservan sus firmas originales al copiarse a `ZEUVE.app`. Deno también conserva su firma oficial y sus autorizaciones Hardened Runtime para JIT. FFmpeg, FFprobe, gallery-dl e instaloader-zeuve se firman con la identidad de ZEUVE. Los dos binarios PyInstaller reciben únicamente la excepción de validación de bibliotecas necesaria para cargar su framework Python temporal; la aplicación principal no la recibe. Después del copiado y la firma, la verificación ejecuta sus diagnósticos y comprueba la firma estricta; cualquier fallo detiene la compilación.

## Preparación

```bash
./Scripts/prepare_engines_macos.sh
```

La preparación se realiza en un directorio temporal del sistema sin espacios y con un identificador derivado de la ruta del proyecto. El script no modifica `Resources/Engines` mientras descarga o compila. Primero genera y verifica un staging completo; solo entonces publica el conjunto obligatorio y los motores opcionales que hayan sido preparados y validados. Si la publicación o la verificación final fallan, restaura el conjunto anterior.

`Scripts/static_pkg_config.py` implementa localmente las consultas que FFmpeg necesita y `prepare_engines_macos.sh` genera `libmp3lame.pc`, ya que LAME 3.100 no lo instala.

`Resources/Engines/engines.json` contiene los hashes/versiones de la instantánea actual. `Docs/Historico/HashesMotores/ENGINE_HASHES_0.11.5.md` y los demás informes de hashes son evidencia histórica y no deben usarse como fuente vigente cuando difieran del manifiesto actual.

## Verificación

```bash
./Scripts/verify_engines_macos.sh
```

La verificación previa al empaquetado rechaza motores obligatorios ausentes —incluidos gallery-dl e instaloader-zeuve—, modificados, sin permiso, con versión o arquitectura incorrecta, con licencia ausente o con dependencias dinámicas externas no incluidas. Dentro de la aplicación ya firmada, el diagnóstico no vuelve a comparar SHA-256 ni tamaño; sí valida el resto de condiciones y ejecuta el comando de versión.

La integridad de la distribución descomprimida se verifica como un árbol completo mediante `bundleSHA256`, `bundleSize` y `bundleFileCount`, además de la huella individual del ejecutable raíz.

## Diagnóstico compartido 0.7.4

El Descargador y el Conversor utilizan la misma instancia de diagnóstico creada por la aplicación. Los resultados se reutilizan mientras las huellas de los motores no cambien; una actualización manual continúa forzando una comprobación completa.
