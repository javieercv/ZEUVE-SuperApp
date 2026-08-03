# Entrega — ZEUVE 0.2.4

Fecha: 2 de julio de 2026.

## 1. Resumen

Se ha optimizado el Descargador de YouTube sin cambiar su interfaz ni introducir descargas paralelas. ZEUVE reutiliza el diagnóstico de motores durante la sesión, activa una caché local controlada de yt-dlp, incorpora la distribución oficial descomprimida de macOS y registra localmente los tiempos de las fases principales.

## 2. Estado

Implementación completada y probada mediante SwiftPM y pruebas de scripts. Pendiente de validación final de la aplicación empaquetada en macOS Apple Silicon.

## 3. Cambios principales

- Diagnóstico compartido y cacheado para yt-dlp, Deno, FFmpeg y FFprobe.
- Invalidación automática si cambian los archivos y comprobación manual forzada.
- Caché en `~/Library/Caches/ZEUVE/yt-dlp`, local y excluida de copias de seguridad.
- Sustitución del ejecutable autónomo por `yt-dlp_macos.zip` 2026.06.09 descomprimido.
- Registros locales de duración para resolución de motores, análisis, descarga/posprocesado, FFprobe y publicación.
- Procesamiento secuencial y validación final con FFprobe conservados.
- Scripts de preparación, firma, verificación e integración adaptados al nuevo árbol de yt-dlp.

## 4. Pruebas

- 65 pruebas Swift superadas.
- 11 pruebas Python superadas.
- Sintaxis shell, Python y Swift validada.
- Manifiesto y huellas del nuevo yt-dlp comprobados.
- Proyecto Xcode regenerado.
- Compilación SwiftPM Release superada.
- Validaciones no exclusivas de macOS de `verify_project.sh` superadas.

Los detalles y limitaciones figuran en `Docs/TEST_RESULTS_0.2.4.md`.

## 5. Versión

- Versión anterior: 0.2.3, build 9.
- Versión nueva: 0.2.4, build 10.
- Motivo: optimización compatible del rendimiento del Descargador de YouTube.

## 6. Limitaciones

No se pudo compilar ni abrir `ZEUVE.app`, validar firmas reales ni medir una descarga en macOS. No se ha afirmado que el paquete final macOS funcione hasta completar esas pruebas en Apple Silicon.

## 7. Privacidad y alcance

No se añadieron APIs, telemetría, actualizaciones automáticas, servicios externos ni dependencias que el usuario deba instalar. La caché y los registros permanecen en el Mac. No se modificó el Organizador ni otras funciones no relacionadas.

La integridad de la distribución descomprimida se verifica como un árbol completo mediante `bundleSHA256`, `bundleSize` y `bundleFileCount`, además de la huella individual del ejecutable raíz.
