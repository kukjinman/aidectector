import Foundation
import StoreKit

struct WalletResponse: Decodable { let id: String; let balance: Int; let billingEnabled: Bool; let products: [String: Int] }
struct ServiceConfiguration: Decodable { let billingEnabled: Bool; let demo: Bool; let textAvailable: Bool; let mediaProvider: String?; let videoAvailable: Bool?
    var mediaProviderName: String { mediaProvider == "illuminarty" ? "Illuminarty" : mediaProvider == "mock" ? "개발용 데모 (외부 전송 없음)" : "Sightengine" }
}
@MainActor
final class CreditStore: ObservableObject {
    @Published var wallet: WalletResponse?
    @Published var products: [Product] = []
    @Published var configuration: ServiceConfiguration?
    @Published var connectionMessage: String?
    @Published var checkingConnection = false
    @Published var busy = false
    @Published var message: String?
    private var listener: Task<Void, Never>?
    init() {
        listener = Task { [weak self] in
            for await result in Transaction.updates {
                do { try await self?.deliver(result) }
                catch { self?.message = "구매 지급을 완료하지 못했습니다. 구매 확인을 다시 눌러 주세요. " + error.localizedDescription }
            }
        }
    }
    deinit { listener?.cancel() }
    func refresh() async {
        do {
            message = nil
            connectionMessage = nil
            configuration = try await AIDetectorAPI.request("v1/config", authenticated: false)
            wallet = try await AIDetectorAPI.request("v1/wallet")
            if let wallet, wallet.billingEnabled {
                products = try await Product.products(for: Array(wallet.products.keys)).sorted { $0.price < $1.price }
            } else { products = [] }
        } catch {
            configuration = nil
            wallet = nil
            products = []
            if case AIDetectorAPIError.server(let code, _) = error, code == "HTTP_404" {
                message = "현재 서버는 구버전입니다. 새 백엔드 전환 후 분석과 횟수권을 이용할 수 있습니다."
                await checkConnection()
            } else { message = error.localizedDescription }
        }
    }
    func checkConnection() async {
        guard !checkingConnection else { return }
        checkingConnection = true
        defer { checkingConnection = false }
        do { connectionMessage = try await AIDetectorAPI.checkConnection().message }
        catch { connectionMessage = "서버 연결 확인 실패: " + error.localizedDescription }
    }
    func purchase(_ product: Product) async {
        guard !busy, let id = wallet?.id, let token = UUID(uuidString: id) else { return }
        busy = true
        message = nil
        defer { busy = false }
        do {
            switch try await product.purchase(options: [.appAccountToken(token)]) {
            case .success(let result): try await deliver(result); message = "횟수권이 충전되었습니다."
            case .pending: message = "구매 승인 대기 중입니다. 승인 후 자동으로 충전됩니다."
            case .userCancelled: break
            @unknown default: break
            }
        } catch { message = error.localizedDescription }
    }
    private func deliver(_ result: VerificationResult<Transaction>) async throws {
        guard case .verified(let transaction) = result else {
            throw NSError(domain: "Store", code: 1, userInfo: [NSLocalizedDescriptionKey: "구매 서명을 확인하지 못했습니다."])
        }
        struct Redeemed: Decodable { let balance: Int }
        let _: Redeemed = try await AIDetectorAPI.request("v1/purchases", body: ["signedTransaction": result.jwsRepresentation])
        await transaction.finish()
        await refresh()
    }
    func resumeUnfinished() async {
        for await result in Transaction.unfinished {
            do { try await deliver(result) }
            catch { message = "미지급 구매를 확인해 주세요. " + error.localizedDescription }
        }
    }
    func recoverPurchases() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            try await AppStore.sync()
            for await result in Transaction.unfinished { try await deliver(result) }
            await refresh()
            message = "미지급 구매 확인을 마쳤습니다. 이전 지갑 잔액은 복구키로 연결해 주세요."
        } catch { message = error.localizedDescription }
    }
    func restoreWallet(_ key: String) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            let clean = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard clean.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil else { throw NSError(domain:"Wallet",code:1,userInfo:[NSLocalizedDescriptionKey:"복구키는 64자리 영문·숫자입니다."]) }
            let restored: WalletResponse = try await AIDetectorAPI.request("v1/wallet", secret: clean)
            try WalletIdentity.save(clean)
            wallet = restored
            await refresh()
            message = "지갑을 연결했습니다."
        } catch { message = error.localizedDescription }
    }
}
