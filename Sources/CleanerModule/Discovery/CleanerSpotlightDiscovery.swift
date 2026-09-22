import Foundation
#if os(macOS)
import CoreServices
#endif
public protocol CleanerApplicationDiscovering: Sendable { func discoverApplications() async -> [URL] }
public struct CleanerSpotlightApplicationDiscovery: CleanerApplicationDiscovering {
    public init() {}
    public func discoverApplications() async -> [URL] {
        #if os(macOS)
        return await withCheckedContinuation { continuation in
            final class Box: NSObject, @unchecked Sendable { var observer:NSObjectProtocol?; let query=NSMetadataQuery() }
            let box=Box()
            box.query.predicate=NSPredicate(format:"kMDItemContentType == %@", "com.apple.application-bundle")
            box.observer=NotificationCenter.default.addObserver(forName:.NSMetadataQueryDidFinishGathering,object:box.query,queue:nil){ _ in
                box.query.disableUpdates(); box.query.stop()
                let urls=box.query.results.compactMap{ ($0 as? NSMetadataItem)?.value(forAttribute:NSMetadataItemPathKey) as? String }.map{URL(fileURLWithPath:$0)}
                if let observer=box.observer { NotificationCenter.default.removeObserver(observer) }; continuation.resume(returning:urls)
            }
            box.query.start()
        }
        #else
        return []
        #endif
    }
}
