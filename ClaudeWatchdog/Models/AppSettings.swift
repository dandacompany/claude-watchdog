import Foundation
import ServiceManagement

/// 앱 설정 (UserDefaults 저장)
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    enum IconStyle: String, CaseIterable, Codable {
        case percentage = "percentage"
        case progressBar = "progressBar"
        case battery = "battery"
    }

    @Published var iconStyle: IconStyle {
        didSet { defaults.set(iconStyle.rawValue, forKey: "iconStyle") }
    }

    @Published var refreshInterval: TimeInterval {
        didSet { defaults.set(refreshInterval, forKey: "refreshInterval") }
    }

    @Published var alertAt75: Bool {
        didSet { defaults.set(alertAt75, forKey: "alertAt75") }
    }

    @Published var alertAt90: Bool {
        didSet { defaults.set(alertAt90, forKey: "alertAt90") }
    }

    @Published var alertAt95: Bool {
        didSet { defaults.set(alertAt95, forKey: "alertAt95") }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // 실패 시 이전 상태로 복원
                launchAtLogin = !launchAtLogin
            }
        }
    }

    private init() {
        let style = defaults.string(forKey: "iconStyle") ?? IconStyle.percentage.rawValue
        self.iconStyle = IconStyle(rawValue: style) ?? .percentage

        let interval = defaults.double(forKey: "refreshInterval")
        self.refreshInterval = interval > 0 ? interval : 30.0

        self.alertAt75 = defaults.object(forKey: "alertAt75") as? Bool ?? true
        self.alertAt90 = defaults.object(forKey: "alertAt90") as? Bool ?? true
        self.alertAt95 = defaults.object(forKey: "alertAt95") as? Bool ?? true

        self.launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
