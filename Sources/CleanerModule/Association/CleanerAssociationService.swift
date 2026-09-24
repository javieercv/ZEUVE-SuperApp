import Foundation

public struct CleanerAssociationScanResult: Sendable { public let candidates:[CleanerCandidate]; public let inaccessibleLocations:[String] }
public final class CleanerAssociationService: @unchecked Sendable {
    private let fileManager: FileManager
    private let homeDirectory: URL
    private let systemLibraryRoot: URL?
    public init(
        fileManager: FileManager = .default,
        homeDirectory: URL? = nil,
        systemLibraryRoot: URL? = URL(fileURLWithPath: "/Library", isDirectory: true)
    ) {
        self.fileManager = fileManager
        self.homeDirectory = homeDirectory ?? fileManager.homeDirectoryForCurrentUser
        self.systemLibraryRoot = systemLibraryRoot
    }

    public func scan(installedApps:[CleanerAppInventoryItem], historicalApps:[CleanerAppInventoryItem], keptPaths:Set<String>, runningBundleIDs:Set<String>) -> CleanerAssociationScanResult {
        let home = homeDirectory
        var locations:[(URL,CleanerCandidateCategory,Bool,Bool)] = [
            (home.appendingPathComponent("Library/Caches"),.cache,false,false),
            (home.appendingPathComponent("Library/Logs"),.log,false,false),
            (home.appendingPathComponent("Library/Preferences"),.preference,true,false),
            (home.appendingPathComponent("Library/Application Support"),.applicationSupport,true,false),
            (home.appendingPathComponent("Library/Containers"),.container,true,false),
            (home.appendingPathComponent("Library/Group Containers"),.groupContainer,true,false),
            (home.appendingPathComponent("Library/Saved Application State"),.savedState,false,false),
            (home.appendingPathComponent("Library/Application Scripts"),.applicationScript,true,false),
        ]
        if let systemLibraryRoot {
            locations.append(contentsOf: [
                (systemLibraryRoot.appendingPathComponent("Caches"), .cache, false, true),
                (systemLibraryRoot.appendingPathComponent("Logs"), .log, false, true),
                (systemLibraryRoot.appendingPathComponent("Preferences"), .preference, true, true),
                (systemLibraryRoot.appendingPathComponent("Application Support"), .applicationSupport, true, true),
            ])
        }
        let installedBundleIDs=Set(installedApps.compactMap{$0.identity.bundleID})
        var groupOwners:[String:Int]=[:]
        for app in installedApps { for group in app.identity.appGroups { groupOwners[group,default:0]+=1 } }
        var candidates:[CleanerCandidate]=[]; var inaccessible:[String]=[]
        for (root,category,userData,requiresAdministrator) in locations {
            if Task.isCancelled { break }
            guard fileManager.fileExists(atPath:root.path) else { continue }
            guard let children=try? fileManager.contentsOfDirectory(at:root,includingPropertiesForKeys:[.isSymbolicLinkKey],options:[.skipsHiddenFiles]) else { inaccessible.append(root.path); continue }
            for url in children {
                if Task.isCancelled { break }
                let path = url.standardizedFileURL.path
                let rawName = url.lastPathComponent
                let matchNames = category == .preference ? [rawName, url.deletingPathExtension().lastPathComponent] : [rawName]
                var app: CleanerAppInventoryItem?; var evidences: [CleanerEvidence] = []
                if let exact = historicalApps.first(where: { item in
                    guard let bundleID = item.identity.bundleID else { return false }
                    return matchNames.contains { $0 == bundleID || $0.hasPrefix(bundleID) }
                }) {
                    app = exact; evidences.append(.init(strength: .strong, explanation: "Coincide con el Bundle ID observado de la aplicación."))
                } else if let exact = historicalApps.first(where: { item in item.identity.appGroups.contains(rawName) }) {
                    app = exact; evidences.append(.init(strength: .strong, explanation: "Coincide con un App Group declarado por la aplicación."))
                } else if let guess = historicalApps.first(where: { item in matchNames.contains { normalize(item.identity.name) == normalize($0) } }) {
                    app = guess; evidences.append(.init(strength: .heuristic, explanation: "El nombre coincide con el nombre conocido de la aplicación."))
                }
                guard let app else { continue }
                let bundle=app.identity.bundleID
                let isInstalled = bundle.map(installedBundleIDs.contains) ?? installedApps.contains(where:{$0.identity.path==app.identity.path})
                let shared = category == .groupContainer && groupOwners[rawName,default:0] > 1
                let kept=keptPaths.contains(path)
                let unavailable=app.availability == .externalVolumeUnavailable
                let running=bundle.map(runningBundleIDs.contains) ?? false
                let confidence:CleanerAssociationConfidence = evidences.contains(where:{$0.strength == .strong}) ? .high : .low
                let status:CleanerResidueStatus
                if kept { status = .keptByUser }
                else if unavailable { status = .applicationUnavailable }
                else if isInstalled { status = .notResidue }
                else if confidence == .high { status = .probableResidue }
                else { status = .uncertainAssociation }
                var risk:CleanerRemovalRisk = category.isRegenerable ? .low : (userData ? .high : .medium)
                if shared || running || unavailable || confidence == .low || requiresAdministrator { risk = .high }
                let fp=CleanerFileInspection.fingerprint(at:url,fileManager:fileManager,shouldCancel:{Task.isCancelled})
                if Task.isCancelled { break }
                candidates.append(.init(url:url,category:category,associatedAppName:app.identity.name,associatedBundleID:bundle,evidences:evidences,confidence:confidence,status:status,risk:risk,logicalSize:fp?.logicalSize,allocatedSize:fp?.allocatedSize,containsPotentialUserData:userData,isShared:shared,requiresAdministrator:requiresAdministrator,applicationRunning:running,consequence: consequence(category:category, userData:userData),selected:false,fingerprint:fp))
            }
        }
        return .init(candidates:candidates,inaccessibleLocations:inaccessible)
    }
    private func normalize(_ s:String)->String{s.lowercased().replacingOccurrences(of:" ",with:"").replacingOccurrences(of:"-",with:"").replacingOccurrences(of:"_",with:"")}
    private func consequence(category:CleanerCandidateCategory,userData:Bool)->String { userData ? "Puede contener preferencias o datos persistentes. No se selecciona automáticamente." : (category.isRegenerable ? "Datos regenerables; la aplicación puede recrearlos." : "Revisa su función antes de eliminarlo.") }
}
