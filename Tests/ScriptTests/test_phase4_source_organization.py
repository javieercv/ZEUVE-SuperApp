from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class Phase4SourceOrganizationTests(unittest.TestCase):
    def test_chat_results_are_split_by_section(self) -> None:
        root = ROOT / "Sources/ZEUVEApp/ChatAnalyzer"
        coordinator = root / "ChatAnalyzerResultsView.swift"
        result_files = {
            "ChatFilterPanel.swift",
            "ChatSummaryView.swift",
            "ChatActivityView.swift",
            "ChatParticipantsView.swift",
            "ChatWordsView.swift",
            "ChatSearchView.swift",
            "ChatConversationsView.swift",
            "ChatResponsesView.swift",
            "ChatComparisonView.swift",
            "ChatFusionsView.swift",
            "ChatResultsComponents.swift",
        }
        self.assertTrue(coordinator.is_file())
        self.assertLess(len(coordinator.read_text().splitlines()), 150)
        self.assertTrue(result_files.issubset({path.name for path in (root / "Results").glob("*.swift")}))

    def test_converter_models_are_split_without_reintroducing_monolith(self) -> None:
        root = ROOT / "Sources/UniversalConverterModule/Models"
        self.assertFalse((root / "UniversalConverterModels.swift").exists())
        required = {
            "ConverterFormats.swift": "public enum ConverterFormat",
            "ConverterOperations.swift": "public enum ConversionOperation",
            "UniversalConverterSettings.swift": "public struct UniversalConverterSettings",
            "ConverterOperationOptions.swift": "public struct ConverterOperationOptions",
            "UniversalConverterPreset.swift": "public struct UniversalConverterPreset",
            "ConverterInputModels.swift": "public struct ConverterInputItem",
            "ConversionPlanModels.swift": "public struct ConversionPlan",
            "ConverterResultModels.swift": "public struct UniversalConverterResult",
            "ConverterProgressModels.swift": "public struct ConverterProgressSnapshot",
        }
        for filename, declaration in required.items():
            path = root / filename
            self.assertTrue(path.is_file(), filename)
            self.assertIn(declaration, path.read_text())

    def test_chat_analytics_are_split_by_domain_and_keep_namespace_small(self) -> None:
        root = ROOT / "Sources/ChatAnalyzerModule/Analysis"
        namespace = root / "ChatAnalytics.swift"
        self.assertLess(len(namespace.read_text().splitlines()), 40)
        for filename in [
            "ChatAnalyticsModels.swift",
            "ChatCoreAnalytics.swift",
            "ChatActivityAnalytics.swift",
            "ChatParticipantAnalytics.swift",
            "ChatWordAnalytics.swift",
            "ChatConversationAnalytics.swift",
            "ChatSearchAnalytics.swift",
            "ChatAnalyticsSnapshots.swift",
            "ChatAnalyticsSupport.swift",
            "ChatTokenizer.swift",
        ]:
            self.assertTrue((root / filename).is_file(), filename)

    def test_converter_ffmpeg_support_is_separate_from_execution_coordinator(self) -> None:
        root = ROOT / "Sources/UniversalConverterModule/Execution"
        service = (root / "UniversalConverterExecutionService.swift").read_text()
        support = (root / "FFmpegProgressSupport.swift").read_text()
        self.assertNotIn("final class FFmpegDiagnosticCollector", service)
        self.assertNotIn("final class FFmpegProgressMonitor", service)
        self.assertIn("final class FFmpegDiagnosticCollector", support)
        self.assertIn("final class FFmpegProgressMonitor", support)

    def test_downloader_settings_card_is_extracted_without_new_feature_surface(self) -> None:
        root = ROOT / "Sources/ZEUVEApp/UniversalDownloader"
        main = (root / "UniversalDownloaderView.swift").read_text()
        card = (root / "Views/UniversalDownloaderSettingsCard.swift").read_text()
        self.assertIn("UniversalDownloaderSettingsCard(model: model)", main)
        self.assertNotIn("private var settingsCard", main)
        self.assertIn('GroupBox("Configuración")', card)
        self.assertIn("networkAndAccessOptions", card)
        self.assertIn("quickPresetSelection", card)


if __name__ == "__main__":
    unittest.main()
