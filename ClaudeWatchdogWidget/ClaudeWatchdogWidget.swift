import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct UsageEntry: TimelineEntry {
    let date: Date
    let sessionPercentage: Double
    let weeklyPercentage: Double
    let opusPercentage: Double
    let sonnetPercentage: Double
    let sessionResetTime: Date
    let lastUpdated: Date
    let isPlaceholder: Bool

    static var placeholder: UsageEntry {
        UsageEntry(
            date: Date(),
            sessionPercentage: 42,
            weeklyPercentage: 28,
            opusPercentage: 15,
            sonnetPercentage: 35,
            sessionResetTime: Date().addingTimeInterval(3 * 3600),
            lastUpdated: Date(),
            isPlaceholder: true
        )
    }

    static var empty: UsageEntry {
        UsageEntry(
            date: Date(),
            sessionPercentage: 0,
            weeklyPercentage: 0,
            opusPercentage: 0,
            sonnetPercentage: 0,
            sessionResetTime: Date().addingTimeInterval(5 * 3600),
            lastUpdated: Date(),
            isPlaceholder: false
        )
    }
}

// MARK: - Timeline Provider

struct UsageTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> UsageEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        let entry = loadEntry()
        // 5분마다 갱신
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private static let appGroupID = "YXPA46F4SJ.com.dante-labs.ClaudeWatchdog"

    private func loadEntry() -> UsageEntry {
        let fileURL: URL
        if let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroupID
        ) {
            fileURL = containerURL
                .appendingPathComponent("Library/Application Support")
                .appendingPathComponent("shared-usage.json")
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            fileURL = appSupport.appendingPathComponent("ClaudeWatchdog/shared-usage.json")
        }

        guard let data = try? Data(contentsOf: fileURL),
              let usage = try? JSONDecoder().decode(SharedClaudeUsage.self, from: data) else {
            return .empty
        }

        return UsageEntry(
            date: Date(),
            sessionPercentage: usage.sessionPercentage,
            weeklyPercentage: usage.weeklyPercentage,
            opusPercentage: usage.opusWeeklyPercentage,
            sonnetPercentage: usage.sonnetWeeklyPercentage,
            sessionResetTime: usage.sessionResetTime,
            lastUpdated: usage.lastUpdated,
            isPlaceholder: false
        )
    }
}

/// 위젯 전용 디코딩 모델 (메인 앱의 ClaudeUsage와 동일 구조)
private struct SharedClaudeUsage: Codable {
    var sessionPercentage: Double
    var sessionResetTime: Date
    var weeklyPercentage: Double
    var weeklyResetTime: Date
    var opusWeeklyPercentage: Double
    var sonnetWeeklyPercentage: Double
    var lastUpdated: Date
}

// MARK: - Widget Views

struct SmallWidgetView: View {
    let entry: UsageEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "gauge.with.needle")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("Claude")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
            }

            Text("\(Int(entry.sessionPercentage))%")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(usageColor(entry.sessionPercentage))
                .minimumScaleFactor(0.6)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(usageColor(entry.sessionPercentage))
                        .frame(width: geo.size.width * entry.sessionPercentage / 100)
                }
            }
            .frame(height: 6)

            Text("리셋 \(formatResetTime(entry.sessionResetTime))")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct MediumWidgetView: View {
    let entry: UsageEntry

    var body: some View {
        HStack(spacing: 16) {
            // 좌측: 세션 사용량
            VStack(alignment: .leading, spacing: 6) {
                Label("세션", systemImage: "gauge.with.needle")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text("\(Int(entry.sessionPercentage))%")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(usageColor(entry.sessionPercentage))

                ProgressView(value: entry.sessionPercentage, total: 100)
                    .tint(usageColor(entry.sessionPercentage))

                Text("리셋 \(formatResetTime(entry.sessionResetTime))")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            Divider()

            // 우측: 주간 + 모델별
            VStack(alignment: .leading, spacing: 8) {
                usageRow(label: "주간", percentage: entry.weeklyPercentage)
                usageRow(label: "Opus", percentage: entry.opusPercentage)
                usageRow(label: "Sonnet", percentage: entry.sonnetPercentage)

                Spacer()

                Text(formatLastUpdated(entry.lastUpdated))
                    .font(.system(size: 8))
                    .foregroundColor(Color.gray.opacity(0.4))
            }
        }
        .padding(12)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func usageRow(label: String, percentage: Double) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 36, alignment: .leading)
            ProgressView(value: percentage, total: 100)
                .tint(usageColor(percentage))
            Text("\(Int(percentage))%")
                .font(.system(.caption2, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundColor(usageColor(percentage))
                .frame(width: 30, alignment: .trailing)
        }
    }
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

private func formatResetTime(_ date: Date) -> String {
    let interval = date.timeIntervalSince(Date())
    guard interval > 0 else { return "곧" }
    let hours = Int(interval) / 3600
    let minutes = (Int(interval) % 3600) / 60
    if hours > 0 { return "\(hours)h \(minutes)m 후" }
    return "\(minutes)m 후"
}

private func formatLastUpdated(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
}

// MARK: - Widget Definition

struct ClaudeWatchdogWidget: Widget {
    let kind = "ClaudeWatchdogWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UsageTimelineProvider()) { entry in
            WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Claude 사용량")
        .description("Claude Code 사용량을 실시간으로 모니터링합니다.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct WidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: UsageEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Bundle (Entry Point)

@main
struct ClaudeWatchdogWidgetBundle: WidgetBundle {
    var body: some Widget {
        ClaudeWatchdogWidget()
    }
}

// MARK: - Preview

#Preview("Small", as: .systemSmall) {
    ClaudeWatchdogWidget()
} timeline: {
    UsageEntry.placeholder
}

#Preview("Medium", as: .systemMedium) {
    ClaudeWatchdogWidget()
} timeline: {
    UsageEntry.placeholder
}
