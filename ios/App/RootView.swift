import SwiftUI
import SwiftData

struct RootView: View {
    @EnvironmentObject private var store: CreditStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        HomeView()
        .onAppear(perform: adoptPendingHistory)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                adoptPendingHistory()
                Task { await store.refresh() }
            }
        }
    }

    /// Pulls in results the Share Extension queued while running in its own process.
    private func adoptPendingHistory() {
        let pending = PendingHistoryQueue.drainAll()
        guard !pending.isEmpty else { return }
        for item in pending {
            modelContext.insert(
                HistoryRecord(
                    id: item.id,
                    sourceURL: item.sourceURL,
                    thumbnailURL: item.thumbnailURL,
                    aiProbability: item.aiProbability,
                    label: item.label,
                    mediaType: item.mediaType,
                    provider: item.provider,
                    analyzedAt: item.analyzedAt
                )
            )
        }
        try? modelContext.save()
    }
}
