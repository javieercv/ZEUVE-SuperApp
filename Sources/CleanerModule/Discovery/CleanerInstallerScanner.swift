import Foundation
public final class CleanerInstallerScanner:@unchecked Sendable{
    let fileManager:FileManager; public init(fileManager:FileManager = .default){self.fileManager=fileManager}
    public func scan(roots:[URL],olderThanDays:Int,now:Date=Date())->[CleanerCandidate]{
        let cutoff=now.addingTimeInterval(-Double(max(1,olderThanDays))*86400);let allowed:Set<String>=["dmg","pkg","xip"]
        var result:[CleanerCandidate]=[]
        var seenPaths=Set<String>()
        for root in roots where fileManager.fileExists(atPath:root.path){
            if Task.isCancelled { break }
            guard let e=fileManager.enumerator(at:root,includingPropertiesForKeys:[.contentModificationDateKey,.isSymbolicLinkKey],options:[.skipsHiddenFiles]) else{continue}
            for case let url as URL in e{
                if Task.isCancelled { break }
                let values=try? url.resourceValues(forKeys:[.contentModificationDateKey,.isSymbolicLinkKey]);if values?.isSymbolicLink==true{e.skipDescendants();continue}
                guard allowed.contains(url.pathExtension.lowercased()),let date=values?.contentModificationDate,date<cutoff,
                      seenPaths.insert(url.standardizedFileURL.path).inserted else{continue}
                let fp=CleanerFileInspection.fingerprint(at:url,fileManager:fileManager)
                result.append(.init(url:url,category:.installer,evidences:[.init(strength:.heuristic,explanation:"Instalador con más de \(max(1,olderThanDays)) días.")],confidence:.low,status:.uncertainAssociation,risk:.medium,logicalSize:fp?.logicalSize,allocatedSize:fp?.allocatedSize,containsPotentialUserData:true,consequence:"La antigüedad no demuestra que ya no sea necesario. Nunca se selecciona automáticamente.",fingerprint:fp))
            }
        };return result
    }
}
