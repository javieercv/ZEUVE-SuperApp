import Foundation
import XCTest
@testable import UniversalDownloaderModule

final class UniversalSocialDownloaderTests: XCTestCase {
    func testDirectMediaUsesDeliveredMIMEWhenCDNNegotiatesAnotherFormat() {
        XCTAssertEqual(
            DirectHTTPDownloadService.extensionName(
                explicit: "jpg",
                mimeType: "image/webp",
                url: URL(string: "https://cdn.example/media.jpg")!
            ),
            "webp"
        )
        XCTAssertEqual(
            DirectHTTPDownloadService.extensionName(
                explicit: "mp4",
                mimeType: "application/octet-stream",
                url: URL(string: "https://cdn.example/media")!
            ),
            "mp4"
        )
    }
    func testInstagramUsernameAndProfileAreCatalogInputs() throws {
        let username = try UniversalDownloadInputValidator().validate("@zeuve", platform: .instagram)
        XCTAssertEqual(username.platform, .instagram)
        XCTAssertEqual(username.kind, .profile)
        XCTAssertEqual(username.profileUsername, "zeuve")
        XCTAssertEqual(username.canonicalURL.absoluteString, "https://www.instagram.com/zeuve/")

        let profile = try UniversalDownloadInputValidator().validate("https://instagram.com/zeuve/", platform: .instagram)
        XCTAssertEqual(profile.kind, .profile)
        XCTAssertEqual(profile.profileUsername, "zeuve")
    }


    func testInstagramKeepsProfileAndStorySemanticsInWebpageMode() throws {
        let profile = try UniversalDownloadInputValidator().validate(
            "https://www.instagram.com/zeuve/",
            platform: .webpage
        )
        XCTAssertEqual(profile.platform, .instagram)
        XCTAssertEqual(profile.kind, .profile)
        XCTAssertEqual(profile.profileUsername, "zeuve")

        let story = try UniversalDownloadInputValidator().validate(
            "https://www.instagram.com/stories/zeuve/123456789/",
            platform: .webpage
        )
        XCTAssertEqual(story.platform, .instagram)
        XCTAssertEqual(story.kind, .gallery)
        XCTAssertEqual(UniversalEngineRouter.strategy(for: story, browserFallbackEnabled: false).primary, .instagramCatalog)
    }

    func testBrowserFallbackFlagNoLongerAddsAnUnimplementedEngine() throws {
        let input = try UniversalDownloadInputValidator().validate(
            "https://example.com/video",
            platform: .webpage
        )
        let disabled = UniversalEngineRouter.strategy(for: input, browserFallbackEnabled: false).ordered
        let legacyEnabled = UniversalEngineRouter.strategy(for: input, browserFallbackEnabled: true).ordered
        XCTAssertEqual(legacyEnabled, disabled)
        XCTAssertFalse(legacyEnabled.contains(.browser))
    }

    func testConcreteInstagramLinksPreferSpecificEngineThenPublicFallbacks() throws {
        let reel = try UniversalDownloadInputValidator().validate(
            "https://www.instagram.com/reels/DcWzMFPuXtg/",
            platform: .instagram
        )
        XCTAssertEqual(reel.platform, .instagram)
        XCTAssertNotEqual(reel.kind, .profile)
        XCTAssertEqual(
            UniversalEngineRouter.strategy(for: reel, browserFallbackEnabled: false).ordered,
            [.instagramCatalog, .galleryDL, .ytDLP, .genericPage]
        )
    }

    func testInstagramDirectCommandAcceptsPostAndReelShortcodesWithoutCookiesByDefault() throws {
        let builder = InstagramCatalogCommandBuilder()
        for raw in [
            "https://www.instagram.com/p/Photo_123/",
            "https://www.instagram.com/reel/Reel-456/",
        ] {
            let input = try UniversalDownloadInputValidator().validate(raw, platform: .instagram)
            let arguments = try builder.directArguments(for: input)
            XCTAssertEqual(arguments.first, "direct")
            XCTAssertTrue(arguments.contains("--shortcode"))
            XCTAssertFalse(arguments.contains("--cookies"))
            XCTAssertFalse(arguments.contains("--cookie-header-file"))
        }
    }

    func testInstagramDirectParserKeepsEveryPhotoAndVideoInMixedCarousel() throws {
        let input = try UniversalDownloadInputValidator().validate(
            "https://www.instagram.com/p/MixedCarousel/",
            platform: .instagram
        )
        let jsonl = """
        {"record":"post","username":"zeuve","post_id":"900","shortcode":"MixedCarousel","typename":"GraphSidecar","is_video":false,"media_count":5,"session_supplied":false}
        {"record":"media","section":"posts","username":"zeuve","post_id":"900","shortcode":"MixedCarousel","id":"900-1","index":1,"kind":"photo","media_url":"https://cdn.example/1.jpg","thumbnail_url":"https://cdn.example/1.jpg","extension":"jpg","source_page":"https://www.instagram.com/p/MixedCarousel/"}
        {"record":"media","section":"posts","username":"zeuve","post_id":"900","shortcode":"MixedCarousel","id":"900-2","index":2,"kind":"video","media_url":"https://cdn.example/2.mp4","thumbnail_url":"https://cdn.example/2.jpg","extension":"mp4","source_page":"https://www.instagram.com/p/MixedCarousel/"}
        {"record":"media","section":"posts","username":"zeuve","post_id":"900","shortcode":"MixedCarousel","id":"900-3","index":3,"kind":"photo","media_url":"https://cdn.example/3.jpg","thumbnail_url":"https://cdn.example/3.jpg","extension":"jpg","source_page":"https://www.instagram.com/p/MixedCarousel/"}
        {"record":"media","section":"posts","username":"zeuve","post_id":"900","shortcode":"MixedCarousel","id":"900-4","index":4,"kind":"video","media_url":"https://cdn.example/4.mp4","thumbnail_url":"https://cdn.example/4.jpg","extension":"mp4","source_page":"https://www.instagram.com/p/MixedCarousel/"}
        {"record":"media","section":"posts","username":"zeuve","post_id":"900","shortcode":"MixedCarousel","id":"900-5","index":5,"kind":"photo","media_url":"https://cdn.example/5.jpg","thumbnail_url":"https://cdn.example/5.jpg","extension":"jpg","source_page":"https://www.instagram.com/p/MixedCarousel/"}
        {"record":"page","offset":0,"next_cursor":null,"has_more":false,"returned":5,"known_total":5}
        """
        let parsed = try InstagramCatalogParser().parseDirectResult(data: Data(jsonl.utf8), input: input)
        XCTAssertEqual(parsed.analysis.engineKind, .instagramCatalog)
        XCTAssertEqual(parsed.analysis.playlistEntries.count, 5)
        XCTAssertEqual(parsed.analysis.playlistEntries.map(\.mediaKind), [.photo, .video, .photo, .video, .photo])
        XCTAssertEqual(parsed.analysis.playlistEntries.map(\.expectedExtension), ["jpg", "mp4", "jpg", "mp4", "jpg"])
        XCTAssertTrue(parsed.analysis.playlistEntries.allSatisfy { $0.engineKind == .genericPage && $0.resolvedMedia?.kind == .directFile })
    }

    func testPublicInstagramDownloadDoesNotUseAvailableSession() {
        let publicItem = UniversalDownloadItem(
            canonicalID: "instagram:DcWzMFPuXtg",
            sourceURL: URL(string: "https://www.instagram.com/reel/DcWzMFPuXtg/")!,
            title: "Reel público",
            platform: .instagram,
            requiresAuthentication: false
        )
        let privateItem = UniversalDownloadItem(
            canonicalID: "instagram:private",
            sourceURL: URL(string: "https://www.instagram.com/reel/private/")!,
            title: "Reel privado autorizado",
            platform: .instagram,
            requiresAuthentication: true
        )
        XCTAssertFalse(UniversalDownloadService.shouldUseSession(for: publicItem))
        XCTAssertTrue(UniversalDownloadService.shouldUseSession(for: privateItem))
    }

    func testAmbiguousInstagramLoginMessageDoesNotConfirmPrivateContent() {
        XCTAssertFalse(UniversalDownloadAnalysisService.isConfirmedPrivateInstagramFailure(
            "Requested content is not available, rate-limit reached or login required"
        ))
        XCTAssertTrue(UniversalDownloadAnalysisService.isConfirmedPrivateInstagramFailure(
            "This account is private"
        ))
        XCTAssertFalse(UniversalDownloadAnalysisService.shouldRetryConcreteInstagramWithSession(after: [
            "Requested content is not available, rate-limit reached or login required"
        ]))
        XCTAssertTrue(UniversalDownloadAnalysisService.shouldRetryConcreteInstagramWithSession(after: [
            "This account is private"
        ]))
    }

    func testInstagramLoginErrorProvidesSessionAction() {
        let result = DownloadErrorClassifier().classify(stderr: "ERROR: You need to log in to access this content")
        XCTAssertTrue(result.userMessage.contains("sesión válida"))
        XCTAssertTrue(result.userMessage.contains("cookies.txt"))
    }

    func testYouTubeForbiddenErrorDoesNotRequireBrowserSession() {
        let result = DownloadErrorClassifier().classify(
            stderr: "ERROR: unable to download video data: HTTP Error 403: Forbidden"
        )
        XCTAssertEqual(result.category, .network)
        XCTAssertTrue(result.userMessage.contains("rutas públicas"))
        XCTAssertFalse(result.userMessage.contains("sesión"))
        XCTAssertFalse(result.userMessage.contains("navegador"))
    }

    func testMissingPOTDoesNotClaimThatBrowserSessionIsRequired() {
        let result = DownloadErrorClassifier().classify(
            stderr: "WARNING: android_vr formats require a GVS PO Token"
        )
        XCTAssertEqual(result.category, .extractionFailed)
        XCTAssertTrue(result.userMessage.contains("rutas anónimas"))
        XCTAssertFalse(result.userMessage.contains("sesión"))
    }

    func testBrowserCookiePermissionErrorIsActionable() {
        let result = DownloadErrorClassifier().classify(
            stderr: "ERROR: could not copy browser cookie database"
        )
        XCTAssertEqual(result.category, .authenticationRequired)
        XCTAssertTrue(result.userMessage.contains("permisos de macOS"))
    }

    func testConcreteLinksRequiredOutsideInstagram() throws {
        XCTAssertThrowsError(try UniversalDownloadInputValidator().validate("https://www.tiktok.com/@zeuve", platform: .tiktok)) { error in
            XCTAssertEqual(error as? UniversalDownloaderError, .platformRequiresConcreteURL("TikTok"))
        }
        let post = try UniversalDownloadInputValidator().validate("https://www.tiktok.com/@zeuve/video/123456789", platform: .tiktok)
        XCTAssertEqual(post.platform, .tiktok)
        XCTAssertEqual(post.kind, .video)
        XCTAssertEqual(UniversalEngineRouter.strategy(for: post, browserFallbackEnabled: false).ordered, [.galleryDL, .ytDLP, .genericPage])

        let photoPost = try UniversalDownloadInputValidator().validate("https://www.tiktok.com/@zeuve/photo/123456789", platform: .automatic)
        XCTAssertEqual(photoPost.platform, .tiktok)
        XCTAssertEqual(photoPost.kind, .gallery)
    }

    func testReportedTikTokRetriesWithYTDLPWhenGalleryFinishesWithoutFiles() throws {
        let reportedURL = "https://www.tiktok.com/@l000rna/video/7675703483303071009"
        let input = try UniversalDownloadInputValidator().validate(reportedURL, platform: .tiktok)
        let item = UniversalDownloadItem(
            canonicalID: input.canonicalID,
            sourceURL: input.canonicalURL,
            title: "TikTok 7675703483303071009",
            playlistIndex: 0,
            platform: .tiktok,
            mediaKind: .video,
            engineKind: .galleryDL,
            expectedExtension: "mp4"
        )

        XCTAssertTrue(TikTokDownloadFallbackPolicy.shouldRetryWithYTDLP(
            platform: .tiktok,
            processSucceeded: true,
            candidateCount: 0
        ))
        XCTAssertTrue(TikTokDownloadFallbackPolicy.shouldRetryWithYTDLP(
            platform: .tiktok,
            processSucceeded: false,
            candidateCount: 0
        ))
        XCTAssertFalse(TikTokDownloadFallbackPolicy.shouldRetryWithYTDLP(
            platform: .tiktok,
            processSucceeded: true,
            candidateCount: 1
        ))
        XCTAssertFalse(TikTokDownloadFallbackPolicy.shouldRetryWithYTDLP(
            platform: .instagram,
            processSucceeded: true,
            candidateCount: 0
        ))

        let galleryArguments = try GalleryDLDownloadCommandBuilder().arguments(
            item: item,
            settings: UniversalDownloadSettings(),
            downloadDirectory: URL(fileURLWithPath: "/tmp/zeuve-tiktok-gallery"),
            cookiesFile: nil,
            proxy: nil
        )
        XCTAssertFalse(galleryArguments.contains("--range"))
        XCTAssertEqual(galleryArguments.last, reportedURL)

        let ytArguments = try YTDLPDownloadCommandBuilder().arguments(
            item: item,
            settings: UniversalDownloadSettings(),
            engines: DownloadEnginePaths(
                ytDLP: URL(fileURLWithPath: "/tmp/yt-dlp"),
                deno: URL(fileURLWithPath: "/tmp/deno"),
                ffmpeg: URL(fileURLWithPath: "/tmp/ffmpeg"),
                ffprobe: URL(fileURLWithPath: "/tmp/ffprobe")
            ),
            downloadDirectory: URL(fileURLWithPath: "/tmp/zeuve-tiktok-ytdlp"),
            temporaryDirectory: URL(fileURLWithPath: "/tmp/zeuve-tiktok-temp"),
            cookiesFile: nil,
            proxy: nil
        )
        XCTAssertEqual(ytArguments.last, reportedURL)
    }

    func testEmptyDownloadGetsAnActionableErrorAndTotalFailureState() {
        let classified = DownloadErrorClassifier().classify(
            stderr: "gallery-dl terminó sin producir archivos.\nyt-dlp terminó sin producir archivos."
        )
        XCTAssertEqual(classified.category, .extractionFailed)
        XCTAssertTrue(classified.userMessage.contains("sin generar ningún archivo"))

        let result = UniversalDownloadResult(
            id: UUID(),
            startedAt: Date(),
            outputFolder: URL(fileURLWithPath: "/tmp/zeuve-output"),
            mode: .video,
            formatSummary: "Original",
            items: [
                UniversalDownloadItemResult(
                    canonicalID: "tiktok:7675703483303071009",
                    title: "TikTok",
                    status: .failed,
                    errorReference: classified.technicalReference,
                    userMessage: classified.userMessage
                )
            ],
            wasCancelled: false
        )
        XCTAssertTrue(result.hasTotalFailure)
        XCTAssertEqual(result.completedCount, 0)
        XCTAssertEqual(result.failedCount, 1)
    }

    func testAdultContentIsBlockedBeforeAnalysisAndCanBeExplicitlyEnabled() throws {
        XCTAssertThrowsError(try UniversalDownloadInputValidator().validate("https://www.erome.com/a/TestAlbum", platform: .erome)) { error in
            XCTAssertEqual(error as? UniversalDownloaderError, .adultContentDisabled("www.erome.com"))
        }
        let value = try UniversalDownloadInputValidator().validate(
            "https://www.erome.com/a/TestAlbum",
            platform: .erome,
            allowAdultContent: true
        )
        XCTAssertTrue(value.isAdultContent)
        XCTAssertEqual(value.platform, .erome)
        XCTAssertThrowsError(try UniversalDownloadInputValidator().validate(
            "https://www.erome.com/u/example",
            platform: .erome,
            allowAdultContent: true
        ))
    }

    func testCustomAdultDomainIsBlocked() throws {
        XCTAssertThrowsError(try UniversalDownloadInputValidator().validate(
            "https://adult.example/media/1",
            platform: .webpage,
            additionalAdultDomains: ["adult.example"]
        ))
    }

    func testAllActiveLiveURLsAreRejected() throws {
        XCTAssertThrowsError(try UniversalDownloadInputValidator().validate("https://www.youtube.com/live/abc", platform: .youtube))
        XCTAssertThrowsError(try UniversalDownloadInputValidator().validate("https://www.twitch.tv/example", platform: .twitch))
        XCTAssertNoThrow(try UniversalDownloadInputValidator().validate("https://www.twitch.tv/videos/123", platform: .twitch))
    }

    func testSessionMaterialAcceptsCookieHeaderAndRejectsIncompleteText() throws {
        let normalized = try InstagramSessionMaterial.normalize("Cookie: csrftoken=abc; sessionid=secret; ds_user_id=12")
        XCTAssertTrue(normalized.hasPrefix("Cookie: "))
        XCTAssertTrue(normalized.contains("sessionid=secret"))
        XCTAssertThrowsError(try InstagramSessionMaterial.normalize("csrftoken=abc"))
        XCTAssertThrowsError(try InstagramSessionMaterial.normalize("session id=bad; sessionid=ok"))
    }

    func testPastedInstagramSessionAlsoCreatesAValidNetscapeCookieFile() throws {
        let file = try InstagramSessionMaterial.writeSecureNetscapeTemporaryFile(
            text: "Cookie: csrftoken=abc; sessionid=secret; ds_user_id=12"
        )
        defer { InstagramSessionMaterial.removeTemporaryFile(file) }
        let cookies = try NetscapeCookieFile.parse(Data(contentsOf: file))
        XCTAssertTrue(cookies.contains { $0.name == "sessionid" && $0.value == "secret" })
        let permissions = try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(permissions?.intValue, 0o600)
    }

    func testSessionTemporaryFileUsesRestrictedPermissionsAndCanBeRemoved() throws {
        let file = try InstagramSessionMaterial.writeSecureTemporaryFile(text: "sessionid=secret; csrftoken=abc")
        defer { InstagramSessionMaterial.removeTemporaryFile(file) }
        let permissions = try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(permissions?.intValue, 0o600)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        InstagramSessionMaterial.removeTemporaryFile(file)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testGalleryCommandsIgnoreUserConfigurationWithSupportedOption() throws {
        let input = try UniversalDownloadInputValidator().validate("https://www.tiktok.com/@zeuve/video/123456789", platform: .tiktok)
        let analysis = try GalleryDLAnalysisCommandBuilder().arguments(
            for: input,
            cookiesFile: nil,
            proxy: nil
        )
        XCTAssertTrue(analysis.contains("--config-ignore"))
        XCTAssertFalse(analysis.contains("--no-config"))

        let item = UniversalDownloadItem(
            canonicalID: input.canonicalID,
            sourceURL: input.canonicalURL,
            title: "TikTok",
            playlistIndex: 2,
            platform: .tiktok,
            mediaKind: .video,
            engineKind: .galleryDL
        )
        let download = try GalleryDLDownloadCommandBuilder().arguments(
            item: item,
            settings: UniversalDownloadSettings(),
            downloadDirectory: URL(fileURLWithPath: "/tmp/output"),
            cookiesFile: nil,
            proxy: nil
        )
        XCTAssertTrue(download.contains("--config-ignore"))
        XCTAssertFalse(download.contains("--no-config"))
        XCTAssertTrue(download.contains("--http-timeout"))
        XCTAssertFalse(download.contains("--timeout"))
        XCTAssertEqual(Array(download[download.firstIndex(of: "--range")!...].prefix(2)), ["--range", "2"])
        XCTAssertEqual(download.last, input.canonicalURL.absoluteString)
    }

    func testGalleryParserBuildsCurrentProtocolPhotoAndVideoEntriesWithoutRecompression() throws {
        let payload: [Any] = [
            [2, ["username": "zeuve", "title": "Álbum"]],
            [3, "https://cdn.example/image.jpg", ["id": "one", "extension": "jpg", "category": "photo"]],
            [3, "https://cdn.example/video.mp4", ["id": "two", "extension": "mp4", "category": "video"]],
            [6, "https://example.com/otra-pagina", ["id": "queue"]]
        ]
        let input = try UniversalDownloadInputValidator().validate("https://www.instagram.com/p/ABC/", platform: .instagram)
        let result = try GalleryDLAnalysisParser().parse(data: JSONSerialization.data(withJSONObject: payload), input: input)
        XCTAssertEqual(result.playlistEntries.count, 2)
        XCTAssertEqual(result.playlistEntries[0].mediaKind, .photo)
        XCTAssertEqual(result.playlistEntries[0].engineKind, .galleryDL)
        XCTAssertEqual(result.playlistEntries[0].sourceURL, input.canonicalURL)
        XCTAssertEqual(result.playlistEntries[0].expectedExtension, "jpg")
        XCTAssertEqual(result.playlistEntries[1].mediaKind, .video)
    }

    func testGalleryParserRetainsLegacyMessageCompatibility() throws {
        let payload: [Any] = [
            [1, ["username": "zeuve", "title": "Álbum anterior"]],
            [2, "https://cdn.example/legacy.jpg", ["id": "legacy", "extension": "jpg"]]
        ]
        let input = try UniversalDownloadInputValidator().validate("https://www.instagram.com/p/ABC/", platform: .instagram)
        let result = try GalleryDLAnalysisParser().parse(data: JSONSerialization.data(withJSONObject: payload), input: input)
        XCTAssertEqual(result.title, "Álbum anterior")
        XCTAssertEqual(result.playlistEntries.map(\.sourceURL.absoluteString), [input.canonicalURL.absoluteString])
    }

    func testInstagramCatalogParserRepresentsPrivateProfileAndPagination() throws {
        let input = try UniversalDownloadInputValidator().validate("private_user", platform: .instagram)
        let jsonl = """
        {"record":"profile","username":"private_user","full_name":"Privado","is_private":true,"requires_authentication":true,"profile_picture_url":"https://cdn.example/avatar.jpg","media_count":10}
        {"record":"page","next_cursor":"4","has_more":true,"known_total":10}
        """
        let result = try InstagramCatalogParser().parse(data: Data(jsonl.utf8), input: input)
        XCTAssertTrue(result.isPrivateProfile)
        XCTAssertTrue(result.requiresAuthentication)
        XCTAssertTrue(result.hasMoreEntries)
        XCTAssertEqual(result.paginationCursor, "4")
        XCTAssertFalse(result.isDownloadable)
    }

    func testInstagramCatalogParserBuildsProfilePictureAndStory() throws {
        let input = try UniversalDownloadInputValidator().validate("zeuve", platform: .instagram)
        let jsonl = """
        {"record":"profile","username":"zeuve","full_name":"ZEUVE","is_private":false,"requires_authentication":false,"profile_picture_url":"https://cdn.example/avatar.jpg","media_count":2}
        {"record":"media","section":"profile","username":"zeuve","id":"profile-current","index":1,"kind":"profilePicture","media_url":"https://cdn.example/avatar.jpg","thumbnail_url":"https://cdn.example/avatar.jpg","extension":"jpg"}
        {"record":"media","section":"stories","username":"zeuve","id":"story-1","index":2,"kind":"storyPhoto","media_url":"https://cdn.example/story.jpg","thumbnail_url":"https://cdn.example/story.jpg","extension":"jpg"}
        {"record":"page","has_more":false,"known_total":2}
        """
        let result = try InstagramCatalogParser().parse(data: Data(jsonl.utf8), input: input)
        XCTAssertEqual(result.playlistEntries.count, 2)
        XCTAssertEqual(result.playlistEntries[0].mediaKind, .profilePicture)
        XCTAssertEqual(result.playlistEntries[0].folderComponents, ["Instagram", "zeuve", "Perfil"])
        XCTAssertEqual(result.playlistEntries[1].mediaKind, .storyPhoto)
    }

    func testWaybackCDXAndProfileImageParsing() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            ["timestamp", "original", "statuscode", "mimetype", "digest"],
            ["20200102030405", "https://instagram.com/zeuve", "200", "text/html", "a"]
        ])
        let rows = try InstagramProfilePictureArchiveService.parseCDX(data)
        XCTAssertEqual(rows.first?.timestamp, "20200102030405")
        let html = #"<html><head><meta property="og:image" content="https://cdn.example/old-avatar.jpg?x=1&amp;y=2"></head></html>"#
        let url = InstagramProfilePictureArchiveService.profileImageURL(
            in: html,
            snapshotURL: URL(string: "https://web.archive.org/web/20200102030405id_/https://instagram.com/zeuve")!
        )
        XCTAssertEqual(url?.absoluteString, "https://cdn.example/old-avatar.jpg?x=1&y=2")
    }

    func testProfilePictureHistoryDoesNotDuplicateSameImage() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ZEUVE-Profile-History-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let image = root.appendingPathComponent("avatar.jpg")
        try Data([0xFF, 0xD8, 0xFF, 0xD9]).write(to: image)
        let store = InstagramProfilePictureHistoryStore(root: root.appendingPathComponent("history"))
        let first = try store.preserve(file: image, username: "zeuve")
        let second = try store.preserve(file: image, username: "zeuve")
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(try store.load(username: "zeuve").count, 1)
    }
    func testAmbiguousInstagramProfileLookupDoesNotRequireSessionOrClaimMissing() throws {
        let input = try UniversalDownloadInputValidator().validate("https://www.instagram.com/mar.rullan/", platform: .instagram)
        let jsonl = """
        {"record":"error","code":"profile_lookup_ambiguous","message":"Instagram no ha permitido comprobar si el perfil existe.","requires_authentication":false,"session_supplied":false,"session_validated":null}
        """
        let parsed = try InstagramCatalogParser().parseResult(data: Data(jsonl.utf8), input: input)
        XCTAssertFalse(parsed.analysis.requiresAuthentication)
        XCTAssertEqual(parsed.analysis.availability, "unavailable")
        XCTAssertEqual(parsed.issueCode, "profile_lookup_ambiguous")
        XCTAssertFalse(parsed.sessionSupplied)
        XCTAssertNil(parsed.sessionValidated)
        XCTAssertTrue(parsed.analysis.description?.contains("no ha permitido comprobar") == true)
        XCTAssertNil(parsed.analysis.authenticationRestrictedSections)
    }

    func testRejectedInstagramSessionDoesNotBlockPublicProfileRetry() throws {
        let input = try UniversalDownloadInputValidator().validate("https://www.instagram.com/mar.rullan/", platform: .instagram)
        let jsonl = """
        {"record":"error","code":"session_not_validated","message":"La sesión no se ha validado y la consulta pública tampoco ha podido completarse.","requires_authentication":false,"session_supplied":true,"session_validated":false}
        """
        let parsed = try InstagramCatalogParser().parseResult(data: Data(jsonl.utf8), input: input)
        XCTAssertFalse(parsed.analysis.requiresAuthentication)
        XCTAssertEqual(parsed.analysis.availability, "unavailable")
        XCTAssertTrue(parsed.sessionSupplied)
        XCTAssertEqual(parsed.sessionValidated, false)
        XCTAssertEqual(parsed.analysis.playlistEntries.count, 0)
    }

    func testLegacyProfileUnavailableFrom0101NoLongerClaimsProfileDoesNotExist() throws {
        let input = try UniversalDownloadInputValidator().validate("https://www.instagram.com/mar.rullan/", platform: .instagram)
        let jsonl = """
        {"record":"error","code":"profile_unavailable","message":"Profile mar.rullan does not exist."}
        """
        let analysis = try InstagramCatalogParser().parse(data: Data(jsonl.utf8), input: input)
        XCTAssertFalse(analysis.requiresAuthentication)
        XCTAssertFalse(analysis.isDownloadable)
    }

    func testPublicInstagramProfileKeepsPublicContentAndMarksRestrictedSections() throws {
        let input = try UniversalDownloadInputValidator().validate("https://www.instagram.com/zeuve/", platform: .instagram)
        let jsonl = """
        {"record":"profile","username":"zeuve","full_name":"ZEUVE","is_private":false,"requires_authentication":false,"profile_picture_url":"https://cdn.example/avatar.jpg","media_count":1}
        {"record":"warning","section":"stories","code":"section_requires_authentication","message":"Stories no disponibles sin una sesión de Instagram."}
        {"record":"warning","section":"highlights","code":"section_requires_authentication","message":"Destacadas no disponibles sin una sesión de Instagram."}
        {"record":"media","section":"profile","username":"zeuve","id":"profile-current","index":1,"kind":"profilePicture","media_url":"https://cdn.example/avatar.jpg","thumbnail_url":"https://cdn.example/avatar.jpg","extension":"jpg"}
        {"record":"page","has_more":false,"known_total":1}
        """
        let parsed = try InstagramCatalogParser().parseResult(data: Data(jsonl.utf8), input: input)
        XCTAssertFalse(parsed.analysis.requiresAuthentication)
        XCTAssertTrue(parsed.analysis.isDownloadable)
        XCTAssertEqual(parsed.analysis.playlistEntries.count, 1)
        XCTAssertEqual(Set(parsed.analysis.authenticationRestrictedSections ?? []), Set([.stories, .highlights]))
        XCTAssertNil(parsed.analysis.description)
    }

    func testUnknownInstagramCatalogFailureStillRaisesAnError() throws {
        let input = try UniversalDownloadInputValidator().validate("https://www.instagram.com/mar.rullan/", platform: .instagram)
        let jsonl = """
        {"record":"error","code":"engine_internal_failure","message":"Fallo interno sintético"}
        """
        XCTAssertThrowsError(try InstagramCatalogParser().parse(data: Data(jsonl.utf8), input: input))
    }

    func testProfileDoesNotExistMessageIsClassifiedAsUnverified() {
        let result = DownloadErrorClassifier().classify(stderr: "Profile mar.rullan does not exist.")
        XCTAssertEqual(result.category, .profileUnverified)
        XCTAssertTrue(result.userMessage.contains("no confirma"))
    }

}
