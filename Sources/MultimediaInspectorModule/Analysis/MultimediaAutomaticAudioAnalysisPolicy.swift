import Foundation

public enum MultimediaAutomaticAudioAnalysisPolicy: Sendable {
    public static func shouldRun(audioStreamCount: Int) -> Bool {
        audioStreamCount == 1
    }
}
