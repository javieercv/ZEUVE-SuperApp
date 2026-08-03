# Entrega ZEUVE 0.7.1

## Estado

Corrección completada y probada a nivel de código y scripts. La preparación física de los motores continúa pendiente de repetirse en el Mac Apple Silicon del usuario.

## Versión

- ZEUVE anterior: 0.7.0 build 21.
- ZEUVE entregada: 0.7.1 build 22.
- Conversor: 0.2.0 sin cambio de contrato.

## Cambio

La descarga de respaldo de la licencia de Calibre 9.11.0 utiliza ahora el archivo oficial `LICENSE`. La referencia a `COPYING`, que devolvía HTTP 404, ha sido eliminada y protegida mediante una prueba de regresión.


## Pruebas

- 138 pruebas Swift superadas.
- 37 pruebas específicas del Conversor superadas.
- 20 pruebas Python de scripts y políticas superadas.
- Sintaxis Bash, documentación de módulos y controles estáticos relacionados superados.
- La compilación Release no finalizó dentro del límite del entorno y no se presenta como superada.

## Siguiente validación requerida

En macOS Apple Silicon:

```bash
./Scripts/prepare_engines_macos.sh 2>&1 | tee prepare_engines_0.7.1.log
./Scripts/verify_engines_macos.sh 2>&1 | tee verify_engines_0.7.1.log
```

Solo después de que ambos comandos terminen correctamente deben comprimirse y remitirse `Resources/Engines` y los dos registros.
