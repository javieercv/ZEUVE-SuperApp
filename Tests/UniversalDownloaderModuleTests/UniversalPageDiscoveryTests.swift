import Foundation
import XCTest
@testable import UniversalDownloaderModule

final class UniversalPageDiscoveryTests: XCTestCase {
    func testHTMLParserFindsDirectManifestIframeMetadataAndRemovesDuplicates() throws {
        let html = #"""
        <html><head>
          <title>Página de prueba</title>
          <meta property="og:video" content="https://cdn.example.com/main.mp4?token=one">
          <script type="application/ld+json">
            {"@type":"VideoObject","contentUrl":"https://cdn.example.com/main.mp4?token=two","embedUrl":"https://player.example.com/embed/42"}
          </script>
        </head><body>
          <video src="/media/clip.webm"></video>
          <source src="https://cdn.example.com/live/master.m3u8?expires=1">
          <iframe src="https://player.example.com/embed/42"></iframe>
        </body></html>
        """#
        let result = UniversalHTMLMediaParser().parse(html: html, baseURL: URL(string: "https://site.example.com/article")!)
        XCTAssertEqual(result.pageTitle, "Página de prueba")
        XCTAssertEqual(result.candidates.count, 4)
        XCTAssertGreaterThanOrEqual(result.duplicateCount, 2)
        XCTAssertTrue(result.candidates.contains { $0.url.absoluteString == "https://site.example.com/media/clip.webm" })
        XCTAssertTrue(result.candidates.contains { $0.kind == .manifest })
        XCTAssertTrue(result.candidates.contains { $0.kind == .embeddedPlayer })
    }

    func testURLNormalizerRemovesTrackingAndTransientTokensOnlyForDeduplication() throws {
        let first = URL(string: "https://cdn.example.com/video.mp4?token=abc&utm_source=x&quality=1080")!
        let second = URL(string: "https://cdn.example.com/video.mp4?token=def&quality=1080")!
        XCTAssertEqual(UniversalURLNormalizer.duplicateKey(for: first), UniversalURLNormalizer.duplicateKey(for: second))
        XCTAssertTrue(UniversalURLNormalizer.canonicalURL(first).absoluteString.contains("token=abc"))
    }

    func testProvenanceURLKeepsUsefulPageIdentityAndRemovesPrivateTokens() throws {
        let original = URL(string: "https://www.ejemplo.com/a/JVwS60hN?token=secret&utm_source=test&lang=es#player")!
        let cleaned = UniversalURLNormalizer.provenanceURL(original)
        XCTAssertEqual(cleaned.absoluteString, "https://www.ejemplo.com/a/JVwS60hN?lang=es")
        XCTAssertEqual(UniversalURLNormalizer.pageIdentifier(for: original), "JVwS60hN")
    }

    func testNetscapeCookiesAreValidatedAndFilteredByDomain() throws {
        let text = """
        # Netscape HTTP Cookie File
        .example.com\tTRUE\t/\tTRUE\t4102444800\tsession\tsecret
        other.example\tFALSE\t/\tFALSE\t4102444800\tother\tvalue
        """
        let cookies = try NetscapeCookieFile.parse(Data(text.utf8))
        let header = NetscapeCookieFile.cookieHeader(for: URL(string: "https://video.example.com/page")!, cookies: cookies)
        XCTAssertEqual(header, "session=secret")
    }

    func testNetworkOptionsDecodeLegacyDataWithoutLocalHTTPFlag() throws {
        let data = Data(#"{"retryCount":3,"fragmentRetryCount":4,"connectionTimeoutSeconds":20,"concurrentFragments":2}"#.utf8)
        let value = try JSONDecoder().decode(DownloadNetworkOptions.self, from: data)
        XCTAssertFalse(value.allowInsecureLocalNetwork)
    }
}
