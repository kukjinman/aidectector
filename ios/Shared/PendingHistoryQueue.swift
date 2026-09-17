import Foundation

/// A result produced by the Share Extension, waiting to be adopted into the
/// main app's SwiftData store. The extension and the app run in separate
/// processes, so results are handed off through App Group UserDefaults
/// rather than writing to SwiftData directly from the extension.
struct PendingHistoryItem: Codable, Identifiable {
    let id: UUID
    let sourceURL: String
    let thumbnailURL: String
    let aiProbability: Double
    let label: String
    let mediaType: String
    let provider: String
    let analyzedAt: Date
}

enum PendingHistoryQueue {
    private static let key = "pendingHistoryItems"

    static func enqueue(_ item: PendingHistoryItem) {
        var items = loadAll()
        items.append(item)
        save(items)
    }

    /// Returns everything queued since the last drain and clears the queue.
    static func drainAll() -> [PendingHistoryItem] {
        let items = loadAll()
        if !items.isEmpty {
            AppConfig.sharedDefaults.removeObject(forKey: key)
        }
        return items
    }

    private static func loadAll() -> [PendingHistoryItem] {
        guard let data = AppConfig.sharedDefaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([PendingHistoryItem].self, from: data)) ?? []
    }

    private static func save(_ items: [PendingHistoryItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        AppConfig.sharedDefaults.set(data, forKey: key)
    }
}
