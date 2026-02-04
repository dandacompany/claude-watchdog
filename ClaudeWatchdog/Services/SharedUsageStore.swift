import Foundation

/// 메인 앱과 위젯이 공유하는 사용량 데이터 저장소
/// App Groups 컨테이너를 통해 데이터를 공유합니다.
final class SharedUsageStore {
    static let shared = SharedUsageStore()

    private static let appGroupID = "YXPA46F4SJ.com.dante-labs.ClaudeWatchdog"
    private let fileURL: URL

    private init() {
        if let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroupID
        ) {
            let dir = containerURL.appendingPathComponent("Library/Application Support")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            fileURL = dir.appendingPathComponent("shared-usage.json")
        } else {
            // App Group 미지원 시 폴백
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = appSupport.appendingPathComponent("ClaudeWatchdog")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            fileURL = dir.appendingPathComponent("shared-usage.json")
        }
    }

    func save(_ usage: ClaudeUsage) {
        if let data = try? JSONEncoder().encode(usage) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    func load() -> ClaudeUsage? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(ClaudeUsage.self, from: data)
    }
}
