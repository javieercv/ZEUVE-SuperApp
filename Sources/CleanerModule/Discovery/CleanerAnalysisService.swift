import Foundation
import ZEUVECore
import ZEUVEOperations

public struct CleanerAnalysisResult:Sendable{public let applications:[CleanerAppInventoryItem];public let candidates:[CleanerCandidate];public let summary:CleanerScanSummary}
public final class CleanerAnalysisService:@unchecked Sendable{
    let coordinator:OperationCoordinator;let repository:CleanerRepository?;let inventoryService:CleanerInventoryService;let spotlight:any CleanerApplicationDiscovering;let identityProvider:any CleanerAppIdentityProviding;let association:CleanerAssociationService;let launch:CleanerLaunchItemScanner;let xcode:CleanerDevelopmentScanner;let installers:CleanerInstallerScanner;let fileManager:FileManager
    public init(coordinator:OperationCoordinator,repository:CleanerRepository?,fileManager:FileManager = .default,identityProvider:any CleanerAppIdentityProviding=SystemCleanerAppIdentityProvider(),spotlight:any CleanerApplicationDiscovering=CleanerSpotlightApplicationDiscovery()){self.coordinator=coordinator;self.repository=repository;self.fileManager=fileManager;self.identityProvider=identityProvider;self.spotlight=spotlight;self.inventoryService = .init(fileManager:fileManager,identityProvider:identityProvider);self.association = .init(fileManager:fileManager);self.launch = .init(fileManager:fileManager);self.xcode = .init(fileManager:fileManager);self.installers = .init(fileManager:fileManager)}
    public func analyze(preferences:CleanerPreferences)async throws->CleanerAnalysisResult{
        let op=try await coordinator.begin(moduleID:cleanerModuleIdentifier,name:"Analizando almacenamiento");let started=Date()
        do{
            let extra=Self.resolve(preferences.additionalFolderBookmarks);try? await coordinator.update(id:op,progress:.init(completed:0,total:nil,phase:"Inventariando aplicaciones"));var inventory=await Task.detached{[inventoryService] in inventoryService.scan(additionalRoots:extra)}.value
            if await coordinator.shouldCancel(id:op){throw CancellationError()}
            let spotlightURLs=await spotlight.discoverApplications();var seen=Set(inventory.applications.map{$0.identity.path});var apps=inventory.applications
            for url in spotlightURLs where fileManager.fileExists(atPath:url.path) && seen.insert(url.standardizedFileURL.path).inserted{if let id=identityProvider.identity(for:url){apps.append(.init(identity:id,logicalSize:CleanerFileInspection.recursiveSize(at:url,fileManager:fileManager).logical))}}
            inventory = .init(applications:apps,inaccessibleLocations:inventory.inaccessibleLocations);let keys=Set(apps.map{($0.identity.bundleID ?? "unsigned") + "|" + $0.identity.path});try repository?.upsertInventory(apps);try repository?.markMissingInventory(except:keys);let history=(try? repository?.loadInventory()) ?? [];let kept=(try? repository?.keptPaths()) ?? []
            if await coordinator.shouldCancel(id:op){throw CancellationError()};try? await coordinator.update(id:op,progress:.init(completed:0,total:nil,phase:"Relacionando residuos y guardas"))
            let assoc=await Task.detached{[association, identityProvider] in association.scan(installedApps:apps,historicalApps:history,keptPaths:kept,runningBundleIDs:identityProvider.runningBundleIdentifiers())}.value;let launchResult=await Task.detached{[launch] in launch.scan()}.value;var candidates=assoc.candidates+launchResult.candidates
            if preferences.scanXcode{candidates += await Task.detached{[xcode] in xcode.scanXcode()}.value}
            if preferences.scanOldInstallers{var roots=[fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")];roots += extra;candidates += await Task.detached{[installers] in installers.scan(roots:roots,olderThanDays:preferences.oldInstallerDays)}.value}
            if !preferences.scanCaches{candidates.removeAll{$0.category == .cache}};if !preferences.scanLogs{candidates.removeAll{$0.category == .log}}
            if await coordinator.shouldCancel(id:op){throw CancellationError()};try repository?.upsertAssociatedRoots(candidates)
            let inaccessible=inventory.inaccessibleLocations.count+assoc.inaccessibleLocations.count+launchResult.inaccessible.count;let scanned=apps.compactMap(\.logicalSize).reduce(0,+)+candidates.compactMap(\.logicalSize).reduce(0,+);let recoverable=candidates.filter(\.canBeSafelyPreselected).compactMap(\.allocatedSize).reduce(0,+);let summary=CleanerScanSummary(startedAt:started,finishedAt:Date(),coverage:inaccessible==0 ? .complete:.partial,scannedLogicalBytes:scanned,potentialRecoverableBytes:recoverable,inaccessibleLocations:inaccessible,appCount:apps.count,candidateCount:candidates.count);try repository?.saveScanMetadata(summary);try await coordinator.finish(id:op);return .init(applications:apps.sorted{$0.identity.name<$1.identity.name},candidates:candidates.sorted{($0.logicalSize ?? 0)>($1.logicalSize ?? 0)},summary:summary)
        }catch{try? await coordinator.finish(id:op);throw error}
    }
    private static func resolve(_ bookmarks:[Data])->[URL]{let codec=SystemFolderBookmarkCodec();return bookmarks.compactMap{try? codec.resolveBookmark($0).url}}
}
