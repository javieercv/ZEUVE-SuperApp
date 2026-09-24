import Foundation
import ZEUVECore
import ZEUVEOperations

public struct CleanerAnalysisResult:Sendable{public let applications:[CleanerAppInventoryItem];public let candidates:[CleanerCandidate];public let summary:CleanerScanSummary;public let discoveryStatus:CleanerApplicationDiscoveryStatus}
public final class CleanerAnalysisService:@unchecked Sendable{
    let coordinator:OperationCoordinator;let repository:CleanerRepository?;let inventoryService:CleanerInventoryService;let spotlight:any CleanerApplicationDiscovering;let identityProvider:any CleanerAppIdentityProviding;let association:CleanerAssociationService;let launch:CleanerLaunchItemScanner;let xcode:CleanerDevelopmentScanner;let installers:CleanerInstallerScanner;let fileManager:FileManager
    public init(coordinator:OperationCoordinator,repository:CleanerRepository?,fileManager:FileManager = .default,identityProvider:any CleanerAppIdentityProviding=SystemCleanerAppIdentityProvider(),spotlight:any CleanerApplicationDiscovering=CleanerSpotlightApplicationDiscovery()){self.coordinator=coordinator;self.repository=repository;self.fileManager=fileManager;self.identityProvider=identityProvider;self.spotlight=spotlight;self.inventoryService = .init(fileManager:fileManager,identityProvider:identityProvider);self.association = .init(fileManager:fileManager);self.launch = .init(fileManager:fileManager);self.xcode = .init(fileManager:fileManager);self.installers = .init(fileManager:fileManager)}
    public func analyze(preferences:CleanerPreferences)async throws->CleanerAnalysisResult{
        let op=try await coordinator.begin(moduleID:cleanerModuleIdentifier,name:"Analizando almacenamiento");let started=Date()
        do{
            let extra=Self.resolve(preferences.additionalFolderBookmarks);try? await coordinator.update(id:op,progress:.init(completed:0,total:nil,phase:"Inventariando aplicaciones"));var inventory=await runCancellable(operationID:op){[inventoryService] in inventoryService.scan(additionalRoots:extra)}
            if await coordinator.shouldCancel(id:op){throw CancellationError()}
            let discovery = await runCancellable(operationID:op){[spotlight] in await spotlight.discoverApplications()}
            if await coordinator.shouldCancel(id:op) || discovery.status == .cancelled { throw CancellationError() }
            var seen=Set(inventory.applications.map{$0.identity.path});var apps=inventory.applications
            for url in discovery.urls where fileManager.fileExists(atPath:url.path) && seen.insert(url.standardizedFileURL.path).inserted{if let id=identityProvider.identity(for:url){apps.append(.init(identity:id,logicalSize:CleanerFileInspection.recursiveSize(at:url,fileManager:fileManager).logical))}}
            inventory = .init(applications:apps,inaccessibleLocations:inventory.inaccessibleLocations);let keys=Set(apps.map{($0.identity.bundleID ?? "unsigned") + "|" + $0.identity.path});try repository?.upsertInventory(apps)
            let canConfirmAbsentApplications = Self.canConfirmAbsentApplications(discoveryStatus:discovery.status,inaccessibleLocations:inventory.inaccessibleLocations)
            if canConfirmAbsentApplications { try repository?.markMissingInventory(except:keys) }
            let history=(try? repository?.loadInventory()) ?? [];let kept=(try? repository?.keptPaths()) ?? []
            let associationApps = Self.applicationsForAssociation(current:apps,historical:history,canConfirmAbsent:canConfirmAbsentApplications)
            if await coordinator.shouldCancel(id:op){throw CancellationError()};try? await coordinator.update(id:op,progress:.init(completed:0,total:nil,phase:"Relacionando residuos y guardas"))
            let assoc=await runCancellable(operationID:op){[association, identityProvider] in association.scan(installedApps:associationApps,historicalApps:history,keptPaths:kept,runningBundleIDs:identityProvider.runningBundleIdentifiers())};let launchResult=await runCancellable(operationID:op){[launch] in launch.scan()};var candidates=assoc.candidates+launchResult.candidates
            if preferences.scanXcode{candidates += await runCancellable(operationID:op){[xcode] in xcode.scanXcode()}}
            if preferences.scanOldInstallers{let roots=[fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")]+extra;candidates += await runCancellable(operationID:op){[installers] in installers.scan(roots:roots,olderThanDays:preferences.oldInstallerDays)}}
            if !preferences.scanCaches{candidates.removeAll{$0.category == .cache}};if !preferences.scanLogs{candidates.removeAll{$0.category == .log}}
            if await coordinator.shouldCancel(id:op){throw CancellationError()};try repository?.upsertAssociatedRoots(candidates)
            let inaccessible=inventory.inaccessibleLocations.count+assoc.inaccessibleLocations.count+launchResult.inaccessible.count;let scanned=apps.compactMap(\.logicalSize).reduce(0,+)+candidates.compactMap(\.logicalSize).reduce(0,+);let recoverable=candidates.filter(\.canBeSafelyPreselected).compactMap(\.allocatedSize).reduce(0,+);let summary=CleanerScanSummary(startedAt:started,finishedAt:Date(),coverage:inaccessible==0 && discovery.status == .complete ? .complete:.partial,scannedLogicalBytes:scanned,potentialRecoverableBytes:recoverable,inaccessibleLocations:inaccessible,appCount:apps.count,candidateCount:candidates.count);try repository?.saveScanMetadata(summary);try await coordinator.finish(id:op);return .init(applications:apps.sorted{$0.identity.name<$1.identity.name},candidates:candidates.sorted{($0.logicalSize ?? 0)>($1.logicalSize ?? 0)},summary:summary,discoveryStatus:discovery.status)
        }catch{try? await coordinator.finish(id:op);throw error}
    }
    private func runCancellable<T:Sendable>(operationID:UUID,operation:@escaping @Sendable () async -> T) async -> T {
        let task=Task.detached { await operation() }
        let cancellationTask=Task.detached { [coordinator] in
            for await snapshot in await coordinator.snapshots() {
                if snapshot?.id == operationID && snapshot?.status == .cancelling {
                    task.cancel()
                    break
                }
            }
        }
        let result=await task.value
        cancellationTask.cancel()
        return result
    }
    static func canConfirmAbsentApplications(discoveryStatus:CleanerApplicationDiscoveryStatus,inaccessibleLocations:[String])->Bool {
        discoveryStatus == .complete && inaccessibleLocations.isEmpty
    }
    static func applicationsForAssociation(current:[CleanerAppInventoryItem],historical:[CleanerAppInventoryItem],canConfirmAbsent:Bool)->[CleanerAppInventoryItem] {
        guard !canConfirmAbsent else { return current }
        let currentIDs=Set(current.map(\.id))
        return current + historical.filter { !currentIDs.contains($0.id) && $0.availability != .missing }
    }
    private static func resolve(_ bookmarks:[Data])->[URL]{let codec=SystemFolderBookmarkCodec();return bookmarks.compactMap{try? codec.resolveBookmark($0).url}}
}
