# Resultados de pruebas ZEUVE 0.10.0

Fecha: 5 de agosto de 2026.
Entorno: Linux x86_64, Swift 6.2.1 y Python 3.

## Resultados

- `swift test`: 158 pruebas XCTest/Swift, 0 fallos.
- Swift Testing del Conversor: 45 pruebas, 0 fallos.
- `python3 -m unittest discover -s Tests/ScriptTests`: 32 pruebas, 0 fallos.
- Compilación del target `YouTubeDownloaderModule`: correcta.
- Sintaxis de helpers Python: correcta.
- Sintaxis Bash de preparación y verificación: correcta.
- Análisis sintáctico de las vistas SwiftUI/AppKit modificadas: correcto.

## Cobertura nueva

- plataformas y enlaces concretos;
- Instagram por usuario o perfil;
- perfiles privados y paginación;
- stories, foto de perfil y carruseles;
- contenido adulto y dominios personalizados;
- sesión pegada y conversión a Netscape con permisos 0600;
- historial de fotos de perfil;
- parser Wayback;
- gallery-dl con foto y vídeo;
- restauración de motores externos;
- manifiesto 0.6.0 y permiso explícito de cookies de navegador.

## Pendiente en macOS Apple Silicon

- preparar gallery-dl e instaloader-zeuve como ejecutables ARM64;
- ejecutar `verify_engines_macos.sh` y firma;
- compilar Debug/Release con Xcode;
- abrir la aplicación;
- validar Llavero, importación real desde navegadores, interfaz, VoiceOver y modos claro/oscuro;
- probar enlaces reales autorizados de cada plataforma;
- probar Wayback Machine y el navegador opcional;
- verificar Gatekeeper y empaquetado final.
