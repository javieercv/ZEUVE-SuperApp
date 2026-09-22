# Resultados de pruebas ZEUVE 0.10.4

## Entorno

- Sistema: Linux x86_64.
- Swift: toolchain disponible en el entorno de pruebas.
- Proyecto fuente: ZEUVE 0.10.4, build 35.
- No se utilizó el archivo JSONL real como dato permanente de prueba.

## Pruebas Python

Comando:

```bash
python3 -m unittest discover -s Tests/ScriptTests -p 'test_*.py' -v
```

Resultado:

- 45 pruebas ejecutadas.
- 45 superadas.
- 0 fallos.

Las regresiones específicas comprueban que:

- la preparación fija Instaloader 4.15.3;
- el helper, el comprobador y el actualizador del manifiesto fijan `4.15.3-zeuve.1`;
- `4.15.2-zeuve.3` se rechaza como revisión obsoleta;
- un manifiesto sin el ejecutable nuevo conserva tamaño cero, SHA-256 vacío y licencia `NOT_PROVIDED`;
- después de generar un ejecutable, el actualizador sustituye únicamente las entradas sociales y conserva las demás;
- los perfiles públicos mantienen el fallback a `gallery-dl` sin convertir una sesión en requisito general.

## Pruebas Swift

Comando:

```bash
swift test --jobs 1
```

Resultado:

- 166 pruebas XCTest superadas.
- 45 pruebas Swift Testing superadas.
- 211 pruebas Swift en total.
- 0 fallos.

La suite incluye la comprobación del manifiesto del Descargador universal 0.6.4 y su versión mínima ZEUVE 0.10.4.

## Compilación Swift de producción

Comando:

```bash
swift build -c release --jobs 1
```

Resultado:

- compilación completada correctamente en Linux x86_64;
- duración registrada: 92,33 segundos en el intento final;
- no equivale a una compilación Xcode de la aplicación macOS.

## Protección de originales

El ZIP original `ZEUVE_Swift_0.10.3.zip` no se modificó. Su SHA-256 antes y después del trabajo es:

```text
61065e879de83b540a342bd9d620051ed872857df4c6ed2c4dc6668276752825
```

El registro aportado y los archivos de reglas originales tampoco se incorporan al ZIP de entrega como datos de prueba.

## Pruebas pendientes en macOS Apple Silicon

No se han podido realizar en este entorno:

- instalación de Instaloader 4.15.3 desde PyPI durante la preparación macOS;
- generación PyInstaller del ejecutable ARM64;
- validación con `lipo`, firma y verificación de `codesign`;
- compilación mediante Xcode;
- apertura de `ZEUVE.app`;
- análisis real de uno o más perfiles públicos de Instagram;
- prueba de perfil privado autorizado, Stories y Destacadas con sesión válida;
- comprobación visual de la interfaz.

Por estas limitaciones, la corrección está implementada y probada lógicamente, pero la integración real con Instagram permanece pendiente de validación en el Mac objetivo.
