from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class GlobalSettingsResetPolicyTests(unittest.TestCase):
    def test_general_settings_exposes_confirmed_global_reset(self):
        text = (ROOT / "Sources/ZEUVEApp/SettingsView.swift").read_text()
        self.assertIn('Button("Restaurar todos los ajustes predeterminados", role: .destructive)', text)
        self.assertIn('"¿Restaurar todos los ajustes de ZEUVE?"', text)
        self.assertIn('.disabled(!app.canRestoreAllSettings)', text)
        for preserved in [
            "historial",
            "preajustes",
            "favoritas",
            "perfiles personalizados",
            "carpetas recientes",
            "motores",
        ]:
            self.assertIn(preserved, text)

    def test_app_model_coordinates_every_persistent_settings_area_without_history_deletion(self):
        text = (ROOT / "Sources/ZEUVEApp/AppModel.swift").read_text()
        self.assertIn("func restoreAllSettingsToDefaults()", text)
        keys = (ROOT / "Sources/ZEUVEApp/AppStorageKeys.swift").read_text()
        self.assertIn('static let theme = "appearance.theme"', keys)
        self.assertIn('storage.settings.set(ThemePreference.system, forKey: ZEUVEAppStorageKeys.theme)', text)
        self.assertIn("organizer.restoreDefaultOptions()", text)
        self.assertIn("universalDownloader.restorePersistentDefaultsForGlobalReset()", text)
        self.assertIn("chatAnalyzer.restoreSettings()", text)
        self.assertIn("universalConverter.restorePersistentDefaultsForGlobalReset()", text)
        self.assertNotIn("operation_history", text)
        self.assertNotIn("globalHistory.clear", text)

    def test_downloader_reset_keeps_user_content_and_forgets_sensitive_remembered_state(self):
        text = (ROOT / "Sources/ZEUVEApp/UniversalDownloader/UniversalDownloaderViewModel.swift").read_text()
        start = text.index("func restorePersistentDefaultsForGlobalReset()")
        end = text.index("func applyDefaultSettingsToCurrentOperation()", start)
        method = text[start:end]
        self.assertIn("restoreAllFactorySettings(keepingCustomProfiles: true)", method)
        self.assertIn("instagramKeychain.delete()", method)
        self.assertIn('instagramSessionText = ""', method)
        self.assertIn("bookmarkStore?.clear()", method)
        self.assertNotIn("restoreDefaultPresets", method)
        self.assertNotIn("presets =", method)

    def test_converter_reset_does_not_touch_presets_or_favorites(self):
        text = (ROOT / "Sources/ZEUVEApp/UniversalConverter/UniversalConverterViewModel.swift").read_text()
        start = text.index("func restorePersistentDefaultsForGlobalReset()")
        end = text.index("func refreshEngineSummary", start)
        method = text[start:end]
        self.assertIn("restoreDefaults()", method)
        self.assertIn("bookmarkStore?.clear()", method)
        self.assertNotIn("restoreDefaultPresets", method)
        self.assertNotIn("favorites", method)


if __name__ == "__main__":
    unittest.main()
