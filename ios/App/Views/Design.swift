import SwiftUI

struct AppBackground: View {
    var body: some View { Color(uiColor: .systemGroupedBackground).ignoresSafeArea() }
}
extension View {
    func glassCard(_ color: Color = .white) -> some View {
        self.padding(20).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.primary.opacity(0.08), lineWidth: 1))
    }
}
enum AnalysisConsent {
    // Bump this version whenever the disclosed purpose/data/terms change.
    static func signature(_ config: ServiceConfiguration?) -> String {
        guard let config else { return "" }
        return "v2|" + AppConfig.backendBaseURL.absoluteString + "|" + (config.mediaProvider ?? "unknown") + "|GPTZero|" + String(config.demo)
    }
}
struct APIConsentView: View {
    @EnvironmentObject private var store: CreditStore
    @Binding var accepted: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if accepted {
                Label("외부 AI 전송 동의 완료", systemImage: "checkmark.shield.fill").font(.subheadline.bold())
                Text("동의를 기억했습니다. 설정에서 언제든 철회할 수 있습니다.").font(.caption).foregroundStyle(.secondary)
            } else {
                Text("분석 전 한 번만 확인해 주세요").font(.headline)
                Text("AI 생성 가능성을 분석하기 위해 선택한 자료를 아래 업체로 전송합니다. 동의는 이 기기에 저장됩니다.").font(.subheadline)
            }
            if store.configuration?.demo == true {
                Text("개발용 데모 결과이며 외부 AI API로 자료를 전송하지 않습니다.").font(.caption).foregroundStyle(.secondary)
            } else {
            Text("텍스트는 GPTZero, 이미지는 \(store.configuration?.mediaProviderName ?? "설정된 외부 탐지 API")으로 전송됩니다. URL 분석은 Instagram 미리보기 이미지만 사용합니다. 개인정보가 포함된 자료는 제출하지 마세요.")
                .font(.caption).foregroundStyle(.secondary)
            }
            if !accepted {
                Toggle("만 14세 이상이며 이용약관과 위 외부 AI 전송에 동의합니다.", isOn: $accepted).font(.subheadline)
            }
            HStack {
                Link("개인정보처리방침", destination: AppConfig.legalURL("privacy"))
                Link("이용약관", destination: AppConfig.legalURL("terms"))
            }.font(.caption)
        }.glassCard()
    }
}
