#!/usr/bin/env python3
from __future__ import annotations

import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
os.chdir(ROOT)

# Integración, privacidad y seguridad del Analizador de chats.
from pathlib import Path
required_files = [
    'Sources/ChatAnalyzerModule/ChatAnalyzerService.swift',
    'Sources/ChatAnalyzerModule/Archive/ChatArchive.swift',
    'Sources/ChatAnalyzerModule/Import/WhatsAppImporter.swift',
    'Sources/ChatAnalyzerModule/Import/InstagramImporter.swift',
    'Sources/ChatAnalyzerModule/Storage/ChatAnalyzerStorage.swift',
    'Sources/ChatAnalyzerModule/Analysis/ChatAnalyticsCache.swift',
    'Sources/ZEUVEApp/ChatAnalyzer/ChatAnalyzerView.swift',
    'Sources/ZEUVEApp/ChatAnalyzer/ChatAnalyzerResultsView.swift',
]
for name in required_files:
    if not Path(name).is_file():
        raise SystemExit('Falta un componente del Analizador: ' + name)
app = '\n'.join(path.read_text() for path in Path('Sources/ZEUVEApp').rglob('*.swift'))
for required in ['chatAnalyzerModuleIdentifier', 'ChatAnalyzerView', 'ChatAnalyzerModuleSettingsView', 'ChatAnalyzerHistoryPresenter']:
    if required not in app:
        raise SystemExit('Falta integración del Analizador en la aplicación: ' + required)
module = '\n'.join(path.read_text(errors='ignore') for path in Path('Sources/ChatAnalyzerModule').rglob('*') if path.is_file())
for forbidden in ['URLSession', 'WKWebView', 'NSWorkspace.shared.open', 'http://localhost', 'https://api.']:
    if forbidden in module:
        raise SystemExit('El Analizador contiene una vía de red o apertura externa: ' + forbidden)
for required in ['SafeArchivePath', 'readUserSelectedFiles', '.zeuve-chat-operation', 'MessageDeduplicator']:
    if required not in module:
        raise SystemExit('Falta una protección obligatoria del Analizador: ' + required)

archive = Path('Sources/ChatAnalyzerModule/Archive/ChatArchive.swift').read_text()
whatsapp = Path('Sources/ChatAnalyzerModule/Import/WhatsAppImporter.swift').read_text()
instagram = Path('Sources/ChatAnalyzerModule/Import/InstagramImporter.swift').read_text()
models = Path('Sources/ChatAnalyzerModule/ChatAnalyzerModels.swift').read_text()
view = Path('Sources/ZEUVEApp/ChatAnalyzer/ChatAnalyzerView.swift').read_text()
view_model = Path('Sources/ZEUVEApp/ChatAnalyzer/ChatAnalyzerViewModel.swift').read_text()
settings = Path('Sources/ZEUVEApp/SettingsView.swift').read_text()
chat_results_root = Path('Sources/ZEUVEApp/ChatAnalyzer')
results = Path(chat_results_root / 'ChatAnalyzerResultsView.swift').read_text() + '\n' + '\n'.join(path.read_text() for path in sorted((chat_results_root / 'Results').glob('*.swift')))
for required in ['readPrefixes(', 'public func stream(']:
    if required not in archive:
        raise SystemExit('Falta lectura ZIP progresiva del Analizador: ' + required)
for required in ['checkCancellation(', 'entrada duplicada', 'throw ChatAnalyzerError.archiveUnsafe']:
    if required not in archive:
        raise SystemExit('Falta seguridad/cancelación ZIP 0.12.4: ' + required)
for required in ['reader.readPrefixes', 'reader.stream', 'conversationFileMaximumBytes', 'unverifiedAttachments']:
    if required not in whatsapp + models:
        raise SystemExit('Falta corrección de WhatsApp: ' + required)
for required in ['usesDirectConversationLayout', 'resolveAttachmentPath(']:
    if required not in instagram:
        raise SystemExit('Falta compatibilidad con ZIP individual de Instagram: ' + required)
for required in ['dropTitle', 'dropSubtitle', 'allowedContentTypes', 'Arrastra el ZIP de Instagram']:
    if required not in view:
        raise SystemExit('El cuadro de importación no depende de la plataforma: ' + required)
if view_model.count('instagramSelections[url] =') < 2:
    raise SystemExit('No se selecciona automáticamente el único chat de Instagram en ZIP y carpeta.')
for required in ['Limitar el tamaño de cada archivo de conversación', 'Por defecto no hay límite']:
    if required not in settings:
        raise SystemExit('Falta el límite opcional centralizado: ' + required)
if 'Adjuntos no comprobados' not in results:
    raise SystemExit('El resumen no diferencia adjuntos no comprobados.')

analytics = '\n'.join(path.read_text() for path in sorted(Path('Sources/ChatAnalyzerModule/Analysis').glob('*.swift')))
analytics_cache = Path('Sources/ChatAnalyzerModule/Analysis/ChatAnalyticsCache.swift').read_text()
for required in [
    '@Published private(set) var coreSnapshot', 'detachedStoreAnalyticsValue',
    'Task.sleep(nanoseconds: 200_000_000)', 'handleOperationSettingsChange',
    'searchTask?.cancel()', 'analyticsRevision',
    'ChatStoreAnalytics.coreSnapshot', 'ChatStoreAnalytics.searchResult',
]:
    if required not in view_model:
        raise SystemExit('Falta arquitectura de rendimiento del Analizador: ' + required)
for required in [
    'ChatStoreCoreAnalyticsSnapshot', 'ChatActivityAnalyticsSnapshot',
    'ChatWordsAnalyticsSnapshot', 'ChatConversationAnalyticsSnapshot',
]:
    if required not in analytics_cache:
        raise SystemExit('Falta una instantánea analítica compacta: ' + required)
store_analytics = Path('Sources/ChatAnalyzerModule/Analysis/ChatStoreAnalytics.swift').read_text()
storage_source = Path('Sources/ChatAnalyzerModule/Storage/ChatAnalyzerStorage.swift').read_text()
for required in ['forEachBatch(', 'forEachIndexedBatch(', 'FrequencyScratch', 'ConversationScratch', 'public static func searchResult(']:
    if required not in store_analytics + storage_source:
        raise SystemExit('Falta analítica por lotes respaldada por SQLite: ' + required)
for forbidden in ['coreSnapshot.messages', 'coreSnapshot.filteredMessages', 'result.messages', 'searchTextCache', 'store.allMessages(']:
    if forbidden in view_model:
        raise SystemExit('El ViewModel vuelve a conservar/materializar el chat completo: ' + forbidden)
for required in [
    'guard filter.activeCount > 0 else { return messages }',
    'guard needsWeekday || needsHour else { return true }',
    'var overallWords: [String: Int]',
    'var heatmapValues = Array(repeating: 0, count: 7 * 24)',
]:
    if required not in analytics:
        raise SystemExit('Falta una optimización analítica: ' + required)
for forbidden in [
    'ChatAnalytics.words(model.filteredMessages',
    'ChatAnalytics.timeSeries(model.filteredMessages',
]:
    if forbidden in results:
        raise SystemExit('La interfaz vuelve a recalcular estadísticas pesadas: ' + forbidden)

chart_support = Path('Sources/ZEUVEApp/Components/InteractiveChartSupport.swift').read_text()
for required in [
    'struct ChartTooltipCard: View', 'CursorFollowingTooltip',
    'tooltipCenter(in:', 'chartOverlay', 'onContinuousHover',
    'proxy.plotFrame', 'nearestDate(to:', 'trackChartDateHover',
    'trackChartCategoryHover', 'cursorLocation', 'chartCursorTooltip',
    'location.x - horizontalGap - halfWidth',
    'location.y + verticalGap + halfHeight',
    'containerSize.width - margin', 'containerSize.height - margin',
]:
    if required not in chart_support:
        raise SystemExit('Falta interacción común de gráficos: ' + required)
for required in [
    'activityTooltipRows', 'comparisonTemporalRows', 'HeatmapHoverValue',
    'hoveredCellLocation', 'ChartTooltipRow("Total"',
]:
    if required not in results:
        raise SystemExit('Falta tooltip en un gráfico del Analizador: ' + required)
if results.count('trackChartDateHover(') < 3 or results.count('trackChartCategoryHover(') < 5:
    raise SystemExit('No todos los gráficos Swift Charts tienen hover interactivo.')
if results.count('chartCursorTooltip(at:') < 9:
    raise SystemExit('No todos los gráficos colocan el tooltip junto al cursor.')
if '.annotation(position: .top' in results:
    raise SystemExit('Queda algún tooltip fijado al borde superior del gráfico.')
for forbidden in ['ChatAnalytics.timeSeries', 'ChatAnalytics.participants', 'ChatAnalytics.words']:
    if forbidden in chart_support:
        raise SystemExit('La capa de hover ejecuta análisis pesado: ' + forbidden)

if 'private struct ChatAnalyzerObservedContent: View' not in view or 'if model.session == nil' not in view:
    raise SystemExit('La vista del Analizador no observa directamente el cambio entre resultados e importación.')
if 'if app.chatAnalyzer.session == nil' in view:
    raise SystemExit('La navegación del Analizador sigue dependiendo únicamente de AppModel.')
for required in [
    'chatSummaryOverview', 'chatActivityOverview', 'chatParticipantOverview',
    'chatWordsOverview', 'chatSearchOverview', 'chatConversationsOverview',
    'chatResponsesOverview', 'chatComparisonOverview', 'chatFusionsOverview',
    'HelpTableHeader(', 'HelpGroupBox(', 'topic: ContextualHelpTopic?',
]:
    if required not in results:
        raise SystemExit('Falta ayuda contextual analítica en resultados: ' + required)
rules = Path('SUPERAPP_PROJECT_RULES.md').read_text()
for required in [
    '56. COHERENCIA AL CAMBIAR MODOS, PLATAFORMAS O TIPOS DE ENTRADA',
    '57. REGRESO AL ESTADO INICIAL DEL MÓDULO',
    '58. SELECCIÓN AUTOMÁTICA CUANDO SOLO EXISTE UNA OPCIÓN',
    '59. ARCHIVOS GRANDES Y LÍMITES CONFIGURABLES',
    '60. DIFERENCIAR AUSENTE, NO PROPORCIONADO Y NO COMPROBABLE',
    '61. USO TEMPORAL DE ARCHIVOS REALES PARA REPRODUCIR ERRORES',
    '62. AYUDA CONTEXTUAL EN RESULTADOS ANALÍTICOS',
    '63. INSPECCIÓN EFICIENTE DE ARCHIVOS COMPRIMIDOS',
    '78. SELECCIÓN ESPECIALIZADA DE MOTORES',
    '80. REGLA FINAL',
]:
    if required not in rules:
        raise SystemExit('Falta una regla permanente aprobada: ' + required)
