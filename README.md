# ZEUVE 0.20.3.0

ZEUVE es una aplicación nativa y modular para **macOS 14+ en Apple Silicon** que reúne distintas herramientas de uso local dentro de una única aplicación.

El proyecto prioriza la privacidad, la protección de los archivos originales, la ejecución local y una arquitectura modular que permita seguir ampliando ZEUVE sin convertir cada herramienta en una aplicación separada.

## Módulos actuales

ZEUVE incluye actualmente:

- **Organizador**
- **Descargador universal**
- **Analizador de chats**
- **Conversor universal**
- **Comparador de seguidores de Instagram**
- **Inspector multimedia**
- **Limpiador**

Además, la aplicación dispone de **Historial**, ajustes centralizados y personalización del orden y los atajos de los módulos.

## Principios del proyecto

ZEUVE está diseñado con varias reglas permanentes:

- procesamiento local siempre que sea posible;
- sin telemetría ni analítica;
- protección de los archivos originales;
- publicación segura de resultados sin sobrescrituras silenciosas;
- privacidad y minimización de datos;
- operaciones pesadas coordinadas y cancelables;
- motores externos ejecutados con argumentos validados y sin comandos de shell interpolados;
- ajustes centralizados para las preferencias configurables;
- validación específica de los resultados antes de darlos por correctos.

Los detalles completos de arquitectura, seguridad, privacidad y comportamiento se mantienen en la documentación del proyecto.

## Plataforma

- **macOS 14 o posterior**
- **Apple Silicon**
- **Swift 6**
- **SwiftUI**, con AppKit cuando es necesario
- Hardened Runtime
- Sin App Sandbox en la fase actual del proyecto

## Motores y dependencias

Algunas funciones utilizan motores locales incluidos o preparados para ZEUVE, como **FFmpeg** y **FFprobe**.

Los motores no se descargan ni actualizan automáticamente al abrir la aplicación. Su preparación, validación y empaquetado están documentados en la sección de motores y compilación.

## Compilación y pruebas

Desde la carpeta raíz del proyecto:

```bash
./Scripts/run_tests.sh
./Scripts/verify_project.sh
./Scripts/build_macos.sh Release
```

La validación final de Xcode, firma, Hardened Runtime, SwiftUI/AppKit y motores ARM64 debe realizarse en un Mac Apple Silicon compatible.

## Documentación

La documentación completa está organizada en:

**[Docs/INDEX.md](Docs/INDEX.md)**

Desde ese índice se puede acceder a:

- arquitectura, alcance, seguridad, compilación y pruebas;
- documentación funcional de cada módulo;
- desarrollo y API de módulos;
- motores y empaquetado;
- informes de implementación;
- resultados de pruebas;
- entregas e histórico de versiones.

El `README.md` describe únicamente el estado general actual de ZEUVE. El detalle técnico y el historial de desarrollo se mantienen en `Docs/`.

## Estado actual

La versión actual del proyecto es **ZEUVE 0.20.3.0**.

La información detallada de esta entrega y de versiones anteriores se conserva en **[Docs/Historico](Docs/Historico/)**.
