import Foundation

/// Claude Code CLI 크리덴셜을 읽는 서비스
/// - 우선순위: ~/.claude/.credentials.json 파일 → macOS Keychain fallback
final class CredentialService {
    static let shared = CredentialService()

    enum CredentialError: LocalizedError {
        case notFound
        case invalidJSON
        case keychainFailed(status: Int32)
        case tokenExpired

        var errorDescription: String? {
            switch self {
            case .notFound:
                return "Claude Code 크리덴셜을 찾을 수 없습니다. Claude Code에 먼저 로그인하세요."
            case .invalidJSON:
                return "크리덴셜 JSON이 올바르지 않습니다."
            case .keychainFailed(let status):
                return "Keychain 접근 실패 (status: \(status))"
            case .tokenExpired:
                return "OAuth 토큰이 만료되었습니다. Claude Code에서 다시 로그인하세요."
            }
        }
    }

    private init() {}

    /// Claude Code 크리덴셜 읽기 (파일 우선, Keychain fallback)
    func readSystemCredentials() throws -> String {
        // 1차: ~/.claude/.credentials.json 파일에서 읽기 (Claude Code v2.x+)
        if let fileCredentials = readFileCredentials() {
            return fileCredentials
        }

        // 2차: macOS Keychain에서 읽기 (Claude Code v1.x 호환)
        return try readKeychainCredentials()
    }

    /// ~/.claude/.credentials.json 파일에서 크리덴셜 읽기
    private func readFileCredentials() -> String? {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let credentialPath = homeDir.appendingPathComponent(".claude/.credentials.json")

        guard FileManager.default.fileExists(atPath: credentialPath.path),
              let data = try? Data(contentsOf: credentialPath),
              let content = String(data: data, encoding: .utf8),
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return content
    }

    /// macOS Keychain에서 크리덴셜 읽기 (레거시 방식)
    private func readKeychainCredentials() throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = [
            "find-generic-password",
            "-s", "Claude Code-credentials",
            "-a", NSUserName(),
            "-w"
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let exitCode = process.terminationStatus

        if exitCode == 0 {
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            guard let value = String(data: outputData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else {
                throw CredentialError.invalidJSON
            }
            return value
        } else if exitCode == 44 {
            throw CredentialError.notFound
        } else {
            throw CredentialError.keychainFailed(status: exitCode)
        }
    }

    /// 크리덴셜 JSON에서 OAuth access token 추출
    func extractAccessToken(from jsonData: String) -> String? {
        guard let data = jsonData.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String else {
            return nil
        }
        return token
    }

    /// 토큰 만료 확인
    /// - Note: expiresAt은 밀리초(ms) 단위 (Claude Code v2.x+)
    func isTokenExpired(_ jsonData: String) -> Bool {
        guard let data = jsonData.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let expiresAt = oauth["expiresAt"] as? TimeInterval else {
            return false
        }
        // 밀리초 vs 초 자동 판별: 1e12 이상이면 밀리초로 간주
        let expiresAtSeconds = expiresAt > 1e12 ? expiresAt / 1000.0 : expiresAt
        return Date() > Date(timeIntervalSince1970: expiresAtSeconds)
    }

    /// 유효한 access token 가져오기 (Keychain 읽기 + 검증)
    func getAccessToken() throws -> String {
        let credentials = try readSystemCredentials()

        if isTokenExpired(credentials) {
            throw CredentialError.tokenExpired
        }

        guard let token = extractAccessToken(from: credentials) else {
            throw CredentialError.invalidJSON
        }

        return token
    }
}
