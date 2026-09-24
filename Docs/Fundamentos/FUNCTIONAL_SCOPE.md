# Alcance funcional vigente — ZEUVE 0.20.4.0

Este documento resume qué ofrece hoy la aplicación. Los detalles y límites de cada módulo viven en `Docs/Modulos/Funcionales/`.

## Superapp

ZEUVE integra siete módulos built-in, Inicio, Historial y Ajustes centralizados. El orden de módulos es personalizable y se comparte entre Sidebar, Inicio y comandos; los atajos de módulos e Historial también pueden personalizarse o desactivarse. No existe carga dinámica de plugins externos.

Las operaciones pesadas comparten `OperationCoordinator`; la aplicación evita ejecutar dos operaciones principales pesadas simultáneas. La privacidad, logs mínimos, protección de archivos y ejecución segura de motores son criterios transversales.

## Organizador de archivos 0.1.4

- Selección/arrastre de carpetas y análisis previo.
- Clasificación por categorías/extensiones con vista previa y selección por operación.
- Agrupación opcional de archivos relacionados por nombre base.
- Recursión y archivos ocultos configurables.
- Políticas de conflictos, incluida renombrado seguro por defecto.
- Ejecución como movimiento real de archivos, historial y Undo verificable.
- Exportación CSV del plan/resultados y preferencias centralizadas.

No modifica rutas críticas del sistema, no sigue symlinks como archivos ordinarios y no usa red.

## Descargador universal 0.7.3

- Análisis y descarga desde URLs compatibles mediante rutas públicas y motores aprobados.
- YouTube, Instagram/social y descubrimiento web según las capacidades documentadas.
- Presets, favoritos, historial, progreso, cancelación y carpeta de salida persistente.
- Sesiones/cookies solo cuando el usuario las aporta o autoriza y la fuente realmente las requiere.
- Motores locales empaquetados/validados; overrides manuales desde archivo local para el subconjunto soportado.

No elude DRM, CAPTCHA, paywalls ni controles de acceso. El navegador Playwright no participa en el routing efectivo de 0.7.3.

## Analizador de chats 0.1.6

- Importación local de exportaciones compatibles de WhatsApp e Instagram.
- Parsing, deduplicación, filtros, búsqueda, métricas de actividad/participación/conversación y vistas analíticas.
- Manejo acotado de archivos comprimidos y almacenamiento temporal para datasets grandes.
- Historial agregado y ajustes centralizados.

No usa red ni conserva contenido privado completo en el historial global.

## Conversor universal 0.3.0

- Conversión local de imágenes, audio, vídeo, PDF, texto y datos en las rutas documentadas.
- FFmpeg/FFprobe para multimedia; APIs nativas cuando corresponda; Pandoc opcional para rutas compatibles cuando está preparado.
- Presets/favoritos, lotes, progreso/cancelación, validación y publicación segura.

Calibre, Ghostscript y LibreOffice no forman parte del producto actual. Ebook/EPS permanecen fuera del alcance aprobado salvo nueva decisión.

## Comparador de seguidores de Instagram 0.1.0

- Procesa exportaciones JSON seleccionadas por el usuario.
- Compara seguidores y seguidos localmente, tolera variantes previstas del formato y permite exportar resultados.
- Sin red, sesión de Instagram ni scraping.

## Inspector multimedia 0.7.2

- Inspección FFprobe de contenedores/streams, vídeo, audio, subtítulos, capítulos, metadata, attachments y carátulas.
- Preview local de audio y vídeo con transporte compartido, waveform, espectrograma y subtítulos cuando son viables.
- Sonoridad, señal, silencios/clipping, A/B, indicios explicables de fuente con pérdida y anomalías espectrales.
- OCR local/revisable de subtítulos bitmap mediante Vision cuando el flujo lo admite.
- Edición estructural segura de streams/metadata/capítulos/attachments/carátulas por stream copy, con Undo/Redo de borrador, planificación, FFmpeg, FFprobe y publicación segura.
- Lotes, carpetas/reglas, presets, favoritos e informes versionados.

No es un editor temporal/creativo y no recodifica audio/vídeo dentro del Inspector; una transformación que exige transcode pertenece al Conversor.

## Limpiador 0.1.2

- Inventario local de aplicaciones y asociaciones/residuos.
- Análisis de cachés/logs/tmp, restos, instaladores y contenido regenerable de desarrollo según reglas conservadoras.
- Desinstalación asistida con selección visible y protección de datos persistentes.
- Papelera por defecto, borrado permanente opt-in y Undo cuando los movimientos siguen verificables.
- Spotlight acotado/cancelable; una cobertura parcial no convierte aplicaciones históricas en “ausentes”.

No usa red, `sudo`, shell ni helper privilegiado. `scanLocalStorage` autoriza análisis en ubicaciones documentadas; retirar elementos exige `removeLocalItems`, selección y revalidación.

## Exclusiones transversales actuales

- Sin telemetría, analítica, anuncios o actualizaciones automáticas silenciosas.
- Sin App Sandbox en esta fase.
- Sin loader de módulos/plugins externos.
- Sin bypass de DRM, CAPTCHA, paywalls o privacidad.
- Sin Calibre, Ghostscript o LibreOffice.
- Sin modificación silenciosa de originales ni sobrescritura no confirmada.
