import SwiftUI

/// The core result presentation, shared between the main app (Home/History)
/// and the Share Extension so both surfaces look identical.
struct ResultCard: View {
    let result: AIResultDisplayable

    private var percentText: String {
        "\(Int((result.displayProbability * 100).rounded()))%"
    }

    var body: some View {
        VStack(spacing: 12) {
            if result.displayProvider == "mock" {
                Text("개발용 예시 · 실제 AI 판별 결과가 아닙니다").font(.caption.bold()).foregroundStyle(.orange)
            }
            if !result.displayThumbnailURL.isEmpty {
            AsyncImage(url: URL(string: result.displayThumbnailURL)) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    Color.gray.opacity(0.15)
                }
            }
            .frame(height: 220)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            }
            Text("AI 생성 가능성")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(percentText)
                .font(.system(size: 48, weight: .bold, design: .rounded))
            Text(labelTitle(for: result.displayLabel))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(labelColor(for: result.displayLabel))
            Text("참고용 추정치예요. 결과의 정확도는 보장되지 않아요.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}
