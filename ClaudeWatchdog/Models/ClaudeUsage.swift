import Foundation

/// Claude API 사용량 데이터 모델
struct ClaudeUsage: Codable, Equatable {
    // 5시간 롤링 윈도우 세션
    var sessionPercentage: Double
    var sessionResetTime: Date

    // 주간 사용량 (전체 모델)
    var weeklyPercentage: Double
    var weeklyResetTime: Date

    // 주간 사용량 (Opus)
    var opusWeeklyPercentage: Double

    // 주간 사용량 (Sonnet)
    var sonnetWeeklyPercentage: Double

    // 메타데이터
    var lastUpdated: Date

    static var empty: ClaudeUsage {
        ClaudeUsage(
            sessionPercentage: 0,
            sessionResetTime: Date().addingTimeInterval(5 * 3600),
            weeklyPercentage: 0,
            weeklyResetTime: Date().addingTimeInterval(7 * 24 * 3600),
            opusWeeklyPercentage: 0,
            sonnetWeeklyPercentage: 0,
            lastUpdated: Date()
        )
    }
}
