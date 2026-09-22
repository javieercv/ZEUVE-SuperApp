import Foundation
import ZEUVECore
import OrganizerModule
import UniversalDownloaderModule
import ChatAnalyzerModule
import UniversalConverterModule
import InstagramFollowersModule
import MultimediaInspectorModule
import CleanerModule

enum BuiltInModuleID: String, CaseIterable, Identifiable, Hashable, Sendable {
    case organizer
    case universalDownloader
    case chatAnalyzer
    case universalConverter
    case instagramFollowers
    case multimediaInspector
    case cleaner

    var id: String { rawValue }
}

struct BuiltInModuleDescriptor: Identifiable, Sendable {
    let id: BuiltInModuleID
    let primaryIdentifier: String
    let legacyIdentifiers: [String]
    let registrationName: String
    let navigationOrder: Int
    let settingsOrder: Int?
    let settingsTitle: String?
    let commandTitle: String
    let defaultShortcut: KeyboardShortcutDescriptor?
    let loadManifest: @Sendable () throws -> ModuleManifest
    let makeHistoryPresenters: @Sendable () -> [any ModuleHistoryPresenter]

    var historyIdentifiers: [String] {
        [primaryIdentifier] + legacyIdentifiers
    }
}

struct RegisteredBuiltInModule: Identifiable, Sendable {
    let descriptor: BuiltInModuleDescriptor
    let manifest: ModuleManifest

    var id: BuiltInModuleID { descriptor.id }
}

enum BuiltInModuleCatalog {
    static let all: [BuiltInModuleDescriptor] = [
        BuiltInModuleDescriptor(
            id: .organizer,
            primaryIdentifier: organizerModuleIdentifier,
            legacyIdentifiers: [],
            registrationName: "Organizador",
            navigationOrder: 10,
            settingsOrder: 10,
            settingsTitle: "Organizador de archivos",
            commandTitle: "Abrir organizador",
            defaultShortcut: .command("1"),
            loadManifest: OrganizerModuleDefinition.manifest,
            makeHistoryPresenters: { [OrganizerGlobalHistoryPresenter()] }
        ),
        BuiltInModuleDescriptor(
            id: .universalDownloader,
            primaryIdentifier: universalDownloaderModuleIdentifier,
            legacyIdentifiers: [legacyYouTubeDownloaderModuleIdentifier],
            registrationName: "Descargador universal",
            navigationOrder: 20,
            settingsOrder: 20,
            settingsTitle: "Descargador universal",
            commandTitle: "Abrir Descargador universal",
            defaultShortcut: .command("2"),
            loadManifest: UniversalDownloaderModuleDefinition.manifest,
            makeHistoryPresenters: {
                [
                    UniversalDownloadHistoryPresenter(),
                    UniversalDownloadHistoryPresenter(moduleID: legacyYouTubeDownloaderModuleIdentifier),
                ]
            }
        ),
        BuiltInModuleDescriptor(
            id: .chatAnalyzer,
            primaryIdentifier: chatAnalyzerModuleIdentifier,
            legacyIdentifiers: [],
            registrationName: "Analizador de chats",
            navigationOrder: 30,
            settingsOrder: 30,
            settingsTitle: "Analizador de chats",
            commandTitle: "Abrir Analizador de chats",
            defaultShortcut: .command("3"),
            loadManifest: ChatAnalyzerModuleDefinition.manifest,
            makeHistoryPresenters: { [ChatAnalyzerHistoryPresenter()] }
        ),
        BuiltInModuleDescriptor(
            id: .universalConverter,
            primaryIdentifier: universalConverterModuleIdentifier,
            legacyIdentifiers: [],
            registrationName: "Conversor universal",
            navigationOrder: 40,
            settingsOrder: 40,
            settingsTitle: "Conversor universal",
            commandTitle: "Abrir Conversor universal",
            defaultShortcut: .command("4"),
            loadManifest: UniversalConverterModuleDefinition.manifest,
            makeHistoryPresenters: { [UniversalConverterHistoryPresenter()] }
        ),
        BuiltInModuleDescriptor(
            id: .instagramFollowers,
            primaryIdentifier: instagramFollowersModuleIdentifier,
            legacyIdentifiers: [],
            registrationName: "Comparador de seguidores de Instagram",
            navigationOrder: 50,
            settingsOrder: nil,
            settingsTitle: nil,
            commandTitle: "Abrir Comparador de seguidores",
            defaultShortcut: .command("5"),
            loadManifest: InstagramFollowersModuleDefinition.manifest,
            makeHistoryPresenters: { [InstagramFollowersHistoryPresenter()] }
        ),
        BuiltInModuleDescriptor(
            id: .multimediaInspector,
            primaryIdentifier: multimediaInspectorModuleIdentifier,
            legacyIdentifiers: [],
            registrationName: "Inspector multimedia",
            navigationOrder: 60,
            settingsOrder: 50,
            settingsTitle: "Inspector multimedia",
            commandTitle: "Abrir Inspector multimedia",
            defaultShortcut: .command("6"),
            loadManifest: MultimediaInspectorModuleDefinition.manifest,
            makeHistoryPresenters: { [MultimediaInspectorHistoryPresenter()] }
        ),
        BuiltInModuleDescriptor(
            id: .cleaner,
            primaryIdentifier: cleanerModuleIdentifier,
            legacyIdentifiers: [],
            registrationName: "Limpiador",
            navigationOrder: 70,
            settingsOrder: 60,
            settingsTitle: "Limpiador",
            commandTitle: "Abrir Limpiador",
            defaultShortcut: .command("7"),
            loadManifest: CleanerModuleDefinition.manifest,
            makeHistoryPresenters: { [CleanerHistoryPresenter()] }
        ),
    ]

    static var navigation: [BuiltInModuleDescriptor] {
        all.sorted { $0.navigationOrder < $1.navigationOrder }
    }

    static var settings: [BuiltInModuleDescriptor] {
        all
            .filter { $0.settingsOrder != nil }
            .sorted { ($0.settingsOrder ?? .max) < ($1.settingsOrder ?? .max) }
    }

    static var historyPresenters: [any ModuleHistoryPresenter] {
        all.flatMap { $0.makeHistoryPresenters() }
    }

    static func descriptor(for id: BuiltInModuleID) -> BuiltInModuleDescriptor {
        guard let descriptor = all.first(where: { $0.id == id }) else {
            preconditionFailure("Falta la integración del módulo built-in: \(id.rawValue)")
        }
        return descriptor
    }

    static func descriptor(forIdentifier identifier: String) -> BuiltInModuleDescriptor? {
        all.first { descriptor in
            descriptor.primaryIdentifier == identifier || descriptor.legacyIdentifiers.contains(identifier)
        }
    }

    static func registeredModules(
        from manifests: [ModuleManifest],
        orderedBy descriptors: [BuiltInModuleDescriptor]
    ) -> [RegisteredBuiltInModule] {
        let byIdentifier = Dictionary(uniqueKeysWithValues: manifests.map { ($0.identifier, $0) })
        return descriptors.compactMap { descriptor in
            guard let manifest = byIdentifier[descriptor.primaryIdentifier] else { return nil }
            return RegisteredBuiltInModule(descriptor: descriptor, manifest: manifest)
        }
    }

    static func dashboardModules(
        from manifests: [ModuleManifest],
        orderedBy descriptors: [BuiltInModuleDescriptor]
    ) -> [RegisteredBuiltInModule] {
        registeredModules(from: manifests, orderedBy: descriptors)
    }

    static let historyTargetID = "history"

    static var navigationDefaults: NavigationPreferencesDefaults {
        NavigationPreferencesDefaults(
            moduleOrder: navigation.map(\.primaryIdentifier),
            shortcuts: Dictionary(uniqueKeysWithValues:
                navigation.compactMap { descriptor in
                    descriptor.defaultShortcut.map { (descriptor.primaryIdentifier, $0) }
                } + [(historyTargetID, .command("8"))]
            ),
            historyTargetID: historyTargetID
        )
    }

    static func historyManifests(from manifests: [ModuleManifest]) -> [ModuleManifest] {
        var result = manifests
        for descriptor in all {
            guard let current = manifests.first(where: { $0.identifier == descriptor.primaryIdentifier }) else { continue }
            for legacyIdentifier in descriptor.legacyIdentifiers where !result.contains(where: { $0.identifier == legacyIdentifier }) {
                result.append(ModuleManifest(
                    schemaVersion: current.schemaVersion,
                    identifier: legacyIdentifier,
                    name: current.name,
                    summary: current.summary,
                    version: current.version,
                    minimumZEUVEVersion: current.minimumZEUVEVersion,
                    moduleAPI: current.moduleAPI,
                    technology: current.technology,
                    executionMode: current.executionMode,
                    permissions: current.permissions,
                    capabilities: current.capabilities,
                    presentation: current.presentation
                ))
            }
        }
        return result
    }

    static func historyIdentifiers(forSelectedIdentifier identifier: String?) -> [String?] {
        guard let identifier else { return [nil] }
        guard let descriptor = descriptor(forIdentifier: identifier) else { return [identifier] }
        return descriptor.historyIdentifiers.map(Optional.some)
    }
}
