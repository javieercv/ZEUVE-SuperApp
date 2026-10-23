# Alcance funcional vigente — ZEUVE 0.21.0.0

Este documento resume qué ofrece hoy la aplicación. Los detalles y límites de cada módulo viven en `Docs/Modulos/Funcionales/`.

## Superapp

ZEUVE integra siete módulos built-in, Inicio, Historial y Ajustes centralizados. El orden de módulos es personalizable y se comparte entre Sidebar, Inicio y comandos; los atajos de módulos e Historial también pueden personalizarse o desactivarse. No existe carga dinámica de plugins externos.

Las operaciones pesadas comparten `OperationCoordinator`; la aplicación evita ejecutar dos operaciones principales pesadas simultáneas. La privacidad, logs mínimos, protección de archivos y ejecución segura de motores son criterios transversales.

## Utilidades rápidas residentes — registro retirado

> Retirado del código el 23/10/2026 por decisión del usuario. Este apartado conserva el diseño y los límites del intento, no describe funciones actuales ni QA pendiente. Véase el [registro de retirada](../Historico/Implementacion/QUICK_UTILITIES_RETIREMENT_20261023.md).

Familia independiente en Ajustes, sin duplicar la barra lateral de módulos. Un icono de barra de menús permite recuperar la ventana, abrir Ajustes, consultar/activar funciones compatibles, detenerlas y salir. Inicio con macOS opt-in mediante `SMAppService.mainApp` y estados efectivos del sistema.

- Mezclador de aplicaciones compatibles en macOS 14.2+, con ruta de audio explícita y formatos/salidas limitados. Prueba explícita de reproducción privada al 100 % durante una llamada preparada por el usuario, con fuentes seguras elegidas y RMS agregado efímero. La prueba y el mezclador poseen sus rutas por separado. Protección durante llamadas pendiente de comparación real y eficacia, sin declaración de cumplimiento.
- Inversión de ruedas discretas vertical/horizontal; eventos continuos y gestos intactos. Asignaciones globales por índice para botones adicionales mediante atajos; no se garantiza identidad física ni aislamiento de otro ratón.
- Selector textual de ventanas con Accesibilidad, sin miniaturas ni permiso de pantalla. Perfiles de geometría con asociación explícita; después de reiniciar deben reasociarse las posiciones guardadas.
- Crear archivos nuevos mediante panel y Servicios con carpeta seleccionada, plantillas y extensión permitida. No se promete un menú contextual universal de Finder.
- Bandeja flotante con referencias temporales en RAM y transformaciones de texto plano a través de Servicios; no son movimientos de archivos ni monitorización del portapapeles. RTF/RTFD se rechaza para proteger el formato.

Comportamiento, compatibilidad, restauración y aceptación: [Utilidades rápidas](../Utilidades/QUICK_UTILITIES.md). Quedan fuera brillo externo avanzado, capturas flotantes, reglas de reposo, drivers/KEXT, root/helpers privilegiados y plugins externos.

## Estado tras la retirada

Desde el 23/10/2026, ZEUVE conserva los siete módulos, Inicio, Historial y Ajustes. Las microutilidades descritas arriba ya no están disponibles. No se registra inicio de sesión ni se ofrecen Servicios o controles residentes.

## Organizador de archivos 0.1.5

- Selección/arrastre de carpetas y análisis previo.
- Clasificación por categorías/extensiones con vista previa y selección por operación.
- Agrupación opcional de archivos relacionados por nombre base.
- Recursión y archivos ocultos configurables.
- Políticas de conflictos, incluida renombrado seguro por defecto.
- Ejecución como movimiento real de archivos, historial y Undo verificable.
- Exportación CSV del plan/resultados y preferencias centralizadas.

No modifica rutas críticas del sistema, no sigue symlinks como archivos ordinarios y no usa red.

## Descargador universal 0.7.8

- Análisis y descarga desde URLs compatibles mediante rutas públicas y motores aprobados.
- YouTube, Instagram/social y descubrimiento web según las capacidades documentadas.
- Presets, favoritos, historial, progreso, cancelación y carpeta de salida persistente.
- Sesiones/cookies solo cuando el usuario las aporta o autoriza y la fuente realmente las requiere.
- Motores locales empaquetados/validados; overrides manuales desde archivo local para el subconjunto soportado.

No elude DRM, CAPTCHA, paywalls ni controles de acceso. El navegador Playwright no participa en el routing efectivo de 0.7.4.

## Analizador de chats 0.1.6

- Importación local de exportaciones compatibles de WhatsApp e Instagram.
- Parsing, deduplicación, filtros, búsqueda, métricas de actividad/participación/conversación y vistas analíticas.
- Manejo acotado de archivos comprimidos y almacenamiento temporal para datasets grandes.
- Historial agregado y ajustes centralizados.

No usa red ni conserva contenido privado completo en el historial global.

## Conversor universal 0.3.2

- Conversión local de imágenes, audio, vídeo, PDF, texto y datos en las rutas documentadas.
- FFmpeg/FFprobe para multimedia; APIs nativas cuando corresponda; Pandoc opcional para rutas compatibles cuando está preparado.
- Presets/favoritos, lotes, progreso/cancelación, validación y publicación segura.

Calibre, Ghostscript y LibreOffice no forman parte del producto actual. Ebook/EPS permanecen fuera del alcance aprobado salvo nueva decisión.

## Comparador de seguidores de Instagram 0.1.0

- Procesa exportaciones JSON seleccionadas por el usuario.
- Compara seguidores y seguidos localmente, tolera variantes previstas del formato y permite exportar resultados.
- Sin red, sesión de Instagram ni scraping.

## Inspector multimedia 0.7.5

- Inspección FFprobe de contenedores/streams, vídeo, audio, subtítulos, capítulos, metadata, attachments y carátulas.
- Preview local de audio y vídeo con transporte compartido, waveform, espectrograma y subtítulos cuando son viables.
- Sonoridad, señal, silencios/clipping, A/B, indicios explicables de fuente con pérdida y anomalías espectrales.
- OCR local/revisable de subtítulos bitmap mediante Vision cuando el flujo lo admite.
- Edición estructural segura de streams/metadata/capítulos/attachments/carátulas por stream copy, con Undo/Redo de borrador, planificación, FFmpeg, FFprobe y publicación segura.
- Lotes, carpetas/reglas, presets, favoritos e informes versionados.
- El preflight de edición por lotes respeta la exclusión global de operaciones, cancelación local/global y cierre coordinado antes de publicar el resultado.

No es un editor temporal/creativo y no recodifica audio/vídeo dentro del Inspector; una transformación que exige transcode pertenece al Conversor.

## Limpiador 0.1.4

- Inventario local de aplicaciones y asociaciones/residuos.
- Análisis de cachés/logs/tmp, restos, instaladores y contenido regenerable de desarrollo según reglas conservadoras.
- Desinstalación asistida con selección visible y protección de datos persistentes.
- Papelera por defecto, borrado permanente opt-in y Undo cuando los movimientos siguen verificables.
- Spotlight acotado/cancelable; una cobertura parcial no convierte aplicaciones históricas en “ausentes”.
- Los fallos de persistencia o filas inválidas detienen el plan en lugar de asumir que no hay inventario ni decisiones «Conservar»; un fallo secundario del historial tras Deshacer se comunica sin invalidar archivos ya restaurados.

No usa red, `sudo`, shell ni helper privilegiado. `scanLocalStorage` autoriza análisis en ubicaciones documentadas; retirar elementos exige `removeLocalItems`, selección y revalidación.

## Exclusiones transversales actuales

- Sin telemetría, analítica, anuncios o actualizaciones automáticas silenciosas.
- Sin App Sandbox en esta fase.
- Sin loader de módulos/plugins externos.
- Sin bypass de DRM, CAPTCHA, paywalls o privacidad.
- Sin Calibre, Ghostscript o LibreOffice.
- Sin modificación silenciosa de originales ni sobrescritura no confirmada.
