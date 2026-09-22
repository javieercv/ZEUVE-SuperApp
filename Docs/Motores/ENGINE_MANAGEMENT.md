# Gestión avanzada de motores del Descargador universal

## Principio

ZEUVE conserva siempre los motores incluidos dentro de la aplicación. Las versiones instaladas por el usuario se almacenan aparte en `~/Library/Application Support/ZEUVE/Engines/` y pueden restaurarse sin reinstalar la app.

## Advertencia obligatoria

Actualizar o sustituir un motor puede cambiar su comportamiento, introducir incompatibilidades o provocar que algunas descargas dejen de funcionar. Esta advertencia se muestra también para versiones estables. Las versiones experimentales o nightly añaden una advertencia reforzada.

## Instalar una versión

1. Obtén un ejecutable ARM64 de una fuente oficial o prepara el motor con los scripts del proyecto.
2. Abre Ajustes > Descargador universal > Motores.
3. Elige el nombre del motor y el canal estable o experimental.
4. Indica la versión y selecciona el ejecutable local.
5. Revisa la advertencia y confirma.
6. Ejecuta Diagnóstico antes de una descarga real.

ZEUVE comprueba que sea un archivo regular, ejecutable, que el nombre y la versión sean seguros, calcula SHA-256 y copia primero a un temporal antes de activarlo.

## Restaurar

En «Versiones activas externas», pulsa «Restaurar incluida». El registro externo se desactiva y vuelve a utilizarse el motor firmado incluido con ZEUVE. Los archivos originales de la aplicación nunca se modifican.

## Preparar gallery-dl e Instagram

En macOS Apple Silicon:

```bash
./Scripts/prepare_social_engines_macos.sh /ruta/a/Resources/Engines
```

El script fija `gallery-dl 1.32.9`, `Instaloader 4.15.3`, `browser-cookie3 0.20.1` y `PyInstaller 6.16.0`, genera ejecutables ARM64, valida sus versiones, copia las licencias y actualiza en `engines.json` los tamaños y SHA-256 reales. Es un paso manual: `build_macos.sh` y Xcode no lo ejecutan automáticamente, pero desde 0.11.2 rechazan compilar si esos motores obligatorios faltan.

## Navegador opcional

`playwright-browser` se conserva en el manifiesto de motores como marcador de compatibilidad futura y sigue declarado como no proporcionado. Desde ZEUVE 0.12.3 no existe una opción visible ni una ruta efectiva que lo ejecute, porque el contrato anterior no estaba implementado de extremo a extremo. No se descarga, instala ni actualiza en segundo plano.

## Modificar motores

Un usuario avanzado puede sustituir un ejecutable, pero debe mantener su contrato de argumentos y salida. Una modificación incompatible puede impedir que ZEUVE analice el resultado, cancele correctamente o reconozca los archivos. Debe conservarse una copia fuera del proyecto y probarse con contenido autorizado.
