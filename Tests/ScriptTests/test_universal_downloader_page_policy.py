from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def _downloader_view_source() -> str:
    root = ROOT / "Sources/ZEUVEApp/UniversalDownloader"
    files = [root / "UniversalDownloaderView.swift"] + sorted((root / "Views").glob("*.swift"))
    return "\n".join(path.read_text() for path in files)


class UniversalDownloaderPagePolicyTests(unittest.TestCase):
    def test_page_only_ui_hides_conversion_controls_but_keeps_network_access(self):
        text = _downloader_view_source()
        self.assertIn("if !model.onlyPageDiscoveredSelection", text)
        self.assertIn("pageNetworkOptions", text)
        self.assertIn("networkAndAccessOptions", text)
        self.assertIn("Seleccionar cookies.txt", text)
        self.assertIn("Usar proxy solo en esta operación", text)

    def test_provenance_options_use_shared_contextual_help(self):
        view = _downloader_view_source()
        settings = (ROOT / "Sources/ZEUVEApp/SettingsView.swift").read_text() + "\n" + "\n".join(p.read_text() for p in (ROOT / "Sources/ZEUVEApp/UniversalDownloader/Settings").rglob("*.swift"))
        help_topics = (ROOT / "Sources/ZEUVEApp/UniversalDownloader/UniversalDownloaderHelp.swift").read_text()
        for name in ["pageOriginalDownload", "pageDiscoveredFilename", "pageSourceMetadata", "pageSourceDownloadDate", "macOSWhereFrom"]:
            self.assertIn(f"ZEUVEHelpTopics.{name}", view + settings)
            self.assertIn(f"static let {name}", help_topics)

    def test_page_download_command_explicitly_disables_transforming_options(self):
        command = (ROOT / "Sources/UniversalDownloaderModule/Engines/YTDLP/YTDLPCommandBuilder.swift").read_text()
        selector = (ROOT / "Sources/UniversalDownloaderModule/Engines/YTDLP/YTDLPFormatSelector.swift").read_text()
        self.assertIn("if item.isPageDiscovered", command)
        for option in ["--no-embed-metadata", "--no-embed-thumbnail", "--no-write-subs", "--no-write-info-json"]:
            self.assertIn(option, command)
        self.assertIn('selector: "bestvideo*+bestaudio/best"', selector)
        self.assertIn("willTranscode: false", selector)

    def test_page_filename_and_provenance_components_are_packaged(self):
        filename = (ROOT / "Sources/UniversalDownloaderModule/Files/DownloadFilenamePolicy.swift").read_text()
        metadata = (ROOT / "Sources/UniversalDownloaderModule/Publishing/DownloadOriginMetadata.swift").read_text()
        self.assertIn("pageDiscoveredBaseNames", filename)
        self.assertIn('return "\\(base) (\\(positions[base]!))"', filename)
        self.assertIn('"-c", "copy"', metadata)
        self.assertIn("com.apple.metadata:kMDItemWhereFroms", metadata)
        self.assertNotIn("zeuve-info.json", metadata)

    def test_page_download_reuses_resolved_media_and_keeps_secrets_ephemeral(self):
        models = "\n".join((ROOT / "Sources/UniversalDownloaderModule/Models").joinpath(name).read_text() for name in [
            "ResolvedMediaModels.swift", "DownloadSettings.swift", "DownloadResult.swift"
        ])
        parser = (ROOT / "Sources/UniversalDownloaderModule/Engines/YTDLP/YTDLPAnalysisParser.swift").read_text()
        command = (ROOT / "Sources/UniversalDownloaderModule/Engines/YTDLP/YTDLPCommandBuilder.swift").read_text()
        service = (ROOT / "Sources/UniversalDownloaderModule/Download/UniversalDownloadService.swift").read_text()
        self.assertIn("ResolvedMediaReference", models)
        self.assertIn("mediaURL = nil", models)
        self.assertNotIn("case mediaURL", models)
        self.assertNotIn("case httpHeaders", models)
        self.assertIn("resolvedMediaReference", parser)
        self.assertIn("resolvedMedia?.mediaURL ?? item.sourceURL", command)
        self.assertIn('"--add-header"', command)
        self.assertIn('secretOptions = ["--cookies", "--cookies-from-browser", "--proxy", "--add-header"]', command)
        self.assertIn("shouldResolveStableAnonymousYouTubeURL", service)
        self.assertIn("item.platform == .youtube", service)
        self.assertIn("adaptiveFragmentCeiling = 16", service)
        self.assertIn('target: "resuelto"', service)
        self.assertIn('target: "respaldo"', service)

    def test_page_download_uses_adaptive_fragments_and_atomic_same_volume_publication(self):
        policy = (ROOT / "Sources/UniversalDownloaderModule/Engines/YTDLP/YTDLPAdaptiveFragmentPolicy.swift").read_text()
        publisher = (ROOT / "Sources/UniversalDownloaderModule/Publishing/DownloadOutputPublisher.swift").read_text()
        view = _downloader_view_source()
        settings = (ROOT / "Sources/ZEUVEApp/SettingsView.swift").read_text() + "\n" + "\n".join(p.read_text() for p in (ROOT / "Sources/ZEUVEApp/UniversalDownloader/Settings").rglob("*.swift"))
        help_topics = (ROOT / "Sources/ZEUVEApp/UniversalDownloader/UniversalDownloaderHelp.swift").read_text()
        for level in ["16", "8", "4", "1"]:
            self.assertIn(level, policy)
        self.assertIn("sameVolume(source, destinationRoot)", publisher)
        self.assertIn("moveItem(at: source, to: staging)", publisher)
        self.assertIn("copyItem(at: source, to: staging)", publisher)
        self.assertIn("adaptivePageFragments", view + settings)
        self.assertIn("static let adaptivePageFragments", help_topics)

    def test_instagram_public_profiles_use_gallery_fallback_without_mandatory_session(self):
        service = (ROOT / "Sources/UniversalDownloaderModule/Analysis/UniversalDownloadAnalysisService.swift").read_text()
        helper = (ROOT / "Scripts/engine_helpers/instagram_catalog.py").read_text()
        view = "\n".join([
            _downloader_view_source(),
            (ROOT / "Sources/ZEUVEApp/UniversalDownloader/UniversalDownloaderCatalogView.swift").read_text(),
        ])
        self.assertIn("Perfil de Instagram resuelto mediante fallback", service)
        self.assertIn("analyzeWithGalleryDL(", service)
        self.assertIn("instagramPublicProfileUnavailableAnalysis", service)
        self.assertIn("markingAuthenticationRestrictedSections", service)
        self.assertIn('"requires_authentication": False', helper)
        self.assertIn("section_requires_authentication", helper)
        self.assertIn("Perfil público analizado sin sesión", view)
        self.assertIn("no disponibles sin sesión", view)

    def test_tiktok_empty_gallery_result_uses_real_fallback_and_visible_failure(self):
        service = (ROOT / "Sources/UniversalDownloaderModule/Download/UniversalDownloadService.swift").read_text()
        models = "\n".join((ROOT / "Sources/UniversalDownloaderModule/Models").joinpath(name).read_text() for name in [
            "ResolvedMediaModels.swift", "DownloadSettings.swift", "DownloadResult.swift"
        ])
        view = "\n".join([
            _downloader_view_source(),
            (ROOT / "Sources/ZEUVEApp/UniversalDownloader/UniversalDownloaderCompletionView.swift").read_text(),
        ])
        classifier = (ROOT / "Sources/UniversalDownloaderModule/Errors/DownloadErrorClassifier.swift").read_text()

        self.assertIn("galleryCandidates", service)
        policy = (ROOT / "Sources/UniversalDownloaderModule/Platforms/TikTok/TikTokDownloadFallbackPolicy.swift").read_text()
        self.assertIn("TikTokDownloadFallbackPolicy.shouldRetryWithYTDLP", service)
        self.assertIn("shouldRetryWithYTDLP", policy)
        self.assertIn('target: "tiktok_gallery_fallback"', service)
        self.assertIn("fallback.succeeded, !fallbackCandidates.isEmpty", service)
        self.assertIn("Resultado del respaldo TikTok con yt-dlp", service)
        self.assertIn("hasTotalFailure", models)
        self.assertIn('return "La descarga ha fallado"', view)
        self.assertIn('Button("Abrir registros")', view)
        self.assertIn("sin generar ningún archivo", classifier)



if __name__ == "__main__":
    unittest.main()
