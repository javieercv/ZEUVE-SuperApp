import Foundation

public struct UniversalDownloadPlanBuilder: Sendable {
    public init() {}

    public func build(
        items: [UniversalDownloadItem],
        operationSettings: UniversalDownloadSettings,
        profiles: UniversalDownloadProfiles,
        outputFolder: URL,
        cookiesFile: URL? = nil,
        cookieHeaderFile: URL? = nil,
        browserCookies: DownloadBrowserCookieSource? = nil,
        proxyHost: String? = nil
    ) -> UniversalDownloadPlan {
        let resolver = UniversalDownloadSettingsResolver()
        let resolved = Dictionary(uniqueKeysWithValues: items.map { item in
            (item.id, resolver.settings(for: item, operationSettings: operationSettings, profiles: profiles))
        })
        return UniversalDownloadPlan(
            items: items,
            settings: operationSettings,
            itemSettings: resolved,
            outputFolder: outputFolder,
            cookiesFile: cookiesFile,
            cookieHeaderFile: cookieHeaderFile,
            browserCookies: browserCookies,
            proxyHost: proxyHost
        )
    }
}
