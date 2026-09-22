# Resultados de pruebas — ZEUVE 0.11.3

Fecha: 22 de agosto de 2026.

## Regresiones disponibles en este entorno

- `python3 -m unittest discover -s Tests/ScriptTests -p 'test_*.py'`: 49 pruebas superadas, 0 fallos.
- `bash -n Scripts/*.sh`: sintaxis correcta en los scripts Bash.
- Manifiestos JSON del Descargador y de motores: lectura correcta.
- `python3 Scripts/generate_xcode_project.py`: proyecto regenerado correctamente con 23 archivos Swift de aplicación.
- Bloque estructural de `Scripts/verify_project.sh` que no depende de Swift/Xcode: superado; incluye versión, manifiestos, privacidad, políticas de motores, documentación modular y las 49 regresiones Python.
- `python3 Scripts/validate_module_docs.py`: documentación de módulos y ejemplos JSON validados correctamente.

La nueva cobertura comprueba la activación del respaldo cuando gallery-dl falla o termina con cero archivos, la conservación de la URL pública estable reportada, la exigencia de salida también para yt-dlp, la clasificación accionable y la presentación visible de un fallo total.

## Limitaciones verificadas

El entorno de trabajo es Linux x86_64 y no contiene Swift, Xcode ni los frameworks de macOS. Por ello:

- `Scripts/run_tests.sh` se detuvo al invocar `swift` y devolvió código 127.
- `Scripts/verify_project.sh` se detuvo por la misma ausencia de `swift` y devolvió código 127.
- No se compilaron las pruebas Swift ni `ZEUVE.app`.
- No se ejecutaron los binarios Mach-O ARM64 incluidos, FFprobe, firma, Gatekeeper ni apertura real de la aplicación.
- No se realizó una descarga de red del TikTok reportado; el enlace se utilizó como entrada exacta de la regresión de comandos y política.

## Validación pendiente en Mac Apple Silicon

Se debe ejecutar `Scripts/run_tests.sh`, `Scripts/verify_project.sh` y una descarga autorizada del enlace reportado. Debe confirmarse tanto la ruta principal como el cambio `gallery-dl` → `yt-dlp`, la validación FFprobe, la publicación del archivo y el mensaje visible si ambos motores fallan.

## Validación del ZIP fuente

- `python3 Scripts/package_release.py --skip-verify`: ZIP completo generado; se omite la verificación integral porque este entorno no dispone de Swift.
- `unzip -tq`: integridad del archivo comprimido superada.
- Inspección interna: una única raíz `ZEUVE_Swift_0.11.3`, 502 archivos, sin cachés, builds, datos privados de Xcode, `.DS_Store`, AppleDouble, logs ni temporales prohibidos.
- El validador especializado reconoce la versión y ya no detecta cabeceras o decisiones activas obsoletas. Mantiene un error de empaquetado preexistente porque la fuente aportada no contiene `.agents/skills/zeuve-development/SKILL.md`; no se creó configuración de agentes fuera del alcance aprobado.
- El mismo validador avisa de `certifi/cacert.pem`; se revisó como el almacén público de autoridades certificadoras incluido dentro del paquete oficial de yt-dlp, no como una clave o credencial privada.
