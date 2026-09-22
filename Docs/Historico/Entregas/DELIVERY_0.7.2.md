# Entrega ZEUVE 0.7.2

## Estado

Corrección del script de x264 integrada en el proyecto completo. La preparación física de motores debe reanudarse en el Mac Apple Silicon del usuario.

## Versión

- ZEUVE anterior: 0.7.1 build 22.
- ZEUVE entregada: 0.7.2 build 23.
- Conversor: 0.2.0 sin cambio de contrato.

## Cambio

La preparación de x264 utiliza únicamente `make install-lib-static`. Se elimina `install-headers`, que no existe en el Makefile de la revisión r3222 y detenía el proceso después de haber instalado correctamente la biblioteca estática, las cabeceras y `x264.pc`.


## Pruebas

- 138 pruebas Swift superadas.
- 37 pruebas específicas del Conversor superadas.
- 21 pruebas Python de scripts y políticas superadas.
- Sintaxis Bash de los scripts modificados superada.
- La compilación Release fue iniciada, pero no terminó dentro del límite del entorno y no se presenta como superada.

## Siguiente validación requerida

En macOS Apple Silicon:

```bash
./Scripts/prepare_engines_macos.sh 2>&1 | tee prepare_engines_0.7.2.log
./Scripts/verify_engines_macos.sh 2>&1 | tee verify_engines_0.7.2.log
```

Solo después de que ambos comandos terminen correctamente deben comprimirse y remitirse `Resources/Engines` y los dos registros.
