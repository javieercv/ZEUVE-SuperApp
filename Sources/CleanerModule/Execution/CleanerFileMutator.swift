import Foundation
public protocol CleanerFileMutating:Sendable{func moveToTrash(_ url:URL)throws->URL;func removePermanently(_ url:URL)throws;func restore(_ trashURL:URL,to originalURL:URL)throws}
public struct SystemCleanerFileMutator:CleanerFileMutating,@unchecked Sendable{
    let fileManager:FileManager;public init(fileManager:FileManager = .default){self.fileManager=fileManager}
    public func moveToTrash(_ url:URL)throws->URL{
        #if os(macOS)
        var result:NSURL?;try fileManager.trashItem(at:url,resultingItemURL:&result);guard let value=result as URL? else{throw CocoaError(.fileWriteUnknown)};return value
        #else
        let trash=fileManager.temporaryDirectory.appendingPathComponent("ZEUVE-Test-Trash",isDirectory:true);try fileManager.createDirectory(at:trash,withIntermediateDirectories:true);var target=trash.appendingPathComponent(url.lastPathComponent);if fileManager.fileExists(atPath:target.path){target=trash.appendingPathComponent(UUID().uuidString+"-"+url.lastPathComponent)};try fileManager.moveItem(at:url,to:target);return target
        #endif
    }
    public func removePermanently(_ url:URL)throws{try fileManager.removeItem(at:url)}
    public func restore(_ trashURL:URL,to originalURL:URL)throws{try fileManager.createDirectory(at:originalURL.deletingLastPathComponent(),withIntermediateDirectories:true);try fileManager.moveItem(at:trashURL,to:originalURL)}
}
