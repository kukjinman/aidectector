import Foundation
import SwiftData

@Model
final class HistoryRecord {
    var id: UUID
    var sourceURL: String
    var thumbnailURL: String
    var aiProbability: Double
    var label: String
    var mediaType: String
    var provider: String
    var analyzedAt: Date

    init(
        id: UUID = UUID(),
        sourceURL: String,
        thumbnailURL: String,
        aiProbability: Double,
        label: String,
        mediaType: String,
        provider: String,
        analyzedAt: Date
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.thumbnailURL = thumbnailURL
        self.aiProbability = aiProbability
        self.label = label
        self.mediaType = mediaType
        self.provider = provider
        self.analyzedAt = analyzedAt
    }
}

extension HistoryRecord: AIResultDisplayable {
    var displayThumbnailURL: String { thumbnailURL }
    var displayProbability: Double { aiProbability }
    var displayLabel: String { label }
    var displayProvider: String { provider }
}
