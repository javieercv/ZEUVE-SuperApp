import SwiftUI

struct BuiltInModuleSettingsRouter: View {
    @EnvironmentObject private var app: AppModel
    let moduleID: BuiltInModuleID

    @ViewBuilder
    var body: some View {
        switch moduleID {
        case .organizer:
            OrganizerModuleSettingsView(model: app.organizer)
        case .universalDownloader:
            UniversalDownloaderSettingsView(model: app.universalDownloader)
        case .chatAnalyzer:
            ChatAnalyzerModuleSettingsView(model: app.chatAnalyzer)
        case .universalConverter:
            UniversalConverterSettingsView(model: app.universalConverter)
        case .instagramFollowers:
            EmptyView()
        case .multimediaInspector:
            MultimediaInspectorSettingsView(model: app.multimediaInspector)
        case .cleaner:
            CleanerSettingsView(model: app.cleaner)
        }
    }
}
