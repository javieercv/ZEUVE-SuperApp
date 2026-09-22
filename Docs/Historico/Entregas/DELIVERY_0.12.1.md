# Entrega — ZEUVE 0.12.1

## Estado

La carpeta activa `ZEUVE_Swift` contiene ZEUVE 0.12.1, build 43, y Descargador universal 0.7.1. No se crea otra carpeta ni un ZIP.

## Corrección entregada

- «Mejor calidad compatible» conserva contenido original de cualquier tipo.
- Los presets específicos de vídeo mantienen su función.
- La copia incluida antigua se migra sin restaurar ni borrar la lista de presets.
- Los presets personales se conservan.
- No cambian motores, red, privacidad, permisos, dependencias ni tratamiento de archivos.

## Validación

La entrega supera 195 pruebas XCTest, 45 pruebas Swift Testing y 52 pruebas Python, además de las compilaciones Swift Release y Xcode Debug ARM64, la validación documental y la verificación de motores. La aplicación compilada arranca como ZEUVE 0.12.1 (43) y migra el preset guardado a «Original sin convertir» sin exigir que el usuario restaure sus presets.
