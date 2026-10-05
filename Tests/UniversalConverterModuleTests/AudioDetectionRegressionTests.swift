import Foundation
import Testing
@testable import UniversalConverterModule

@Test func adtsAACIsNotAnMPEGAudioFrameEvenWithMisleadingExtension() {
    let detector = ConverterFormatDetector()
    for header: UInt8 in [0xf1,0xf9] {
        let adts = Data([0xff,header,0x4c,0x40,0x01,0x3f,0xfc])
        #expect(detector.detect(sample: adts, filename: "salida.aac") == .aac)
        #expect(detector.detectDetailed(sample: adts, filename: "salida.mp3").warning != nil)
    }
    #expect(detector.detect(sample: Data([0xff,0xfb,0x90,0x64]), filename: "audio.bin") == .mp3)
    #expect(detector.detect(sample: Data([0xff,0xe9,0x90,0x64]), filename: "reservado.bin") != .mp3)
}
