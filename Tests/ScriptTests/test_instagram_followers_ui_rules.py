import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class InstagramFollowersUIRulesTests(unittest.TestCase):
    def read(self, relative: str) -> str:
        return (ROOT / relative).read_text(encoding="utf-8")

    def test_module_is_integrated_in_navigation_dashboard_history_and_commands(self) -> None:
        app = "\n".join(
            path.read_text(encoding="utf-8")
            for path in (ROOT / "Sources/ZEUVEApp").rglob("*.swift")
        )
        for required in (
            "case .instagramFollowers",
            "InstagramFollowersView()",
            "InstagramFollowersHistoryPresenter",
            "instagramFollowersModuleIdentifier",
            "Comparador de seguidores de Instagram",
        ):
            self.assertIn(required, app)

    def test_results_are_filtered_in_memory_and_external_open_is_manual(self) -> None:
        view_model = self.read("Sources/ZEUVEApp/InstagramFollowers/InstagramFollowersViewModel.swift")
        view = self.read("Sources/ZEUVEApp/InstagramFollowers/InstagramFollowersView.swift")
        self.assertIn("Task.sleep(for: .milliseconds(180))", view_model)
        self.assertIn("result.accounts(in: selectedCategory)", view_model)
        self.assertNotIn("Data(contentsOf:", view_model)
        self.assertNotIn("InstagramFollowersArchiveReader", view_model)
        self.assertIn("Button(\"Abrir en Instagram\")", view)
        self.assertIn("NSWorkspace.shared.open(account.profileURL)", view_model)

    def test_manifest_has_only_approved_permissions(self) -> None:
        manifest = json.loads(
            self.read("Sources/InstagramFollowersModule/Resources/manifest.json")
        )
        self.assertEqual(
            manifest["permissions"],
            [
                "readUserSelectedFiles",
                "writeUserSelectedFolder",
                "openExternalApplications",
            ],
        )
        self.assertNotIn("networkAccess", manifest["permissions"])
        self.assertNotIn("browserCookies", manifest["permissions"])

    def test_history_schema_contains_only_aggregate_fields(self) -> None:
        history = self.read("Sources/InstagramFollowersModule/History/InstagramFollowersHistory.swift")
        for required in (
            "inputType",
            "followerFileCount",
            "durationSeconds",
            "notFollowingBackCount",
            "followersNotFollowedCount",
            "mutualCount",
            "exported",
        ):
            self.assertIn(required, history)
        for forbidden in ("username", "profileURL", "searchText", "sourcePath"):
            self.assertNotIn(forbidden, history)

    def test_import_catalog_precedes_analysis(self) -> None:
        view = self.read("Sources/ZEUVEApp/InstagramFollowers/InstagramFollowersView.swift")
        model = self.read("Sources/ZEUVEApp/InstagramFollowers/InstagramFollowersViewModel.swift")
        self.assertIn("Archivos detectados", view)
        self.assertIn("Analizar exportación", view)
        self.assertIn("preparedInput != nil", model)
        self.assertNotIn("prepareArchive(url)\n        analyze()", model)


if __name__ == "__main__":
    unittest.main()
