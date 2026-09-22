# Entrega — ZEUVE 0.8.0

## Contenido

- Proyecto completo ZEUVE 0.8.0, build 27.
- Nuevo módulo `InstagramFollowersModule` 0.1.0.
- Código fuente Swift y SwiftUI.
- Pruebas automáticas.
- Manifiesto e integración Xcode/SwiftPM.
- Documentación y scripts de verificación actualizados.

## Privacidad

La entrega no contiene exportaciones reales de Instagram, nombres de usuario reales, resultados, cachés, bases de datos locales, logs ni rutas privadas.

## Elementos excluidos del ZIP

- `.build` y otros resultados de compilación;
- `.swiftpm`;
- `xcuserdata`;
- `__MACOSX`, `.DS_Store` y archivos `._*`;
- logs, temporales y cachés;
- repositorio `.git`.

## Estado de validación

El núcleo del módulo se valida en Linux x86_64 mediante 21 pruebas específicas. La suite completa alcanza 128 pruebas XCTest, 45 pruebas Swift Testing y 26 pruebas Python sin fallos. `Scripts/verify_project.sh` y la compilación SwiftPM Release se han completado correctamente. La compilación del target de aplicación y la prueba visual continúan pendientes de un Mac Apple Silicon con Xcode.

La copia extraída del ZIP también compila el target del comparador y supera sus 21 pruebas específicas.

## Publicación

Esta entrega se prepara como ZIP completo y se mantiene como fuente local.
