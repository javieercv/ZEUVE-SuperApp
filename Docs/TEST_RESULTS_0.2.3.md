# Resultados de pruebas — ZEUVE 0.2.3

Fecha: 2 de julio de 2026.

## Entorno utilizado

- Sistema disponible: Linux x86_64.
- Swift: toolchain compatible con Swift 6.
- Python 3 para validaciones y pruebas de scripts.
- Sin macOS, Xcode, `codesign`, `otool` ni posibilidad de abrir una aplicación `.app`.
- Sin pruebas online contra YouTube.

## Pruebas ejecutadas

### Suite Swift

Comando:

```bash
./Scripts/run_tests.sh
```

Resultado:

- 62 pruebas ejecutadas.
- 62 superadas.
- 0 fallos.
- Compilación Debug de SwiftPM superada.

Las dos pruebas Swift añadidas verifican:

- conservación y presentación de código de salida, señal, salida estándar y salida de error;
- compatibilidad al decodificar diagnósticos anteriores que no contienen `technicalDetails`.

### Pruebas Python

Ejecutadas mediante `unittest`:

- 11 pruebas ejecutadas.
- 11 superadas.
- 0 fallos.

Las tres pruebas nuevas verifican que:

- `yt-dlp/yt-dlp` está en la lista cuya firma original se conserva y no en la lista que se vuelve a firmar;
- el verificador del paquete ejecuta `yt-dlp --version` y valida las firmas con `codesign`;
- la compilación por Terminal vuelve a comprobar la aplicación final después de `xcodebuild`.

### Validación completa del proyecto

Comando:

```bash
./Scripts/verify_project.sh
```

Resultado: superado en el entorno disponible. El script volvió a ejecutar las 62 pruebas Swift y las 11 pruebas Python, compiló SwiftPM en Release, validó documentación y manifiestos, analizó la sintaxis de las vistas y regeneró el proyecto Xcode. La parte exclusiva de macOS se omitió de forma explícita.

Se comprobaron:

- sintaxis de los scripts shell;
- compilación sintáctica de los scripts Python;
- versión 0.2.3 y build 9;
- versión 0.2.3 del manifiesto del módulo;
- presencia del nuevo verificador del paquete;
- ausencia de refirma de yt-dlp en la lista de ejecutables firmados por ZEUVE;
- presencia de “Detalles técnicos” en la interfaz;
- regeneración del proyecto Xcode;
- compilación SwiftPM Release.

## Integridad de los motores

Los cuatro motores de `Resources/Engines` se mantuvieron sin modificaciones respecto al ZIP 0.2.2 recibido. No se recompilaron ni sustituyeron ejecutables.

## Pruebas no realizadas

No se pudieron ejecutar en este entorno:

- `codesign --verify` sobre la firma real de los motores;
- `yt-dlp --version` dentro de una aplicación compilada y firmada;
- compilación Debug o Release mediante Xcode;
- apertura de `ZEUVE.app`;
- diagnóstico visual real en macOS;
- análisis o descarga real desde YouTube;
- Gatekeeper y notarización.

Estas comprobaciones deben realizarse en un Mac Apple Silicon. La corrección no debe considerarse validada en la aplicación final hasta completar al menos la compilación, apertura, diagnóstico y análisis real de un enlace.
