import Foundation
import UserNotifications

/// 사용량 임계값 도달 시 macOS 알림 전송
final class NotificationService {
    static let shared = NotificationService()

    private var sentAlerts: Set<Int> = []
    private let thresholds = [75, 90, 95]

    private init() {}

    /// 사용량 확인 후 필요시 알림 전송
    func checkAndNotify(usage: ClaudeUsage) {
        let settings = AppSettings.shared
        let percentage = Int(usage.sessionPercentage)

        for threshold in thresholds {
            guard !sentAlerts.contains(threshold) else { continue }
            guard percentage >= threshold else { continue }

            let shouldAlert: Bool
            switch threshold {
            case 75: shouldAlert = settings.alertAt75
            case 90: shouldAlert = settings.alertAt90
            case 95: shouldAlert = settings.alertAt95
            default: shouldAlert = false
            }

            if shouldAlert {
                sendAlert(percentage: percentage, threshold: threshold)
                sentAlerts.insert(threshold)
            }
        }
    }

    /// 세션 리셋 감지 시 알림 상태 초기화
    func resetAlerts() {
        sentAlerts.removeAll()
    }

    private func sendAlert(percentage: Int, threshold: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Claude 사용량 경고"

        switch threshold {
        case 75:
            content.body = "세션 사용량 \(percentage)% — 75% 임계값을 초과했습니다."
            content.sound = .default
        case 90:
            content.body = "세션 사용량 \(percentage)% — 한도에 가까워지고 있습니다!"
            content.sound = .default
        case 95:
            content.body = "세션 사용량 \(percentage)% — 거의 한도에 도달했습니다!"
            content.sound = .defaultCritical
        default:
            return
        }

        let request = UNNotificationRequest(
            identifier: "usage-alert-\(threshold)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
