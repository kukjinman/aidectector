import SwiftUI
import StoreKit

struct SettingsView: View {
    @EnvironmentObject private var store: CreditStore
    @Environment(\.requestReview) private var requestReview
    @AppStorage("analysisConsentSignature") private var consentSignature = ""
    @State private var engineering = AppConfig.engineeringEnabled
    @State private var backendURLText = AppConfig.backendBaseURL.absoluteString
    @State private var feedback: String?
    @State private var recoveryKey = ""
    @State private var importKey = ""
    @State private var showingRestore = false
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:20) {
                VStack(alignment:.leading,spacing:22) {
                    Image(systemName:"viewfinder").font(.largeTitle).foregroundStyle(.white).padding(16).background(.white.opacity(0.2),in:Circle())
                    HStack {
                        Text("ORIGIN").font(.largeTitle.bold())
                        Spacer()
                        NavigationLink("충전하기") { CreditShopView() }.buttonStyle(.borderedProminent).tint(.indigo)
                    }
                    Text("필요한 만큼 구매 · 남은 \(store.wallet?.balance ?? 0)회").foregroundStyle(.secondary)
                }.frame(maxWidth:.infinity,alignment:.leading).padding(22)
.background(Color(uiColor:.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:20))
                VStack(alignment: .leading, spacing: 10) {
                    Label("서버 연결", systemImage: "network").font(.headline)
                    if let status = store.connectionMessage { Text(status).font(.footnote).foregroundStyle(.secondary) }
                    Button(store.checkingConnection ? "확인 중…" : "서버 연결 확인") {
                        Task { await store.checkConnection() }
                    }.disabled(store.checkingConnection)
                }.glassCard()
                Text("일반").font(.headline).foregroundStyle(.secondary)
                VStack(spacing:0) {
                    Button { Task { await store.recoverPurchases() } } label: { row("미지급 구매 확인", "arrow.counterclockwise") }.disabled(store.busy)
                    Divider()
                    Button { requestReview() } label: { row("평가하기", "hand.thumbsup") }
                    Divider()
                    ShareLink(item:AppConfig.website) { row("앱 공유", "square.and.arrow.up") }
                    Divider()
                    Link(destination:AppConfig.legalURL("support")) { row("문의하기", "envelope") }
                }.glassCard().buttonStyle(.plain)
                Text("지갑 복구").font(.headline).foregroundStyle(.secondary)
                VStack(alignment:.leading,spacing:14) {
                    Text("재설치·기기 변경 전에 복구키를 안전하게 보관하세요. 이 키를 아는 사람은 횟수를 사용할 수 있습니다.").font(.footnote).foregroundStyle(.secondary)
                    if let id = store.wallet?.id { Text("지갑 ID: \(id)").font(.caption).textSelection(.enabled) }
                    Button("내 복구키 보기") {
                        do { recoveryKey = try WalletIdentity.secret() } catch { feedback = error.localizedDescription }
                    }
                    if !recoveryKey.isEmpty { Text(recoveryKey).font(.caption.monospaced()).textSelection(.enabled) }
                    SecureField("기존 지갑 복구키 입력",text:$importKey).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder)
                    Button("기존 지갑 연결") { showingRestore = true }.disabled(importKey.isEmpty || store.busy)
                    Text("연결 전 현재 복구키를 보관하세요. 두 지갑의 잔액은 합쳐지지 않습니다.").font(.caption).foregroundStyle(.secondary)
                }.glassCard()
                VStack(alignment:.leading,spacing:12) {
                    Label("분석 데이터 전송 동의",systemImage:"hand.raised").font(.headline)
                    Text(consentSignature.isEmpty ? "다음 분석 전에 동의를 받습니다." : "이 기기에 동의가 저장되어 있습니다.").font(.subheadline)
                    Button("동의 철회",role:.destructive) { consentSignature = "" }.disabled(consentSignature.isEmpty)
                }.glassCard()
                Text("개인정보 보호").font(.headline).foregroundStyle(.secondary)
                VStack(spacing:0) {
                    Link(destination:AppConfig.legalURL("privacy")) { row("개인정보처리방침", "shield.lefthalf.filled") }
                    Divider()
                    Link(destination:AppConfig.legalURL("terms")) { row("이용약관", "doc.text") }
                }.glassCard().foregroundStyle(.primary)
                Text("외부 AI 탐지 API를 합리적인 횟수권으로 제공합니다. 결과는 참고용 추정치입니다.").font(.footnote).foregroundStyle(.secondary)
                if let message = store.message { Text(message).font(.footnote).foregroundStyle(.secondary) }
                if let feedback { Text(feedback).font(.footnote) }
                #if DEBUG
                if AppConfig.engineeringKey != nil {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("엔지니어링 모드", isOn: $engineering)
                            .onChange(of: engineering) { _, value in
                                AppConfig.sharedDefaults.set(value, forKey: "engineeringEnabled")
                                Task { await store.refresh(); await store.checkConnection() }
                            }
                        Text("별도 테스트 지갑 · 최초 20회. 실제 Illuminarty API 비용이 발생합니다. 운영 구매 잔액과 분리됩니다.").font(.caption).foregroundStyle(.secondary)
                    }.glassCard()
                }
                VStack(alignment:.leading,spacing:10) {
                    Text("개발용 서버 설정").font(.caption)
                    TextField("http://localhost:8787",text:$backendURLText).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder)
                    Button("서버 주소 저장") {
                        guard let url = URL(string:backendURLText.trimmingCharacters(in:.whitespacesAndNewlines)), ["http","https"].contains(url.scheme ?? ""), url.host != nil else { feedback = "올바른 서버 주소를 입력해 주세요."; return }
                        AppConfig.backendBaseURL = url
                        Task { await store.refresh() }
                        feedback = "저장되었습니다."
                    }
                }.glassCard()
                #endif
                Text("버전 \(Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "1.0")").font(.caption).foregroundStyle(.secondary)
            }.padding(20)
        }.background(AppBackground()).navigationTitle("설정").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
            .confirmationDialog("현재 지갑 복구키를 보관했나요? 기존 지갑으로 전환합니다.",isPresented:$showingRestore,titleVisibility:.visible) {
                Button("지갑 전환") { Task { await store.restoreWallet(importKey); importKey = ""; recoveryKey = "" } }
            }
    }
    private func row(_ title:String,_ icon:String) -> some View {
        HStack(spacing:16) { Image(systemName:icon).font(.title2).frame(width:28); Text(title).font(.headline); Spacer(); Image(systemName:"arrow.right").foregroundStyle(.secondary) }.padding(.vertical,18).contentShape(Rectangle())
    }
}
