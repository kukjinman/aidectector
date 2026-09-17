import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HistoryRecord.analyzedAt, order: .reverse) private var records: [HistoryRecord]

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    ContentUnavailableView(
                        "아직 판별 기록이 없어요",
                        systemImage: "clock",
                        description: Text("텍스트·미디어·URL을 분석하면 여기에 기록돼요.")
                    )
                } else {
                    List {
                        ForEach(records) { record in
                            NavigationLink(value: record) {
                                HistoryRow(record: record)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("히스토리").toolbar(.visible, for: .navigationBar)
            .navigationDestination(for: HistoryRecord.self) { record in
                HistoryDetailView(record: record)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(records[index])
        }
        try? modelContext.save()
    }
}
