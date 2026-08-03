# Empaquetado y firma de motores

## Distribución dentro de la app

```text
ZEUVE.app/Contents/Resources/Engines/
├── yt-dlp/yt-dlp_macos
├── yt-dlp/_internal/
├── deno/deno
├── ffmpeg/ffmpeg
├── ffmpeg/ffprobe
├── licenses/
└── engines.json
```

## Orden de preparación

1. Ejecutar `Scripts/prepare_engines_macos.sh` en un Mac Apple Silicon.
2. Ejecutar `Scripts/verify_engines_macos.sh`.
3. Ejecutar pruebas Swift.
4. Generar el proyecto Xcode.
5. Compilar Debug y Release.
6. Verificar la firma de cada ejecutable anidado.
7. Abrir la aplicación y ejecutar pruebas manuales.
8. Notarizar cuando se disponga de identidad y credenciales aprobadas.

## Firma

La fase `Firmar motores incluidos` llama a `Scripts/sign_embedded_engines.sh` después de copiar los recursos.

- `yt-dlp/yt-dlp_macos` y su carpeta `_internal` proceden de la distribución oficial descomprimida para macOS. Se conservan sus firmas originales y no se vuelven a firmar parcialmente con la identidad de ZEUVE.
- Deno, FFmpeg y FFprobe se firman con la identidad de ZEUVE y Hardened Runtime.
- `Scripts/verify_packaged_engines_macos.sh` verifica las cuatro firmas y ejecuta `yt-dlp --version` sobre la copia ya incluida en `ZEUVE.app`. La compilación se detiene si yt-dlp no arranca.
- La aplicación se firma posteriormente por Xcode con Hardened Runtime.

La firma puede modificar los bytes y el tamaño de los motores que se vuelven a firmar. Por decisión aprobada desde 0.2.2, el diagnóstico en ejecución no compara esos dos valores con `engines.json`; la integridad se comprueba antes de firmar mediante `verify_engines_macos.sh`.

## Dependencias dinámicas

`otool -L` debe mostrar únicamente:

- componentes de `/usr/lib`;
- frameworks o bibliotecas de `/System/Library`;
- bibliotecas incluidas dentro de `Resources/Engines` cuando exista una referencia relativa resoluble.

Se rechazan rutas Homebrew, MacPorts, `/usr/local` y dependencias externas no incluidas.

## App Sandbox

Permanece desactivado en 0.4.0. No debe activarse durante el empaquetado. La futura decisión exige una prueba específica de bookmarks, cookies, procesos anidados y salida a carpetas seleccionadas.

## Entorno actual de esta entrega

El proyecto incorpora la distribución oficial descomprimida de yt-dlp 2026.06.09 y conserva los demás motores de la versión recibida. La integración se ha validado a nivel de código fuera de macOS; la firma, la compilación Xcode y la apertura de `ZEUVE.app` deben comprobarse en un Mac Apple Silicon antes de considerar validado el paquete final.

La integridad de la distribución descomprimida se verifica como un árbol completo mediante `bundleSHA256`, `bundleSize` y `bundleFileCount`, además de la huella individual del ejecutable raíz.
