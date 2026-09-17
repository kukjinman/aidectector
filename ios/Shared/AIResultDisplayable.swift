import SwiftUI

/// Lets ResultCard render either a fresh API response or a persisted
/// HistoryRecord without knowing about either concrete type.
protocol AIResultDisplayable {
    var displayThumbnailURL: String { get }
    var displayProbability: Double { get }
    var displayLabel: String { get }
    var displayProvider: String { get }
}

extension AnalyzeSuccessResponse: AIResultDisplayable {
    var displayThumbnailURL: String { thumbnailUrl }
    var displayProbability: Double { aiProbability }
    var displayLabel: String { label }
    var displayProvider: String { provider }
}

func labelTitle(for label: String) -> String {
    switch label {
    case "likely_real": return "사람이 만든 콘텐츠일 가능성 높음"
    case "likely_ai": return "AI 생성 가능성 높음"
    default: return "판단하기 어려움"
    }
}

func labelColor(for label: String) -> Color {
    switch label {
    case "likely_real": return .green
    case "likely_ai": return .red
    default: return .orange
    }
}
