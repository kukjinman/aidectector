import Foundation

struct AnalyzeSuccessResponse: Decodable {
    let status: String
    let aiProbability: Double
    let label: String
    let mediaType: String
    let thumbnailUrl: String
    let provider: String
    let analyzedAt: String
}

private struct AnalyzeErrorResponse: Decodable {
    let status: String
    let code: String
    let message: String
}

enum AIDetectorAPIError: Error, LocalizedError {
    case network(Error)
    case decoding(Error)
    case server(code: String, message: String)
    case unexpectedStatus(Int)

    var errorDescription: String? {
        switch self {
        case .network:
            return "네트워크에 연결할 수 없어요."
        case .decoding:
            return "서버 응답을 처리하지 못했어요."
        case .server(_, let message):
            return message
        case .unexpectedStatus(let code):
            return "알 수 없는 오류가 발생했어요. (\(code))"
        }
    }
}

enum AIDetectorAPI {
    static func request<T: Decodable>(_ path: String, body: [String: Any]? = nil, requestID: String? = nil, secret: String? = nil, authenticated: Bool = true) async throws -> T {
        var request = URLRequest(url: AppConfig.backendBaseURL.appendingPathComponent(path))
        request.httpMethod = body == nil ? "GET" : "POST"
        request.timeoutInterval = 120
        if AppConfig.engineeringEnabled, let key = AppConfig.engineeringKey {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        } else if authenticated { request.setValue("Bearer \(try secret ?? WalletIdentity.secret())", forHTTPHeaderField: "Authorization") }
        if let requestID { request.setValue(requestID, forHTTPHeaderField: "Idempotency-Key") }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let data: Data
        let response: URLResponse
        do { (data, response) = try await URLSession.shared.data(for: request) }
        catch { throw AIDetectorAPIError.network(error) }
        guard let http = response as? HTTPURLResponse else { throw AIDetectorAPIError.unexpectedStatus(-1) }
        guard (200...299).contains(http.statusCode) else {
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            throw AIDetectorAPIError.server(code: json?["code"] as? String ?? "HTTP_\(http.statusCode)", message: json?["message"] as? String ?? "요청을 처리하지 못했습니다.")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
    /// Public, non-billable endpoints only. Does not read or transmit a wallet key.
    static func checkConnection() async throws -> ServerConnectionReport {
        var healthRequest = URLRequest(url: AppConfig.backendBaseURL.appendingPathComponent("healthz"))
        if AppConfig.engineeringEnabled { healthRequest.setValue("Bearer \(AppConfig.engineeringKey!)", forHTTPHeaderField: "Authorization") }
        healthRequest.timeoutInterval = 15
        let (healthData, healthResponse) = try await URLSession.shared.data(for: healthRequest)
        guard let healthHTTP = healthResponse as? HTTPURLResponse, healthHTTP.statusCode == 200,
              let health = try JSONSerialization.jsonObject(with: healthData) as? [String: Any], health["status"] as? String == "ok" else {
            throw AIDetectorAPIError.server(code: "HEALTH_FAILED", message: "서버 상태를 확인하지 못했습니다. 서버 주소를 확인해 주세요.")
        }
        var configRequest = URLRequest(url: AppConfig.backendBaseURL.appendingPathComponent("v1/config"))
        if AppConfig.engineeringEnabled { configRequest.setValue("Bearer \(AppConfig.engineeringKey!)", forHTTPHeaderField: "Authorization") }
        configRequest.timeoutInterval = 15
        let (configData, configResponse) = try await URLSession.shared.data(for: configRequest)
        guard let configHTTP = configResponse as? HTTPURLResponse else { throw AIDetectorAPIError.unexpectedStatus(-1) }
        if configHTTP.statusCode == 404 { return ServerConnectionReport(healthStatus: 200, configurationStatus: 404) }
        guard configHTTP.statusCode == 200,
              let config = try JSONSerialization.jsonObject(with: configData) as? [String: Any],
              config["billingEnabled"] is Bool, config["demo"] is Bool, config["textAvailable"] is Bool else {
            throw AIDetectorAPIError.server(code: "CONFIG_FAILED", message: "서버에는 연결됐지만 앱 설정 응답을 확인하지 못했습니다.")
        }
        return ServerConnectionReport(healthStatus: 200, configurationStatus: 200)
    }
    static func analyze(url: String) async throws -> AnalyzeSuccessResponse {
        try await analyze(body: ["url": url], requestID: UUID().uuidString)
    }
    static func analyze(body: [String: Any], requestID: String) async throws -> AnalyzeSuccessResponse {
        var input = body
        input["consent"] = true
        // A transport retry reuses the same key so a completed request isn't charged twice.
        do { return try await request("v1/analyze", body: input, requestID: requestID) }
        catch AIDetectorAPIError.network {
            return try await request("v1/analyze", body: input, requestID: requestID)
        }
    }
}

struct ServerConnectionReport {
    let healthStatus: Int
    let configurationStatus: Int
    var supportsCurrentApp: Bool { configurationStatus == 200 }
    var message: String {
        supportsCurrentApp ? "서버 연결 성공 · 새 앱 API 확인 완료" : "서버 연결 성공 · 백엔드 업데이트 필요"
    }
}
