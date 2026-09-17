import SwiftUI

struct HistoryRow: View {
    let record: HistoryRecord

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: record.thumbnailURL)) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: record.mediaType == "text" ? "doc.text" : record.mediaType == "video" ? "video" : "photo").foregroundStyle(.blue)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text("\(Int((record.aiProbability * 100).rounded()))% AI 생성 가능성")
                    .font(.subheadline.weight(.semibold))
                Text(record.analyzedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
