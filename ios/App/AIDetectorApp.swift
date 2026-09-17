import SwiftUI
import SwiftData
import StoreKit

@main
struct AIDetectorApp: App {
    @StateObject private var store = CreditStore()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store)
                .task { await store.refresh(); await store.resumeUnfinished() }
        }
        .modelContainer(for: HistoryRecord.self)
    }
}
