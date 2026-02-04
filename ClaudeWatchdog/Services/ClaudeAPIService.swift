import Foundation

/// Claude API에서 사용량 데이터를 가져오는 서비스
final class ClaudeAPIService {
    static let shared = ClaudeAPIService()

    enum APIError: LocalizedError {
        case noCredentials
        case unauthorized
        case rateLimited
        case serverError(Int)
        case networkError(Error)
        case parseFailed

        var errorDescription: String? {
            switch self {
            case .noCredentials:
                return "인증 정보가 없습니다."
            case .unauthorized:
                return "인증이 만료되었습니다. Claude Code에서 다시 로그인하세요."
            case .rateLimited:
                return "API 요청 제한에 도달했습니다."
            case .serverError(let code):
                return "서버 오류 (HTTP \(code))"
            case .networkError(let error):
                return "네트워크 오류: \(error.localizedDescription)"
            case .parseFailed:
                return "응답 파싱 실패"
            }
        }
    }

    private init() {}

    /// OAuth 엔드포인트로 사용량 데이터 가져오기
    func fetchUsage() async throws -> ClaudeUsage {
        let token = try CredentialService.shared.getAccessToken()

        guard let url = URL(string: "https://api.anthropic.com/api/oauth/usage") else {
            throw APIError.parseFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("claude-code/2.1.5", forHTTPHeaderField: "User-Agent")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.timeoutInterval = 30

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.parseFailed
        }

        switch httpResponse.statusCode {
        case 200:
            return try parseUsageResponse(data)
        case 401, 403:
            throw APIError.unauthorized
        case 429:
            throw APIError.rateLimited
        case 500...599:
            throw APIError.serverError(httpResponse.statusCode)
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }
    }

    // MARK: - Response Parsing

    private func parseUsageResponse(_ data: Data) throws -> ClaudeUsage {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.parseFailed
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // 5시간 세션 사용량
        var sessionPercentage = 0.0
        var sessionResetTime = Date().addingTimeInterval(5 * 3600)
        if let fiveHour = json["five_hour"] as? [String: Any] {
            sessionPercentage = parseUtilization(fiveHour["utilization"])
            if let resetsAt = fiveHour["resets_at"] as? String {
                sessionResetTime = isoFormatter.date(from: resetsAt) ?? sessionResetTime
            }
        }

        // 주간 사용량
        var weeklyPercentage = 0.0
        var weeklyResetTime = Date().addingTimeInterval(7 * 24 * 3600)
        if let sevenDay = json["seven_day"] as? [String: Any] {
            weeklyPercentage = parseUtilization(sevenDay["utilization"])
            if let resetsAt = sevenDay["resets_at"] as? String {
                weeklyResetTime = isoFormatter.date(from: resetsAt) ?? weeklyResetTime
            }
        }

        // Opus 주간 사용량
        var opusPercentage = 0.0
        if let opus = json["seven_day_opus"] as? [String: Any] {
            opusPercentage = parseUtilization(opus["utilization"])
        }

        // Sonnet 주간 사용량
        var sonnetPercentage = 0.0
        if let sonnet = json["seven_day_sonnet"] as? [String: Any] {
            sonnetPercentage = parseUtilization(sonnet["utilization"])
        }

        return ClaudeUsage(
            sessionPercentage: sessionPercentage,
            sessionResetTime: sessionResetTime,
            weeklyPercentage: weeklyPercentage,
            weeklyResetTime: weeklyResetTime,
            opusWeeklyPercentage: opusPercentage,
            sonnetWeeklyPercentage: sonnetPercentage,
            lastUpdated: Date()
        )
    }

    private func parseUtilization(_ value: Any?) -> Double {
        guard let value = value else { return 0.0 }

        if let intValue = value as? Int { return Double(intValue) }
        if let doubleValue = value as? Double { return doubleValue }
        if let stringValue = value as? String {
            return Double(stringValue.replacingOccurrences(of: "%", with: "")) ?? 0.0
        }
        return 0.0
    }
}
