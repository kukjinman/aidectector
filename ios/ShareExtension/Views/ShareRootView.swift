import SwiftUI

struct ShareRootView: View {
    @ObservedObject var viewModel: ShareFlowViewModel

    @State private var accepted = false

    var body: some View {
        VStack(spacing: 16) {
            switch viewModel.state {
            case .missingURL:
                Text("인스타그램 게시물 링크를 찾지 못했어요.")
                    .multilineTextAlignment(.center)
                Button("닫기") { viewModel.close() }
                    .buttonStyle(.bordered)

            case .ready:
                Text("이 게시물을 AI 판별기로 분석할까요?")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text("Instagram 미리보기 이미지를 서버에 설정된 외부 이미지 탐지 API로 전송하며, 성공 시 1회를 사용합니다. 영상 전체 분석은 앱에서 파일을 선택해 주세요.").font(.footnote)
                Toggle("만 14세 이상이며 약관 및 외부 전송에 동의합니다", isOn: $accepted).font(.footnote)
                HStack { Link("개인정보처리방침", destination: AppConfig.legalURL("privacy")); Link("이용약관", destination: AppConfig.legalURL("terms")) }.font(.caption)
                Button("판별하기 · 1회 사용") { viewModel.startAnalysis() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!accepted)
                Button("취소") { viewModel.close() }

            case .analyzing:
                ProgressView("분석 중...")

            case .success(let response):
                ResultCard(result: response)
                Button("닫기") { viewModel.close() }
                    .buttonStyle(.borderedProminent)

            case .failure(let message):
                Text(message)
                    .multilineTextAlignment(.center)
                Button("닫기") { viewModel.close() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}
