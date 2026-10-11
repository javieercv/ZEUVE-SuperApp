import Foundation

enum DownloadMediaIdentity {
    static func keys(for entry: DownloadCatalogItem) -> Set<String> {
        var keys: Set<String> = [key(for: entry)]
        if entry.gallerySelector != nil { keys.insert("resource:\(entry.canonicalID)") }
        return keys
    }
    static func key(for entry: DownloadCatalogItem) -> String {
        if let url = entry.resolvedMedia?.mediaURL {
            let parts = url.path.split(separator: "/").map(String.init)
            if url.host?.lowercased() == "video.twimg.com",
               parts.count > 1, ["ext_tw_video", "amplify_video"].contains(parts[0]),
               parts[1].allSatisfy(\.isNumber) {
                return "x:\(parts[0]):\(parts[1])"
            }
            return "media:\(UniversalURLNormalizer.duplicateKey(for: url))"
        }
        return "id:\(entry.canonicalID)"
    }

    static func qualityRank(for entry: DownloadCatalogItem) -> Int {
        if let url = entry.resolvedMedia?.mediaURL, url.host?.lowercased() == "video.twimg.com" {
            for part in url.path.split(separator: "/") {
                let dimensions = part.split(separator: "x")
                if dimensions.count == 2, let width = Int(dimensions[0]), let height = Int(dimensions[1]),
                   width > 0, height > 0, width <= 16_384, height <= 16_384 { return width * height }
            }
        }
        let width = Int(entry.safeMetadata["width"] ?? "") ?? 0
        let height = Int(entry.safeMetadata["height"] ?? "") ?? 0
        guard width > 0, height > 0, width <= 16_384, height <= 16_384 else { return 0 }
        return width * height
    }
}
