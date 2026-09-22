# Entrega ZEUVE 0.12.4

Fecha: 2026-09-07  
Build: 46

La carpeta activa `ZEUVE_Swift` contiene la intervención global de robustecimiento aprobada sobre la Fase 5. Se mantiene esta misma raíz de trabajo y no se genera otro ZIP ni una carpeta versionada salvo petición expresa del usuario.

## Estado funcional

- Descargador con ciclo estructurado, tarea de sesión independiente, descarga unificada y cancelación de procesos ligada a la `Task` propietaria.
- Analizador con SQLite temporal como fuente principal, importación/analíticas por lotes, búsqueda paginada y lectura ZIP cancelable.
- ZIP con rutas normalizadas duplicadas rechazado de acuerdo con la política de seguridad documentada.
- Logs minimizados, con retención automática de 30 días / 50 MiB y permisos restrictivos cuando la plataforma lo permite.
- Wayback manual mediante sesión efímera dedicada.
- Bookmarks de salida conservados ante fallos no concluyentes de resolución.
- Fallos no críticos de logger/registro de motores visibles como degradación segura de arranque.

No cambia la UI, las plataformas, los motores, los formatos, las dependencias, App Sandbox, permisos, endpoints aprobados, historial visible ni las claves de compatibilidad.

## Validación portable

La suite disponible queda en 214 XCTest con 0 fallos y 1 omitida por requerir macOS Apple Silicon, 47 pruebas Swift Testing con 0 fallos y 79 pruebas Python con 0 fallos. Se han actualizado los verificadores de la Fase 5 para proteger las nuevas garantías y la coherencia de versión/build pasa a 0.12.4/46.

Los verificadores portables restantes pasan individualmente: integración de app, estructura, motores, documentación, rendimiento, módulos, manifiestos, parseo de las 54 fuentes Swift de `ZEUVEApp` y coherencia SwiftPM/Xcode con 9 productos enlazados. El build `swift build -c release --jobs 1` del contenedor Linux supera su ventana máxima de ejecución sin mostrar errores antes del corte, por lo que no se considera una validación Release completa.

## Validación final macOS

La compilación real de `ZEUVEApp`, firma, Hardened Runtime, apertura, Keychain y motores ARM64 deben validarse en macOS Apple Silicon. `Scripts/verify_app_macos.sh` es la comprobación específica de aplicación y no se considera sustituida por el parseo Swift portable.

## Empaquetado

No se crea ZIP automáticamente. `python3 Scripts/package_release.py` solo se ejecutará cuando el usuario solicite expresamente el paquete final.
