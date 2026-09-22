# Entrega — ZEUVE 0.5.2

Fecha: 3 de julio de 2026.

## Resumen

ZEUVE 0.5.2 corrige el regreso inmediato a la pantalla inicial del Analizador de chats y añade ayuda contextual completa en sus nueve pestañas de resultados.

## Estado

Completado en el proyecto fuente.

- Versión anterior: 0.5.1, build 14.
- Versión nueva: 0.5.2, build 15.
- Analizador de chats: 0.1.1 → 0.1.2.

## Cambios funcionales

### Navegación del Analizador

- `Analizar otro chat` cierra la sesión temporal, elimina sus datos, limpia las fuentes y abre inmediatamente la pantalla inicial vacía.
- `Cerrar análisis` cierra la sesión temporal, elimina sus datos, conserva las fuentes y abre inmediatamente la pantalla inicial.
- La transición observa directamente `ChatAnalyzerViewModel`, por lo que ya no depende de cambiar de módulo para refrescarse.

### Ayuda contextual en resultados

Se añadió una explicación general en:

- Resumen.
- Actividad.
- Participantes.
- Palabras y emojis.
- Búsqueda.
- Conversaciones.
- Tiempos de respuesta.
- Comparación.
- Fusiones.

También se añadieron explicaciones específicas en métricas, gráficos, opciones, resúmenes, agrupaciones y columnas no evidentes. La ayuda indica qué mide cada dato, cómo se calcula, qué incluye, qué excluye, cómo le afectan los filtros y qué limitaciones tiene.

### Reglas y decisiones

`SUPERAPP_PROJECT_RULES.md` incorpora ocho reglas nuevas sobre:

- coherencia entre modos y tipos de entrada;
- regreso al estado inicial del módulo;
- selección automática cuando solo existe una opción;
- archivos grandes y límites configurables;
- distinción entre faltante y no comprobable;
- uso temporal de archivos reales;
- ayuda contextual en resultados analíticos;
- inspección eficiente de archivos comprimidos.

`PROJECT_DECISIONS.md` registra el comportamiento de ambos botones y la ayuda contextual de las nueve pestañas.

## Archivos principales modificados

- `Sources/ZEUVEApp/ChatAnalyzer/ChatAnalyzerView.swift`
- `Sources/ZEUVEApp/ChatAnalyzer/ChatAnalyzerResultsView.swift`
- `Sources/ZEUVEApp/Components/ContextualHelp.swift`
- `Tests/ScriptTests/test_chat_analyzer_ui_rules.py`
- `SUPERAPP_PROJECT_RULES.md`
- `PROJECT_DECISIONS.md`
- `Sources/ChatAnalyzerModule/Resources/manifest.json`
- `Sources/ZEUVEApp/SettingsView.swift`
- `Scripts/generate_xcode_project.py`
- `Scripts/verify_project.sh`
- `ZEUVE.xcodeproj/project.pbxproj`
- `VERSION`
- `CHANGELOG.md`
- documentación vigente de arquitectura, compilación, seguridad, pruebas, alcance y Analizador.

## Dependencias y privacidad

- Sin dependencias nuevas.
- Sin Internet ni APIs nuevas.
- Sin cambios en Organizador o Descargador.
- Sin modificación de archivos originales del usuario.
- Sin chats reales dentro del proyecto o la entrega.

## Pruebas

- 97 pruebas Swift superadas.
- 15 pruebas Python superadas.
- Análisis sintáctico de todas las vistas SwiftUI/AppKit superado.
- Compilación SwiftPM Release incluida en la validación final.
- Proyecto Xcode regenerado para versión 0.5.2, build 15.

Los detalles completos se encuentran en `Docs/TEST_RESULTS_0.5.2.md`.

## Limitaciones

No se ha compilado ni abierto la aplicación completa con Xcode porque el entorno disponible no es macOS Apple Silicon. La navegación y los popovers deben verificarse visualmente en un Mac, junto con VoiceOver y los modos claro y oscuro.
