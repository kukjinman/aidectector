import SwiftUI
import SwiftData

struct HomeView: View {
    @EnvironmentObject private var store: CreditStore
    @Query(sort: \HistoryRecord.analyzedAt, order: .reverse) private var records: [HistoryRecord]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack {
                        Label("ORIGIN", systemImage: "viewfinder").font(.headline.monospaced()).tracking(3)
                        Spacer()
                        NavigationLink { SettingsView() } label: { Image(systemName: "gearshape").font(.title3).padding(12) }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("AI의 흔적을\n확인하는 공간").font(.system(size: 34, weight: .bold))
                        Text("사진 · 링크 · 텍스트를 한곳에서 분석하세요.").font(.subheadline).foregroundStyle(.secondary)
                    }
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(AppConfig.engineeringEnabled ? "테스트 분석 잔액" : "분석 잔액").font(.caption.monospaced()).foregroundStyle(.secondary)
                            Text(store.wallet.map { "\($0.balance)회" } ?? "연결 확인 중").font(.title2.bold())
                        }
                        Spacer()
                        if !AppConfig.engineeringEnabled { NavigationLink("충전") { CreditShopView() }.buttonStyle(.bordered) }
                        else { Image(systemName: "wrench.and.screwdriver").foregroundStyle(.orange) }
                    }.padding(20).background(Color(uiColor: .secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:16))
                    if let status = store.connectionMessage { Text(status).font(.caption).foregroundStyle(.secondary) }
                    Text("무엇을 분석할까요?").font(.title2.bold())
                    NavigationLink { AnalysisView(mode: .media) } label: {
                        VStack(alignment:.leading,spacing:22) {
                            HStack { Image(systemName:"viewfinder").font(.largeTitle); Spacer(); Image(systemName:"arrow.up.right") }
                            Text("사진 분석").font(.title.bold())
                            Text("사진을 선택하면 AI 생성 가능성을 확인합니다").font(.subheadline).opacity(0.8)
                        }.foregroundStyle(.white).padding(24).frame(maxWidth:.infinity,alignment:.leading)
                            .background(Color(red:0.12,green:0.25,blue:0.78),in:RoundedRectangle(cornerRadius:20))
                    }.buttonStyle(.plain)
                    VStack(spacing:12) {
                        NavigationLink { AnalysisView(mode:.url) } label: { toolRow("링크 분석", "Instagram 공개 미리보기", "link") }
                        NavigationLink { AnalysisView(mode:.text) } label: { toolRow("텍스트 분석", store.configuration?.textAvailable == false ? "API 연결 준비 중" : "글의 생성 가능성 분석", "text.alignleft") }
                    }.buttonStyle(.plain)
                    HStack { Text("최근 검사").font(.headline); Spacer(); NavigationLink("전체 기록") { HistoryView() }.font(.subheadline) }
                    if records.isEmpty {
                        Label("첫 분석이 끝나면 여기에 기록됩니다.",systemImage:"clock").font(.subheadline).foregroundStyle(.secondary).padding(.vertical,20)
                    } else {
                        ForEach(records.prefix(3)) { record in
                            NavigationLink { HistoryDetailView(record:record) } label: { HistoryRow(record:record) }.buttonStyle(.plain)
                        }
                    }
                    Text(AppConfig.engineeringEnabled ? "테스트 모드 · 실제 외부 API 사용 · 성공 시 1회 차감" : "외부 AI 탐지 API 기반 · 결과는 참고용 추정치입니다.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(24)
            }.background(Color(uiColor:.systemGroupedBackground)).toolbar(.hidden,for:.navigationBar)
                .task { await store.refresh() }
        }.tint(Color(red:0.12,green:0.25,blue:0.78))
    }
    private func toolRow(_ title:String,_ subtitle:String,_ icon:String) -> some View {
        HStack(spacing:16) {
            Image(systemName:icon).font(.title3).frame(width:28)
            VStack(alignment:.leading,spacing:5) { Text(title).font(.headline); Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            Spacer(); Image(systemName:"chevron.right").font(.caption)
        }.foregroundStyle(.primary).padding(20).background(Color(uiColor:.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:20))
    }
}
