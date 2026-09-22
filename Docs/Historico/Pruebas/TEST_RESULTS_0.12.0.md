# Resultados de pruebas — ZEUVE 0.12.0

## Regresiones del Descargador

Las pruebas nuevas cubren perfiles de fábrica editables y restaurables, normalización privada de enlaces, coincidencia exacta y por subdominios, precedencia del host más específico, elección manual, conservación forzada del original para imágenes y colecciones, migración de valores anteriores y persistencia Codable.

La batería existente también se adapta al nuevo significado de «Por defecto de la plataforma» y al modo manual «Original».

## Verificación realizada

- `swift test --filter YouTubeDownloaderModuleTests`: 91 pruebas, 0 fallos durante el desarrollo.
- Compilación Xcode Debug ARM64 sin firma: correcta.
- QA visual de Ajustes > Descargador universal > Plataformas: perfiles incorporados, restauración y formulario de alta presentes; el formulario se canceló sin modificar preferencias locales.
- `swift test`: 192 pruebas XCTest y 45 pruebas Swift Testing, 0 fallos.
- `Scripts/verify_project.sh`: correcto; repitió esas 237 pruebas, ejecutó 52 regresiones Python, validó documentación, privacidad, estructura y motores, compiló Swift Release y generó la aplicación Xcode Debug ARM64.
- Xcode terminó con `BUILD SUCCEEDED`; los motores obligatorios empaquetados superaron su verificación y firma local. Pandoc, que es opcional, no estaba incluido.

No se realizaron descargas reales ni se transmitieron enlaces durante esta entrega; la funcionalidad de motores y red conserva la cobertura previa.
