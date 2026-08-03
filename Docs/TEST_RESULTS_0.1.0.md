# Resultados de pruebas — ZEUVE 0.1.0

Fecha: 1 de julio de 2026

## Entorno disponible

```text
Swift version 6.2.1 (swift-6.2.1-RELEASE)
Target: x86_64-unknown-linux-gnu
Linux 73a907feab06 4.4.0 #1 SMP Sun Jan 10 15:06:54 PST 2016 x86_64 GNU/Linux
```

Este entorno es Linux x86_64. Sirve para compilar y probar los paquetes Swift independientes de la interfaz, pero no incluye AppKit, SwiftUI para macOS, Xcode ni el SDK de macOS.

## Pruebas automáticas

Comando:

```bash
swift test
```

Resultado final:

- 30 pruebas ejecutadas.
- 30 superadas.
- 0 fallos.

Cobertura funcional comprobada:

- validación, orden y duplicados de manifiestos;
- serialización del protocolo de módulos;
- registro local JSONL;
- exclusión de operaciones pesadas simultáneas;
- progreso y solicitud de cancelación;
- persistencia SQLite de ajustes e historial;
- clasificación simple y detallada;
- extensiones equivalentes y reglas personalizadas;
- agrupación de archivos relacionados;
- archivos ocultos, temporales, enlaces simbólicos y paquetes;
- recorrido opcional de subcarpetas;
- conflictos con renombrado u omisión;
- planificación de una carpeta con 1.201 archivos;
- selección parcial;
- invalidación de la vista previa si cambia un origen;
- protección si aparece un destino después de analizar;
- cancelación sin movimientos y cancelación tras un movimiento con reversión;
- exportación CSV;
- ejecución, historial y deshacer;
- protección frente a resultados modificados;
- conservación de carpetas que contienen archivos ajenos.

## Compilación comprobada

- Paquetes Swift en configuración Debug: correcta.
- Paquetes Swift en configuración Release: correcta.
- Análisis sintáctico de todos los archivos SwiftUI/AppKit: correcto.
- Generación y comprobación estructural de `ZEUVE.xcodeproj`: correcta.

## No comprobado en este entorno

- compilación de la aplicación con Xcode;
- enlace real con AppKit y SwiftUI de macOS;
- apertura de `ZEUVE.app`;
- aspecto visual, navegación, diálogos y arrastrar y soltar;
- ejecución ARM64 nativa;
- firma, notarización y App Sandbox.

Estas comprobaciones quedan expresamente pendientes de ejecutarse en un Mac Apple Silicon con Xcode. No se considera que la aplicación macOS esté compilada o probada visualmente hasta completar esa fase.
