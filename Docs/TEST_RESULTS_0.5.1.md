# Resultados de pruebas — ZEUVE 0.5.1

Fecha: 3 de julio de 2026.

## Objetivo

Validar las correcciones de importación del Analizador de chats sin modificar el comportamiento aprobado del Organizador, el Descargador de YouTube o el resto del motor estadístico.

## Pruebas Swift

Comando:

```bash
swift test --jobs 1
```

Resultado final:

- 97 pruebas ejecutadas;
- 97 superadas;
- 0 fallos;
- compilación Debug de todos los paquetes completada.

La cobertura nueva comprueba:

- un `_chat.txt` de WhatsApp mayor de 256 KB se detecta sin tratar la muestra como límite del archivo;
- el límite por archivo está desactivado por defecto y, cuando se configura, rechaza el archivo completo sin análisis parcial;
- un TXT directo diferencia los adjuntos no comprobados de los realmente faltantes;
- los nombres `-STICKER-...webp` se clasifican como stickers y un WEBP normal sigue siendo una imagen;
- un ZIP de Instagram con la conversación directamente en su raíz lógica se cataloga correctamente;
- las rutas multimedia heredadas de una exportación completa se reubican hacia el archivo realmente presente;
- la persistencia conserva el nuevo ajuste sin alterar una operación que ya tomó una copia de los valores predeterminados.

## Pruebas Python

Comando:

```bash
python3 -m unittest discover -s Tests/ScriptTests -p 'test_*.py' -v
```

Resultado final:

- 11 pruebas ejecutadas;
- 11 superadas;
- 0 fallos.

## Pruebas con los archivos reales aportados

Los archivos reales se procesaron únicamente desde su ubicación original y mediante pruebas temporales que se eliminaron después. No se copiaron al proyecto, a los fixtures ni al ZIP de entrega.

### WhatsApp

- 34.549 mensajes reconocidos tanto desde el ZIP como desde el TXT;
- 1.061 adjuntos referenciados dentro del ZIP;
- 0 adjuntos faltantes dentro del ZIP;
- 99 stickers correctamente clasificados;
- al analizar únicamente el TXT, 1.061 adjuntos se marcan como no comprobados y 0 como faltantes.

### Instagram

- una conversación detectada y preparada para selección automática;
- 3 páginas HTML procesadas;
- 27.781 mensajes reconocidos;
- 555 adjuntos referenciados;
- 0 adjuntos faltantes después de adaptar las rutas del ZIP individual.

Las huellas SHA-256 de los dos ZIP reales y del ZIP original del proyecto se volvieron a comprobar al terminar para confirmar que no habían cambiado.

## Validación global

`Scripts/verify_project.sh` se ejecutó completo y finalizó correctamente. Incluyó:

- 97 pruebas Swift;
- compilación SwiftPM Release;
- 11 pruebas Python;
- validación de versión, manifiestos y documentación;
- comprobaciones estáticas de privacidad, lectura progresiva, límite opcional, interfaz dinámica y selección automática;
- análisis sintáctico de todas las fuentes de `ZEUVEApp`;
- regeneración del proyecto Xcode;
- comprobación sintáctica de scripts shell y Python.

## Entorno y pruebas no disponibles

El entorno utilizado es Linux x86_64 con Swift 6.2.1 y Python 3.13.5. No permite:

- compilar el objetivo `ZEUVE.app` mediante Xcode;
- abrir la aplicación real de macOS;
- comprobar manualmente `NSOpenPanel`, arrastrar y soltar o la apariencia del cuadro dinámico;
- verificar VoiceOver, claro/oscuro, firma, Hardened Runtime, Gatekeeper o notarización;
- medir el rendimiento final en un Mac Apple Silicon con chats de varios millones de mensajes.

El código SwiftUI/AppKit se analizó sintácticamente, pero esa comprobación no sustituye la compilación y apertura en macOS.
