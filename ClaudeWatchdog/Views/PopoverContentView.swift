import SwiftUI

struct PopoverContentView: View {
    @ObservedObject var manager: MenuBarManager
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()

            if manager.credentialStatus != .valid {
                credentialErrorSection
            } else {
                usageSection
                Divider()
                settingsSection
            }

            Divider()
            footerSection
        }
        .frame(width: 300)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Text("Claude Watchdog")
                .font(.headline)

            Spacer()

            if manager.isLoading {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 16, height: 16)
            } else {
                Button(action: { manager.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .help("새로고침")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Credential Error

    private var credentialErrorSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(.orange)

            Text(credentialMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("다시 확인") {
                manager.checkCredentials()
                if manager.credentialStatus == .valid {
                    manager.refresh()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(20)
    }

    private var credentialMessage: String {
        switch manager.credentialStatus {
        case .notFound:
            return "Claude Code가 설정되지 않았습니다.\n터미널에서 'claude' 명령으로 로그인하세요."
        case .expired:
            return "OAuth 토큰이 만료되었습니다.\nClaude Code에서 다시 로그인하세요."
        case .error(let msg):
            return msg
        default:
            return "알 수 없는 오류"
        }
    }

    // MARK: - Usage Section

    private var usageSection: some View {
        VStack(spacing: 12) {
            // 세션 사용량 (메인)
            usageBar(
                label: "세션 (5시간)",
                percentage: manager.usage.sessionPercentage,
                resetTime: manager.usage.sessionResetTime
            )

            // 주간 사용량
            usageBar(
                label: "주간",
                percentage: manager.usage.weeklyPercentage,
                resetTime: manager.usage.weeklyResetTime
            )

            // 모델별 사용량 (간략)
            HStack(spacing: 16) {
                modelBadge(name: "Opus", percentage: manager.usage.opusWeeklyPercentage)
                modelBadge(name: "Sonnet", percentage: manager.usage.sonnetWeeklyPercentage)
                Spacer()
            }

            if let error = manager.error {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .lineLimit(2)
            }

            // 마지막 업데이트
            Text("업데이트: \(formatDate(manager.usage.lastUpdated))")
                .font(.caption2)
                .foregroundColor(Color(nsColor: .quaternaryLabelColor))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func usageBar(label: String, percentage: Double, resetTime: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(percentage))%")
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(usageColor(percentage))
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(usageColor(percentage))
                        .frame(width: geometry.size.width * CGFloat(percentage / 100.0), height: 6)
                }
            }
            .frame(height: 6)

            Text("리셋: \(formatResetTime(resetTime))")
                .font(.caption2)
                .foregroundColor(Color(nsColor: .quaternaryLabelColor))
        }
    }

    private func modelBadge(name: String, percentage: Double) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(usageColor(percentage))
                .frame(width: 6, height: 6)
            Text("\(name) \(Int(percentage))%")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        VStack(spacing: 10) {
            // 아이콘 스타일
            HStack {
                Text("아이콘")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()

                Picker("", selection: $settings.iconStyle) {
                    Text("%").tag(AppSettings.IconStyle.percentage)
                    Text("Bar").tag(AppSettings.IconStyle.progressBar)
                    Text("Bat").tag(AppSettings.IconStyle.battery)
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }

            // 리프레시 간격
            HStack {
                Text("갱신")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()

                Picker("", selection: $settings.refreshInterval) {
                    Text("15초").tag(15.0)
                    Text("30초").tag(30.0)
                    Text("60초").tag(60.0)
                    Text("5분").tag(300.0)
                }
                .frame(width: 140)
            }

            // 알림 토글
            HStack(spacing: 8) {
                Text("알림")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()

                alertToggle("75%", isOn: $settings.alertAt75)
                alertToggle("90%", isOn: $settings.alertAt90)
                alertToggle("95%", isOn: $settings.alertAt95)
            }

            // 자동 실행
            HStack {
                Text("시작")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()

                Toggle("로그인 시 자동 실행", isOn: $settings.launchAtLogin)
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func alertToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(label)
                .font(.caption2)
        }
        .toggleStyle(.checkbox)
        .controlSize(.small)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            Button("종료") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .foregroundColor(.secondary)

            Spacer()

            Text("v1.0.0")
                .font(.caption2)
                .foregroundColor(Color(nsColor: .quaternaryLabelColor))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private func usageColor(_ percentage: Double) -> Color {
        switch percentage {
        case 0..<75: return .green
        case 75..<90: return .yellow
        case 90..<95: return .orange
        default: return .red
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    private func formatResetTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "HH:mm KST"

        let now = Date()
        let interval = date.timeIntervalSince(now)

        if interval > 0 {
            let hours = Int(interval) / 3600
            let minutes = (Int(interval) % 3600) / 60
            if hours > 0 {
                return "\(formatter.string(from: date)) (\(hours)h \(minutes)m 후)"
            } else {
                return "\(formatter.string(from: date)) (\(minutes)m 후)"
            }
        }

        return formatter.string(from: date)
    }
}
