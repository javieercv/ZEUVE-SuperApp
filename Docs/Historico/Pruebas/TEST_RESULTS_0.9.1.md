# Resultados de pruebas — ZEUVE 0.9.1

## Pruebas Swift

La suite completa se ejecutó en Linux x86_64 con Swift 6.2.1:

- 138 pruebas XCTest superadas;
- 45 pruebas Swift Testing superadas;
- 183 pruebas Swift en total;
- 0 fallos.

La selección específica del Descargador universal ejecutó 39 pruebas, todas superadas.

## Regresiones añadidas

Se comprobó que:

- los vídeos encontrados en páginas ignoran resolución, formato, audio, bitrate, HDR, subtítulos, miniaturas, capítulos y archivos auxiliares;
- los enlaces directos mantienen formatos exactos, contenedor y metadatos seleccionados;
- el comando original no fuerza contenedor ni recodificación;
- los nombres `de ig 3 (1)`, `(3)` y `(5)` se convierten en `de ig 3 (1)`, `(2)` y `(3)`;
- dos títulos idénticos numeran también el primero;
- un título único como `Película (1976)` no se altera;
- la URL de procedencia elimina tokens, seguimiento y fragmentos, pero conserva el identificador útil de la página;
- los metadatos usan copia directa, dominio, ID y fecha solo cuando se solicita;
- los ajustes anteriores sin `pageSource` se decodifican con todas las opciones desactivadas;
- las opciones de procedencia se almacenan en los ajustes centralizados.

## Prueba funcional sintética de metadatos

Se creó un MP4 sintético de un segundo con vídeo H.264 y audio AAC. Se insertaron URL, dominio e ID de página mediante FFmpeg con copia directa de streams. FFprobe recuperó los campos y las huellas SHA-256 de los streams de vídeo y audio coincidieron antes y después. Esta prueba demuestra que el flujo ensayado no recodificó el contenido sintético.

## Pruebas Python y estáticas

La suite de scripts incluye 30 pruebas: las 26 regresiones existentes y cuatro nuevas comprobaciones del Descargador universal. Verifican la disponibilidad de red y cookies en modo original, las ayudas contextuales, la política explícita del comando y el empaquetado de nombre y procedencia.

Las vistas y ViewModels modificados superaron `swiftc -frontend -parse`. El proyecto Xcode se regeneró con versión 0.9.1 y build 29.

## Compilación

El target `YouTubeDownloaderModule` compiló correctamente en configuración Release. La compilación Release completa se inició en Linux y no mostró errores antes de ser interrumpida por el límite temporal del entorno; por ello no se considera completada en este informe salvo que una comprobación posterior de la entrega indique lo contrario.

## No validado en este entorno

- apertura de la aplicación;
- interfaz SwiftUI y AppKit;
- atributo real «De dónde» en macOS;
- firma, Hardened Runtime y Gatekeeper;
- motores ARM64 dentro de una `.app` firmada;
- descargas reales desde páginas externas;
- accesibilidad y experiencia visual final.

Estas comprobaciones requieren un Mac Apple Silicon.
