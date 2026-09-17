import SwiftUI

struct HistoryDetailView: View {
    let record: HistoryRecord

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ResultCard(result: record)
                Text("분석 API: \(record.provider)").font(.caption).foregroundStyle(.secondary)
                if !record.sourceURL.isEmpty, let url = URL(string: record.sourceURL) {
                    Link("원문 게시물 열기", destination: url)
                        .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .navigationTitle("판별 결과")
        .navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
    }
}
