# Resultados de pruebas — ZEUVE 0.11.5

## Validación real de Instagram público

Se ejecutó el `instaloader-zeuve 4.15.3-zeuve.2` final sin cookies ni sesión contra casos públicos de los repositorios de pruebas de los motores:

| Caso | URL | Resultado |
|---|---|---|
| Foto | `https://www.instagram.com/p/BqvsDleB3lV/` | 1 JPEG, 383.468 bytes |
| Vídeo | `https://www.instagram.com/p/Bqxp0VSBgJg/` | 1 MP4, 6.190.705 bytes |
| Reel | `https://www.instagram.com/reel/Chunk8-jurw/` | 1 MP4, 918.120 bytes |
| Carrusel de fotos | `https://www.instagram.com/p/DaBUYYOjNgA/` | 5 WebP, 177.348 bytes en total |
| Carrusel mixto | `https://www.instagram.com/p/DJUhR65z9Df/` | 19 elementos: 17 JPEG y 2 MP4, 15.611.433 bytes en total |

Los 27 archivos se descargaron desde las referencias resueltas usando la identidad HTTP de ZEUVE. Todos fueron no vacíos y superaron la firma de JPEG, WebP o MP4 correspondiente. No se perdió ningún nodo, no se utilizó sesión y no hubo conversión. El carrusel de fotos conserva WebP porque tanto la ruta del CDN como su `Content-Type` declararon WebP.

## Regresiones focalizadas

- 13 pruebas Python del adaptador de Instagram: 0 fallos.
- 8 pruebas Python de preparación de motores sociales: 0 fallos.
- 84 pruebas XCTest del módulo Descargador universal: 0 fallos.

La cobertura comprueba orden de motores, sidecars mixtos completos, ausencia de sesión pública, clasificación de privacidad, formato real del CDN, automático por elemento, YouTube MP3 320, orígenes no YouTube sin conversión y controles manuales.

## Validación integral y empaquetado

- `Scripts/run_tests.sh`: 185 pruebas XCTest, 45 pruebas Swift Testing y 52 regresiones Python; 282 pruebas en total, 0 fallos.
- `Scripts/verify_project.sh`: correcto; incluye pruebas, compilación Swift Release, políticas estructurales y de privacidad, documentación, motores y compilación Xcode Debug.
- `Scripts/build_macos.sh Release`: `BUILD SUCCEEDED`; `ZEUVE.app` 0.11.5 (41), la firma profunda y todos los motores obligatorios empaquetados superaron la verificación.
- La aplicación Release abrió correctamente y aceptó la navegación al Descargador universal sin terminar. La captura de accesibilidad de la vista compleja no pudo completarse, pero el proceso permaneció estable y los controles de modo están cubiertos por compilación y regresiones.

Xcode solo mostró las notas esperadas de fases de firma/verificación ejecutadas en cada build y el aviso informativo de ausencia de App Intents. No se generó ningún ZIP.
