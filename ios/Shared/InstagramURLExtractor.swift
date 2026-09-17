import Foundation

/// Recognizes public Instagram post/reel/tv permalinks, matching the backend's
/// validateInstagramUrl (backend/src/lib/validateUrl.ts) so the client can
/// reject obviously-invalid input before making a network call.
enum InstagramURLExtractor {
    private static let pathPattern = try! NSRegularExpression(
        pattern: #"^/(p|reel|tv)/[^/]+/?"#
    )

    static func isValidInstagramPostURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" else { return false }
        guard let host = url.host?.lowercased() else { return false }
        guard host == "instagram.com" || host == "www.instagram.com" else { return false }

        let path = url.path
        let range = NSRange(path.startIndex..., in: path)
        return pathPattern.firstMatch(in: path, range: range) != nil
    }

    /// Finds the first valid Instagram post URL inside free-form text
    /// (used when a share extension hands us plain text instead of a URL item).
    static func firstInstagramURL(in text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        for match in detector.matches(in: text, range: range) {
            if let url = match.url, isValidInstagramPostURL(url) {
                return url
            }
        }
        return nil
    }
}
