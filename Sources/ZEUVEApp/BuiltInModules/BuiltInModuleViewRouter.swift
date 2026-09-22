import SwiftUI

struct BuiltInModuleViewRouter: View {
    @EnvironmentObject private var app: AppModel
    let moduleID: BuiltInModuleID

    @ViewBuilder
    var body: some View {
        switch moduleID {
        case .organizer:
            OrganizerView()
                .environmentObject(app.organizer)
        case .universalDownloader:
            UniversalDownloaderView()
                .environmentObject(app.universalDownloader)
        case .chatAnalyzer:
            ChatAnalyzerView()
                .environmentObject(app.chatAnalyzer)
        case .universalConverter:
            UniversalConverterView()
                .environmentObject(app.universalConverter)
        case .instagramFollowers:
            InstagramFollowersView()
                .environmentObject(app.instagramFollowers)
        case .multimediaInspector:
            MultimediaInspectorView()
                .environmentObject(app.multimediaInspector)
        case .cleaner:
            CleanerView()
                .environmentObject(app.cleaner)
        }
    }
}
