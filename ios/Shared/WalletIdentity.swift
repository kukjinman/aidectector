import Foundation
import Security

enum WalletIdentity {
    private static var query: [String: Any] {
        var value: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: "com.kukjinman.aidetector.wallet",
                                   kSecAttrAccount as String: "recovery-key"]
        if let group = Bundle.main.object(forInfoDictionaryKey: "WalletKeychainGroup") as? String, !group.contains("$(") {
            value[kSecAttrAccessGroup as String] = group
        }
        return value
    }
    static func secret() throws -> String {
        var lookup = query
        lookup[kSecReturnData as String] = true
        var value: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &value)
        if status == errSecSuccess, let data = value as? Data, let secret = String(data: data, encoding: .utf8) { return secret }
        guard status == errSecItemNotFound else { throw identityError }
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw identityError }
        let secret = bytes.map { String(format: "%02x", $0) }.joined()
        try save(secret)
        return secret
    }
    static func save(_ secret: String) throws {
        guard secret.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil else { throw identityError }
        let attributes: [String: Any] = [kSecValueData as String: Data(secret.utf8), kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            attributes.forEach { insert[$0.key] = $0.value }
            guard SecItemAdd(insert as CFDictionary, nil) == errSecSuccess else { throw identityError }
        } else if status != errSecSuccess { throw identityError }
    }
    private static var identityError: NSError { NSError(domain: "Wallet", code: 1, userInfo: [NSLocalizedDescriptionKey: "지갑 키를 읽거나 저장할 수 없습니다. 기기 잠금과 앱 설정을 확인해 주세요."]) }
}
