import Foundation
import ZEUVECore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct InstagramArchivedProfilePictureCandidate: Sendable, Equatable, Identifiable {
    public let id: String
    public let capturedAt: Date?
    public let snapshotURL: URL
    public let imageURL: URL
    public let sourceName: String
    public let confidence: String

    public init(capturedAt: Date?, snapshotURL: URL, imageURL: URL, sourceName: String = "Wayback Machine", confidence: String = "Imagen referenciada por una captura archivada") {
        self.id = snapshotURL.absoluteString + "|" + imageURL.absoluteString
        self.capturedAt = capturedAt
        self.snapshotURL = snapshotURL
        self.imageURL = imageURL
        self.sourceName = sourceName
        self.confidence = confidence
    }
}

public enum InstagramProfilePictureArchiveError: LocalizedError, Equatable {
    case invalidUsername
    case invalidResponse
    case noSnapshots

    public var errorDescription: String? {
        switch self {
        case .invalidUsername: return "El nombre de usuario no es válido."
        case .invalidResponse: return "El archivo web no ha devuelto una respuesta válida."
        case .noSnapshots: return "No se han encontrado capturas con una fotografía recuperable. La búsqueda histórica no garantiza resultados."
        }
    }
}

/// Búsqueda manual y de mejor esfuerzo. No se ejecuta en segundo plano y no promete
/// recuperar fotografías que Instagram o el archivo web no hayan conservado.
public struct InstagramProfilePictureArchiveService: Sendable {
    public init() {}

    public static func makeEphemeralSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 120
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        return URLSession(configuration: configuration)
    }

    public func searchInstagramProfile(
        username: String,
        maximumSnapshots: Int = 20,
        session: URLSession? = nil
    ) async throws -> [InstagramArchivedProfilePictureCandidate] {
        let session = session ?? Self.makeEphemeralSession()
        let clean = username.trimmingCharacters(in: CharacterSet(charactersIn: "@ "))
        guard clean.range(of: "^[A-Za-z0-9._]{1,30}$", options: .regularExpression) != nil else {
            throw InstagramProfilePictureArchiveError.invalidUsername
        }
        var components = URLComponents(string: "https://web.archive.org/cdx/search/cdx")!
        components.queryItems = [
            .init(name: "url", value: "instagram.com/\(clean)"),
            .init(name: "output", value: "json"),
            .init(name: "filter", value: "statuscode:200"),
            .init(name: "filter", value: "mimetype:text/html"),
            .init(name: "fl", value: "timestamp,original,statuscode,mimetype,digest"),
            .init(name: "collapse", value: "digest"),
            .init(name: "limit", value: String(max(1, min(maximumSnapshots, 100)))),
            .init(name: "from", value: "2010")
        ]
        guard let url = components.url else { throw InstagramProfilePictureArchiveError.invalidResponse }
        var request = URLRequest(url: url)
        request.setValue(ZEUVEProductInfo.httpUserAgentToken, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw InstagramProfilePictureArchiveError.invalidResponse
        }
        let snapshots = try Self.parseCDX(data)
        guard !snapshots.isEmpty else { throw InstagramProfilePictureArchiveError.noSnapshots }

        var results: [InstagramArchivedProfilePictureCandidate] = []
        var seen = Set<String>()
        for snapshot in snapshots {
            guard !Task.isCancelled else { throw CancellationError() }
            guard let snapshotURL = URL(string: "https://web.archive.org/web/\(snapshot.timestamp)id_/https://www.instagram.com/\(clean)/") else { continue }
            do {
                var pageRequest = URLRequest(url: snapshotURL)
                pageRequest.setValue(ZEUVEProductInfo.httpUserAgentToken, forHTTPHeaderField: "User-Agent")
                let (htmlData, pageResponse) = try await session.data(for: pageRequest)
                guard let pageHTTP = pageResponse as? HTTPURLResponse, (200...299).contains(pageHTTP.statusCode),
                      let html = String(data: htmlData, encoding: .utf8),
                      let imageURL = Self.profileImageURL(in: html, snapshotURL: snapshotURL),
                      seen.insert(imageURL.absoluteString).inserted else { continue }
                results.append(.init(
                    capturedAt: Self.date(from: snapshot.timestamp),
                    snapshotURL: snapshotURL,
                    imageURL: imageURL
                ))
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                continue
            }
        }
        guard !results.isEmpty else { throw InstagramProfilePictureArchiveError.noSnapshots }
        return results.sorted { ($0.capturedAt ?? .distantPast) > ($1.capturedAt ?? .distantPast) }
    }

    public static func parseCDX(_ data: Data) throws -> [(timestamp: String, original: String)] {
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[Any]], rows.count >= 2 else {
            throw InstagramProfilePictureArchiveError.invalidResponse
        }
        let headers = rows[0].compactMap { $0 as? String }
        guard let timestampIndex = headers.firstIndex(of: "timestamp"),
              let originalIndex = headers.firstIndex(of: "original") else {
            throw InstagramProfilePictureArchiveError.invalidResponse
        }
        return rows.dropFirst().compactMap { row in
            guard row.indices.contains(timestampIndex), row.indices.contains(originalIndex),
                  let timestamp = row[timestampIndex] as? String,
                  let original = row[originalIndex] as? String,
                  timestamp.range(of: "^[0-9]{14}$", options: .regularExpression) != nil else { return nil }
            return (timestamp, original)
        }
    }

    public static func profileImageURL(in html: String, snapshotURL: URL) -> URL? {
        let patterns = [
            #"<meta[^>]+property=[\"']og:image[\"'][^>]+content=[\"']([^\"']+)[\"']"#,
            #"<meta[^>]+content=[\"']([^\"']+)[\"'][^>]+property=[\"']og:image[\"']"#,
            #"\"profile_pic_url_hd\"\s*:\s*\"([^\"]+)\""#,
            #"\"profile_pic_url\"\s*:\s*\"([^\"]+)\""#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                  let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                  let range = Range(match.range(at: 1), in: html) else { continue }
            var value = String(html[range])
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "\\u0026", with: "&")
                .replacingOccurrences(of: "\\/", with: "/")
            if value.hasPrefix("//") { value = "https:" + value }
            if let absolute = URL(string: value, relativeTo: snapshotURL)?.absoluteURL,
               ["http", "https"].contains(absolute.scheme?.lowercased() ?? "") {
                return absolute
            }
        }
        return nil
    }

    private static func date(from timestamp: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMddHHmmss"
        return formatter.date(from: timestamp)
    }
}
