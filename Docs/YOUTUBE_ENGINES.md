# Motores del Descargador de YouTube

## Registro compartido

Los motores se almacenan bajo `Resources/Engines` y se describen en `engines.json`. FFmpeg y FFprobe no pertenecen exclusivamente al módulo de YouTube y podrán reutilizarse por el Conversor universal.

## Versiones fijadas

| Motor | Versión | Arquitectura | Procedencia | Función |
|---|---:|---|---|---|
| yt-dlp | 2026.06.09 | Universal macOS | Distribución oficial descomprimida | Análisis y descarga |
| Deno | 2.9.0 | ARM64 macOS | Ejecutable oficial | Runtime JavaScript requerido por yt-dlp |
| FFmpeg | 8.1.2 | ARM64 macOS | Compilación reproducible | Unión, remux, audio, metadatos y subtítulos |
| FFprobe | 8.1.2 | ARM64 macOS | Misma compilación | Validación multimedia |
| libmp3lame | 3.100 | ARM64 estático | Fuentes oficiales | Codificación MP3 |
| libopus | 1.5.2 | ARM64 estático | Fuentes oficiales | Codificación Opus |

## Uso por yt-dlp

La aplicación proporciona siempre rutas explícitas:

```text
--js-runtimes deno:/ruta/incluida/deno
--ffmpeg-location /ruta/incluida/ffmpeg
```

También añade `--ignore-config`, `--no-update`, `--cache-dir` con una carpeta local privada de ZEUVE y desactiva la generación de JSON nativo de información.

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
- no incluye libx264 ni libx265;
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

El ejecutable raíz y los componentes internos de la distribución oficial descomprimida de yt-dlp conservan sus firmas originales al copiarse a `ZEUVE.app`. Deno, FFmpeg y FFprobe se firman con la identidad de ZEUVE. Después del copiado y la firma, `verify_packaged_engines_macos.sh` comprueba las cuatro firmas y ejecuta `yt-dlp --version`; un código distinto de cero detiene la compilación.

## Preparación

```bash
./Scripts/prepare_engines_macos.sh
```

La preparación se realiza en un directorio temporal del sistema sin espacios y con un identificador derivado de la ruta del proyecto. El script no modifica `Resources/Engines` mientras descarga o compila. Primero genera y verifica un staging completo; solo entonces publica los cuatro motores. Si la publicación o la verificación final fallan, restaura el conjunto anterior.

`Scripts/static_pkg_config.py` implementa localmente las consultas que FFmpeg necesita y `prepare_engines_macos.sh` genera `libmp3lame.pc`, ya que LAME 3.100 no lo instala.

Los hashes de descarga aprobados para esta versión se documentan en `ENGINE_HASHES_0.2.4.md`. Los hashes finales de los cuatro ejecutables quedan en `Resources/Engines/engines.json` tras ejecutar el script en macOS ARM64.

## Verificación

```bash
./Scripts/verify_engines_macos.sh
```

La verificación previa al empaquetado rechaza motores ausentes, modificados, sin permiso, con versión o arquitectura incorrecta, con licencia ausente o con dependencias dinámicas externas no incluidas. Dentro de la aplicación ya firmada, el diagnóstico no vuelve a comparar SHA-256 ni tamaño; sí valida el resto de condiciones y ejecuta el comando de versión.

La integridad de la distribución descomprimida se verifica como un árbol completo mediante `bundleSHA256`, `bundleSize` y `bundleFileCount`, además de la huella individual del ejecutable raíz.

## Diagnóstico compartido 0.7.4

El Descargador y el Conversor utilizan la misma instancia de diagnóstico creada por la aplicación. Los resultados se reutilizan mientras las huellas de los motores no cambien; una actualización manual continúa forzando una comprobación completa.
