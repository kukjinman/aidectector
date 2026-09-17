import Foundation

@MainActor
final class ShareFlowViewModel: ObservableObject {
    enum State {
        case missingURL
        case ready(URL)
        case analyzing(URL)
        case success(AnalyzeSuccessResponse)
        case failure(String)
    }

    @Published private(set) var state: State
    private weak var extensionContext: NSExtensionContext?

    init(sharedURL: URL?, extensionContext: NSExtensionContext?) {
        self.extensionContext = extensionContext
        self.state = sharedURL.map(State.ready) ?? .missingURL
    }

    func startAnalysis() {
        guard case .ready(let url) = state else { return }
        state = .analyzing(url)

        Task {
            do {
                let response = try await AIDetectorAPI.analyze(url: url.absoluteString)
                PendingHistoryQueue.enqueue(
                    PendingHistoryItem(
                        id: UUID(),
                        sourceURL: url.absoluteString,
                        thumbnailURL: response.thumbnailUrl,
                        aiProbability: response.aiProbability,
                        label: response.label,
                        mediaType: response.mediaType,
                        provider: response.provider,
                        analyzedAt: ISO8601DateFormatter().date(from: response.analyzedAt) ?? Date()
                    )
                )
                state = .success(response)
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? "알 수 없는 오류가 발생했어요."
                state = .failure(message)
            }
        }
    }

    func close() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
