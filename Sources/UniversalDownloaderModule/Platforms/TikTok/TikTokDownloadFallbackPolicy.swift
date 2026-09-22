public enum TikTokDownloadFallbackPolicy {
    public static func shouldRetryWithYTDLP(
        platform: UniversalDownloadPlatform,
        processSucceeded: Bool,
        candidateCount: Int
    ) -> Bool {
        platform == .tiktok && (!processSucceeded || candidateCount == 0)
    }
}
