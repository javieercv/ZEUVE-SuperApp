import Foundation
import Testing
@testable import UniversalConverterModule

@Test func formatMappingAndCategories() {
    #expect(ConverterFormat.from(pathExtension: "JPG") == .jpeg)
    #expect(ConverterFormat.from(pathExtension: ".docx") == .unknown)
    #expect(ConverterFormat.from(pathExtension: ".csv") == .csv)
    #expect(ConverterFormat.mp4.category == .video)
    #expect(ConverterFormat.pdf.category == .pdf)
}

@Test func defaultSettingsNormalizeCanvas() {
    var settings = UniversalConverterSettings(audioVideoCanvas: .vertical1080, audioVideoWidth: 50, audioVideoHeight: 50, audioVideoFPS: 500)
    settings.normalize()
    #expect(settings.audioVideoWidth == 1_080)
    #expect(settings.audioVideoHeight == 1_920)
    #expect(settings.audioVideoFPS == 120)
}
