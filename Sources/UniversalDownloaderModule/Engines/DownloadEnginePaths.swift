import Foundation

public struct DownloadEnginePaths: Sendable, Equatable {
    public let ytDLP: URL
    public let deno: URL
    public let ffmpeg: URL
    public let ffprobe: URL
    public let galleryDL: URL?
    public let instagramCatalog: URL?
    public let browserHelper: URL?
    public let cacheDirectory: URL?

    public init(
        ytDLP: URL,
        deno: URL,
        ffmpeg: URL,
        ffprobe: URL,
        galleryDL: URL? = nil,
        instagramCatalog: URL? = nil,
        browserHelper: URL? = nil,
        cacheDirectory: URL? = nil
    ) {
        self.ytDLP = ytDLP.standardizedFileURL
        self.deno = deno.standardizedFileURL
        self.ffmpeg = ffmpeg.standardizedFileURL
        self.ffprobe = ffprobe.standardizedFileURL
        self.galleryDL = galleryDL?.standardizedFileURL
        self.instagramCatalog = instagramCatalog?.standardizedFileURL
        self.browserHelper = browserHelper?.standardizedFileURL
        self.cacheDirectory = cacheDirectory?.standardizedFileURL
    }
}
