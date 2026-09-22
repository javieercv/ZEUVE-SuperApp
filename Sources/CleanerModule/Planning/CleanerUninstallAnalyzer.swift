import Foundation
public struct CleanerUninstallAnalysis:Sendable{public let application:CleanerAppInventoryItem;public let plan:CleanerRemovalPlan;public let officialUninstaller:CleanerOfficialUninstaller?;public let isRunning:Bool}
public struct CleanerUninstallAnalyzer{
    let fileManager:FileManager;let identityProvider:any CleanerAppIdentityProviding
    public init(fileManager:FileManager = .default,identityProvider:any CleanerAppIdentityProviding=SystemCleanerAppIdentityProvider()){self.fileManager=fileManager;self.identityProvider=identityProvider}
    public func analyze(application:CleanerAppInventoryItem,historicalApps:[CleanerAppInventoryItem],keptPaths:Set<String>,safeSelection:Bool)->CleanerUninstallAnalysis{
        let bundle=application.identity.bundleID;let running=bundle.map(identityProvider.runningBundleIdentifiers().contains) ?? false
        let association=CleanerAssociationService(fileManager:fileManager).scan(installedApps:[application],historicalApps:Array(Set(historicalApps+[application])),keptPaths:keptPaths,runningBundleIDs:running ? Set([bundle].compactMap{$0}):[])
        let appURL=URL(fileURLWithPath:application.identity.path);let fp=CleanerFileInspection.fingerprint(at:appURL,fileManager:fileManager)
        let needsAdmin = !fileManager.isWritableFile(atPath:appURL.deletingLastPathComponent().path)
        let appCandidate=CleanerCandidate(url:appURL,category:.application,associatedAppName:application.identity.name,associatedBundleID:bundle,evidences:[.init(strength:.strong,explanation:"Es la aplicación seleccionada para desinstalar.")],confidence:.high,status:.notResidue,risk:.medium,logicalSize:fp?.logicalSize,allocatedSize:fp?.allocatedSize,requiresAdministrator:needsAdmin,applicationRunning:running,consequence:"Eliminará la aplicación. Sus datos relacionados se revisan por separado.",selected:!running && !needsAdmin,fingerprint:fp)
        var related=association.candidates.filter{$0.associatedBundleID == bundle || $0.associatedAppName == application.identity.name}.map{ c in CleanerPlanner.copy(c,selected:safeSelection && c.canBeSafelyPreselected) }
        related.insert(appCandidate,at:0)
        return .init(application:application,plan:.init(candidates:related),officialUninstaller:CleanerOfficialUninstallerDetector(identityProvider:identityProvider).detect(for:application),isRunning:running)
    }
}
