import SwiftUI
import StoreKit

struct CreditShopView: View {
    @EnvironmentObject private var store: CreditStore
    @State private var accepted = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Image(systemName: "plus.circle.fill").font(.system(size: 40)).foregroundStyle(.blue)
                Text("필요한 만큼만,\n합리적인 AI 분석").font(.largeTitle.bold())
                Text("6회 · 20회 · 50회 횟수권으로 가볍게 시작하세요.")
                    .foregroundStyle(.secondary)
                Label("남은 분석 \(store.wallet?.balance ?? 0)회", systemImage: "sparkles").font(.title3.bold())
                Text("외부 AI 탐지 API를 사용합니다. 분석 성공 시 1회 차감되며, 실패 시 돌려드립니다. 미사용 횟수는 만료되지 않습니다.").font(.subheadline).foregroundStyle(.secondary)
                if store.configuration?.billingEnabled == true { Toggle("이용약관을 확인하고 구매에 동의합니다.",isOn:$accepted)
                    Link("이용약관",destination:AppConfig.legalURL("terms")) }
                ForEach(store.products, id: \.id) { product in
                    let count = store.wallet?.products[product.id] ?? 0
                    Button { Task { await store.purchase(product) } } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("\(count)회 분석").font(.title2.bold())
                                if count > 0 {
                                    Text("회당 \((product.price / Decimal(count)).formatted(product.priceFormatStyle))").font(.caption)
                                }
                            }
                            Spacer()
                            Text(product.displayPrice).font(.headline)
                        }.glassCard(.blue)
                    }.buttonStyle(.plain).disabled(store.busy || !accepted)
                }
                if store.products.isEmpty {
                    Text(store.configuration?.billingEnabled == false ? "테스트 모드에서는 구매가 비활성화됩니다. 지급된 분석 횟수를 사용해 주세요." : store.configuration?.demo == true ? "개발용 데모입니다. 실제 판별이나 결제가 진행되지 않습니다." : "판매 상품을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.")
                        .font(.callout).glassCard()
                    Button("다시 불러오기") { Task { await store.refresh() } }
                }
                if store.busy { ProgressView("구매 처리 중…") }
                if let message = store.message { Text(message).font(.footnote).foregroundStyle(.secondary) }
                if store.configuration?.billingEnabled == true { Button("미지급 구매 확인") { Task { await store.recoverPurchases() } }.disabled(store.busy) }
                Text("소모성 횟수권입니다. 기기를 바꾸기 전에 설정에서 복구키를 보관해 주세요. Apple 구매 복원만으로 사용한 소모성 구매가 복원되지는 않습니다.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(22)
        }.background(AppBackground()).navigationTitle("횟수권 충전").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
        .task { await store.refresh() }
    }
}
