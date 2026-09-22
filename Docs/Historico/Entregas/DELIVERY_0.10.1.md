# Entrega ZEUVE 0.10.1

## Resumen

Corrección del soporte de Instagram del Descargador universal: clasificación estable, mensajes de autenticación útiles, logs completos y una compilación que ya no puede omitir silenciosamente los motores especializados.

## Estado

Código, scripts, pruebas y documentación integrados. Pruebas lógicas disponibles ejecutadas en Linux. Pendientes la generación de los ejecutables ARM64, la compilación Xcode, la firma, la apertura y las pruebas reales de Instagram en macOS Apple Silicon.

## Protección

El ZIP original 0.10.0 no se modificó. La entrega se genera desde una copia de trabajo y excluye cachés, sesiones, cookies, logs, datos privados, temporales, `__MACOSX` y restos de compilación.

## Compilación recomendada

Usar `Scripts/build_macos.sh`. Si `gallery-dl` o `instaloader-zeuve` faltan, el script los prepara, actualiza `engines.json`, verifica el conjunto y solo entonces compila. Una build directa desde Xcode se detiene hasta que esos motores estén preparados.
