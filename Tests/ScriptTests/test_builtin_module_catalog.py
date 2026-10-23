import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "Sources" / "ZEUVEApp"


class BuiltInModuleCatalogTests(unittest.TestCase):
    def test_catalog_is_single_source_for_builtin_integration(self) -> None:
        catalog = (APP / "BuiltInModules/BuiltInModuleCatalog.swift").read_text()
        self.assertEqual(catalog.count("BuiltInModuleDescriptor("), 7)
        for case_name in [
            ".organizer",
            ".universalDownloader",
            ".chatAnalyzer",
            ".universalConverter",
            ".instagramFollowers",
            ".multimediaInspector",
            ".cleaner",
        ]:
            self.assertIn(f"id: {case_name}", catalog)
        for identifier in [
            "organizerModuleIdentifier",
            "universalDownloaderModuleIdentifier",
            "legacyYouTubeDownloaderModuleIdentifier",
            "chatAnalyzerModuleIdentifier",
            "universalConverterModuleIdentifier",
            "instagramFollowersModuleIdentifier",
            "multimediaInspectorModuleIdentifier",
            "cleanerModuleIdentifier",
        ]:
            self.assertIn(identifier, catalog)

    def test_registration_sidebar_dashboard_and_commands_consume_catalog(self) -> None:
        app_model = (APP / "AppModel.swift").read_text()
        root = (APP / "RootView.swift").read_text()
        dashboard = (APP / "DashboardView.swift").read_text()
        app = (APP / "ZEUVEApp.swift").read_text()

        self.assertIn("for descriptor in BuiltInModuleCatalog.all", app_model)
        self.assertIn("ForEach(app.navigationModules)", root)
        self.assertIn("BuiltInModuleViewRouter(moduleID: moduleID)", root)
        self.assertIn("ForEach(app.dashboardModules)", dashboard)
        self.assertIn("app.selectModule(module.id)", dashboard)
        self.assertIn("ForEach(model.navigationModules)", app)
        self.assertIn("model.selectModule(module.id)", app)
        self.assertNotIn("switch moduleID", dashboard)
        for literal in [
            'navigationRow(.organizer)',
            'navigationRow(.universalDownloader)',
            'navigationRow(.chatAnalyzer)',
            'navigationRow(.universalConverter)',
            'navigationRow(.instagramFollowers)',
        ]:
            self.assertNotIn(literal, root)

    def test_module_view_models_are_injected_only_by_router(self) -> None:
        app = (APP / "ZEUVEApp.swift").read_text()
        router = (APP / "BuiltInModules/BuiltInModuleViewRouter.swift").read_text()
        for model_name in [
            "organizer",
            "universalDownloader",
            "chatAnalyzer",
            "universalConverter",
            "instagramFollowers",
            "multimediaInspector",
            "cleaner",
        ]:
            self.assertNotIn(f".environmentObject(model.{model_name})", app)
            self.assertIn(f".environmentObject(app.{model_name})", router)
        self.assertNotIn(".environmentObject(model.globalHistory)", app)
        self.assertIn(".environmentObject(app.globalHistory)", (APP / "RootView.swift").read_text())

    def test_settings_and_history_use_catalog_metadata(self) -> None:
        settings = (APP / "SettingsView.swift").read_text()
        settings_router = (APP / "BuiltInModules/BuiltInModuleSettingsRouter.swift").read_text()
        history = (APP / "History/GlobalHistoryView.swift").read_text()
        catalog = (APP / "BuiltInModules/BuiltInModuleCatalog.swift").read_text()

        self.assertIn("ForEach(app.settingsModules)", settings)
        self.assertIn("BuiltInModuleSettingsRouter(moduleID: moduleID)", settings)
        self.assertIn("case .instagramFollowers:", settings_router)
        self.assertIn("settingsOrder: nil", catalog)
        self.assertIn("presenters = BuiltInModuleCatalog.historyPresenters", history)
        self.assertIn("BuiltInModuleCatalog.historyManifests(from: manifests)", history)
        self.assertIn("BuiltInModuleCatalog.historyIdentifiers(forSelectedIdentifier: moduleID)", history)
        self.assertNotIn("moduleID == universalDownloaderModuleIdentifier", history)

    def test_default_shortcuts_and_navigation_order_include_cleaner(self) -> None:
        catalog = (APP / "BuiltInModules/BuiltInModuleCatalog.swift").read_text()
        expected = [
            (".organizer", "10", 'defaultShortcut: .command("1")'),
            (".universalDownloader", "20", 'defaultShortcut: .command("2")'),
            (".chatAnalyzer", "30", 'defaultShortcut: .command("3")'),
            (".universalConverter", "40", 'defaultShortcut: .command("4")'),
            (".instagramFollowers", "50", 'defaultShortcut: .command("5")'),
            (".multimediaInspector", "60", 'defaultShortcut: .command("6")'),
            (".cleaner", "70", 'defaultShortcut: .command("7")'),
        ]
        for case_name, order, shortcut in expected:
            start = catalog.index(f"id: {case_name}")
            end = catalog.find("BuiltInModuleDescriptor(", start + 1)
            block = catalog[start:] if end == -1 else catalog[start:end]
            self.assertIn(f"navigationOrder: {order}", block, msg=f"orden de {case_name}")
            self.assertIn(shortcut, block, msg=f"atajo de {case_name}")
        self.assertIn('(historyTargetID, .command("8"))', catalog)

    def test_commands_use_dynamic_shortcuts(self) -> None:
        app = (APP / "ZEUVEApp.swift").read_text()
        self.assertIn("model.shortcut(for: module.id)", app)
        self.assertIn("model.historyShortcut", app)
        self.assertNotIn('.keyboardShortcut("7", modifiers: [.command])', app)


if __name__ == "__main__":
    unittest.main()
