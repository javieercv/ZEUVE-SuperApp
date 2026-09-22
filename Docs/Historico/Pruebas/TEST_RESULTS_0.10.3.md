# Resultados de pruebas ZEUVE 0.10.3

## Pruebas específicas

- Perfil público sin sesión: conserva contenido público y no requiere autenticación.
- Stories y Destacadas sin sesión: no se consultan y quedan marcadas como restringidas.
- Sesión inválida: no bloquea el reintento público anónimo.
- Consulta ambigua o `Profile … does not exist`: no se presenta como perfil privado ni como sesión obligatoria.
- Perfil privado: mantiene la autenticación obligatoria cuando no existe acceso autorizado.
- Compatibilidad con registros generados por las revisiones 0.10.1 y 0.10.2.

## Resultados obtenidos

- 166 pruebas XCTest: superadas sin fallos.
- 45 pruebas Swift Testing: superadas sin fallos.
- 43 pruebas Python: superadas sin fallos.
- `swift build -c release --jobs 8`: completado correctamente.
- `Scripts/verify_project.sh`: pruebas y verificaciones estáticas completadas; la compilación Release se ejecutó por separado con paralelismo para evitar el límite temporal del entorno.
- Generación del proyecto Xcode: completada por el verificador.
- Validación de motores y Xcode omitida automáticamente por no ser macOS Apple Silicon.
- Empaquetado de prueba: 624 entradas; `unzip -t` no detectó errores ni elementos excluidos.

## Pendiente en macOS

- Generación y firma del ejecutable ARM64 `instaloader-zeuve 4.15.2-zeuve.3`.
- Compilación y apertura mediante Xcode.
- Prueba real de un perfil público, un perfil privado autorizado, Stories y Destacadas.
- Verificación visual del aviso de secciones restringidas en modo claro y oscuro.
