# Entrega ZEUVE 0.10.4

## Estado

La corrección de preparación del motor de perfiles públicos está completada en el proyecto fuente. El proyecto ya no contiene el ejecutable Instaloader 4.15.2 obsoleto y obliga a generar `instaloader-zeuve 4.15.3-zeuve.1` antes de compilar la aplicación macOS.

La validación final contra Instagram permanece pendiente de macOS Apple Silicon.

## Versiones

- Aplicación: ZEUVE 0.10.4.
- Build interno: 35.
- Descargador universal: 0.6.4.
- gallery-dl: 1.32.9.
- Instaloader: 4.15.3.
- Ayudante social: `instaloader-zeuve 4.15.3-zeuve.1`.

## Preparación y compilación en el Mac objetivo

Desde la raíz del proyecto:

```bash
./Scripts/build_macos.sh Release
```

El proceso debe:

1. detectar que falta el ejecutable Instaloader nuevo;
2. crear un entorno temporal de desarrollo;
3. instalar las versiones fijadas;
4. generar los ejecutables ARM64 mediante PyInstaller;
5. copiar sus licencias;
6. actualizar tamaños y SHA-256 reales en `engines.json`;
7. verificar los motores;
8. generar el proyecto Xcode y compilar;
9. verificar los motores incluidos en `ZEUVE.app`.

Si se desea preparar únicamente los motores sociales:

```bash
./Scripts/prepare_social_engines_macos.sh Resources/Engines
```

## Comprobación funcional recomendada

Después de compilar y abrir la aplicación en un Mac Apple Silicon, debe probarse al menos:

- un perfil público con publicaciones y reels;
- un perfil público con punto o guion bajo en el nombre;
- carga incremental de más de una página de resultados;
- descarga de una foto y un vídeo públicos;
- fallback a `gallery-dl` cuando Instaloader no resuelva;
- perfil inexistente;
- perfil privado sin sesión;
- perfil privado accesible con sesión autorizada;
- Stories y Destacadas con y sin sesión;
- cancelación, limpieza de temporales y ausencia de credenciales en logs.

## Contenido de la entrega

El ZIP contiene el proyecto completo: fuentes, recursos, módulos, pruebas, scripts, proyecto Xcode, documentación, historial de cambios y configuración. Excluye cachés, `.build`, `DerivedData`, logs, archivos temporales, datos privados y el ejecutable Instaloader 4.15.2 retirado.
