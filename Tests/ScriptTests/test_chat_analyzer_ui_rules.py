import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class ChatAnalyzerUIRulesTests(unittest.TestCase):
    def test_results_and_import_switch_observes_chat_model_directly(self) -> None:
        source = (ROOT / "Sources/ZEUVEApp/ChatAnalyzer/ChatAnalyzerView.swift").read_text()
        self.assertIn("private struct ChatAnalyzerObservedContent: View", source)
        self.assertIn("@ObservedObject var model: ChatAnalyzerViewModel", source)
        self.assertIn("if model.session == nil", source)
        self.assertNotIn("if app.chatAnalyzer.session == nil", source)

    def test_close_and_analyze_another_keep_distinct_source_behavior(self) -> None:
        source = (ROOT / "Sources/ZEUVEApp/ChatAnalyzer/ChatAnalyzerViewModel.swift").read_text()
        self.assertIn("func closeAnalysis()", source)
        self.assertIn("func analyzeAnother() { closeAnalysis(); clearInputs() }", source)
        close_block = source.split("func closeAnalysis()", 1)[1].split("func analyzeAnother()", 1)[0]
        self.assertNotIn("clearInputs()", close_block)

    def test_all_result_tabs_have_general_contextual_help(self) -> None:
        source = (ROOT / "Sources/ZEUVEApp/ChatAnalyzer/ChatAnalyzerResultsView.swift").read_text()
        topics = [
            "chatSummaryOverview",
            "chatActivityOverview",
            "chatParticipantOverview",
            "chatWordsOverview",
            "chatSearchOverview",
            "chatConversationsOverview",
            "chatResponsesOverview",
            "chatComparisonOverview",
            "chatFusionsOverview",
        ]
        for topic in topics:
            self.assertIn(f"topic: ZEUVEHelpTopics.{topic}", source)
        self.assertGreaterEqual(source.count("HelpTableHeader("), 15)
        self.assertGreaterEqual(source.count("MetricCard("), 20)

    def test_new_permanent_rules_are_present(self) -> None:
        rules = (ROOT / "SUPERAPP_PROJECT_RULES.md").read_text()
        headings = [
            "56. COHERENCIA AL CAMBIAR MODOS, PLATAFORMAS O TIPOS DE ENTRADA",
            "57. REGRESO AL ESTADO INICIAL DEL MÓDULO",
            "58. SELECCIÓN AUTOMÁTICA CUANDO SOLO EXISTE UNA OPCIÓN",
            "59. ARCHIVOS GRANDES Y LÍMITES CONFIGURABLES",
            "60. DIFERENCIAR AUSENTE, NO PROPORCIONADO Y NO COMPROBABLE",
            "61. USO TEMPORAL DE ARCHIVOS REALES PARA REPRODUCIR ERRORES",
            "62. AYUDA CONTEXTUAL EN RESULTADOS ANALÍTICOS",
            "63. INSPECCIÓN EFICIENTE DE ARCHIVOS COMPRIMIDOS",
            "64. INTERFAZ RESPONSIVA Y CÁLCULOS FUERA DEL HILO PRINCIPAL",
            "65. CACHÉ E INVALIDACIÓN SELECTIVA",
            "66. CÁLCULO BAJO DEMANDA",
            "67. CANCELACIÓN Y DESCARTE DE RESULTADOS OBSOLETOS",
            "68. ESPERA BREVE EN CAMBIOS REPETITIVOS",
            "69. SEPARACIÓN DEL ESTADO VISUAL Y DEL ESTADO ANALÍTICO",
            "70. OBSERVACIÓN DIRECTA DE LA FUENTE REAL DEL ESTADO",
            "71. ESTÁNDAR COMÚN PARA GRÁFICOS INTERACTIVOS",
            "72. VISIBILIDAD Y POSICIONAMIENTO DE TOOLTIPS",
            "73. INTERACCIÓN GRÁFICA LIGERA",
            "74. COHERENCIA ENTRE GRÁFICOS",
            "75. REGRESIONES DE RENDIMIENTO",
            "76. PRUEBAS CON VOLÚMENES REPRESENTATIVOS",
            "77. VALIDACIÓN EN EL ENTORNO OBJETIVO",
            "78. REGLA FINAL",
        ]
        for heading in headings:
            self.assertIn(heading, rules)

    def test_chat_results_use_background_snapshots_instead_of_recalculating_in_views(self) -> None:
        model = (ROOT / "Sources/ZEUVEApp/ChatAnalyzer/ChatAnalyzerViewModel.swift").read_text()
        results = (ROOT / "Sources/ZEUVEApp/ChatAnalyzer/ChatAnalyzerResultsView.swift").read_text()
        analytics = (ROOT / "Sources/ChatAnalyzerModule/Analysis/ChatAnalyticsCache.swift").read_text()

        self.assertIn("@Published private(set) var coreSnapshot", model)
        self.assertIn("detachedAnalyticsValue", model)
        self.assertIn("Task.sleep(nanoseconds: 200_000_000)", model)
        self.assertIn("worker.cancel()", model)
        self.assertIn("ChatSearchIndex", analytics)
        self.assertIn("model.activitySnapshot", results)
        self.assertIn("model.wordsSnapshot", results)
        self.assertIn("model.comparisonSnapshot", results)
        self.assertNotIn("ChatAnalytics.words(model.filteredMessages", results)
        self.assertNotIn("ChatAnalytics.timeSeries(model.filteredMessages", results)
        self.assertNotIn("var filteredMessages: [NormalizedMessage] { ChatAnalytics.filtered", model)

    def test_background_refresh_cancels_stale_work_and_avoids_unrelated_core_rebuilds(self) -> None:
        model = (ROOT / "Sources/ZEUVEApp/ChatAnalyzer/ChatAnalyzerViewModel.swift").read_text()
        analytics = (ROOT / "Sources/ChatAnalyzerModule/Analysis/ChatAnalytics.swift").read_text()
        parsing = (ROOT / "Sources/ChatAnalyzerModule/Import/ChatParsingUtilities.swift").read_text()

        self.assertIn("handleOperationSettingsChange(from: oldValue, to: operationSettings)", model)
        self.assertIn("if selectedSection != .search", model)
        self.assertIn("searchTask?.cancel()", model)
        self.assertIn("guard filter.activeCount > 0 else { return messages }", analytics)
        self.assertIn("guard needsWeekday || needsHour else { return true }", analytics)
        self.assertIn("return urlRegex.value.firstMatch", parsing)
        self.assertIn("var overallWords: [String: Int]", analytics)
        self.assertIn("var heatmapValues = Array(repeating: 0, count: 7 * 24)", analytics)

    def test_chat_results_show_discreet_background_progress(self) -> None:
        source = (ROOT / "Sources/ZEUVEApp/ChatAnalyzer/ChatAnalyzerResultsView.swift").read_text()
        self.assertIn("Actualizando estadísticas…", source)
        self.assertIn("Buscando…", source)
        self.assertIn("model.isUpdatingStatistics", source)
        self.assertIn("model.isSearching", source)

    def test_all_chat_charts_have_lightweight_hover_tooltips(self) -> None:
        results = (ROOT / "Sources/ZEUVEApp/ChatAnalyzer/ChatAnalyzerResultsView.swift").read_text()
        support = (ROOT / "Sources/ZEUVEApp/Components/InteractiveChartSupport.swift").read_text()

        self.assertIn("struct ChartTooltipCard: View", support)
        self.assertIn("CursorFollowingTooltip", support)
        self.assertIn("tooltipCenter(in:", support)
        self.assertIn("chartOverlay", support)
        self.assertIn("onContinuousHover", support)
        self.assertIn("proxy.plotFrame", support)
        self.assertIn("cursorLocation", support)
        self.assertIn("chartCursorTooltip", support)
        self.assertIn("location.x - horizontalGap - halfWidth", support)
        self.assertIn("location.y + verticalGap + halfHeight", support)
        self.assertIn("containerSize.width - margin", support)
        self.assertIn("containerSize.height - margin", support)
        self.assertGreaterEqual(results.count("trackChartDateHover("), 3)
        self.assertGreaterEqual(results.count("trackChartCategoryHover("), 5)
        self.assertGreaterEqual(results.count("chartCursorTooltip(at:"), 9)
        self.assertIn("HeatmapHoverValue", results)
        self.assertIn("hoveredCellLocation", results)
        self.assertIn('ChartTooltipRow("Total"', results)
        self.assertIn("activityTooltipRows", results)
        self.assertIn("comparisonTemporalRows", results)
        self.assertNotIn(".annotation(position: .top", results)
        self.assertNotIn("ChatAnalytics.timeSeries", support)
        self.assertNotIn("ChatAnalytics.participants", support)



if __name__ == "__main__":
    unittest.main()
