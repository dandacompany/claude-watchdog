import AppKit

/// 메뉴 바 아이콘 렌더링
struct MenuBarIconRenderer {

    enum Style {
        case percentage
        case progressBar
        case battery
    }

    /// 사용량 기반 색상 반환
    /// 초록(0-74%) → 노랑(75-89%) → 주황(90-94%) → 빨강(95-100%)
    static func color(for percentage: Double) -> NSColor {
        switch percentage {
        case 0..<75:
            return NSColor.systemGreen
        case 75..<90:
            return NSColor.systemYellow
        case 90..<95:
            return NSColor.systemOrange
        default:
            return NSColor.systemRed
        }
    }

    /// 메뉴 바용 아이콘 이미지 생성
    static func createImage(percentage: Double, style: Style) -> NSImage {
        switch style {
        case .percentage:
            return createPercentageImage(percentage: percentage)
        case .progressBar:
            return createProgressBarImage(percentage: percentage)
        case .battery:
            return createBatteryImage(percentage: percentage)
        }
    }

    /// "—%" 텍스트 아이콘 (크리덴셜 없을 때)
    static func createPlaceholderImage() -> NSImage {
        let text = "—%"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor
        ]

        let textSize = (text as NSString).size(withAttributes: attrs)
        let imageSize = NSSize(width: textSize.width + 4, height: 18)

        let image = NSImage(size: imageSize, flipped: false) { rect in
            let textRect = NSRect(
                x: (rect.width - textSize.width) / 2,
                y: (rect.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            (text as NSString).draw(in: textRect, withAttributes: attrs)
            return true
        }
        image.isTemplate = false
        return image
    }

    // MARK: - Percentage Style ("45%")

    private static func createPercentageImage(percentage: Double) -> NSImage {
        let text = "\(Int(percentage))%"
        let color = color(for: percentage)

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .bold),
            .foregroundColor: color
        ]

        let textSize = (text as NSString).size(withAttributes: attrs)
        let imageSize = NSSize(width: max(textSize.width + 4, 28), height: 18)

        let image = NSImage(size: imageSize, flipped: false) { rect in
            let textRect = NSRect(
                x: (rect.width - textSize.width) / 2,
                y: (rect.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            (text as NSString).draw(in: textRect, withAttributes: attrs)
            return true
        }
        image.isTemplate = false
        return image
    }

    // MARK: - Progress Bar Style

    private static func createProgressBarImage(percentage: Double) -> NSImage {
        let barWidth: CGFloat = 32
        let barHeight: CGFloat = 8
        let imageSize = NSSize(width: barWidth + 4, height: 18)
        let color = color(for: percentage)

        let image = NSImage(size: imageSize, flipped: false) { rect in
            let barRect = NSRect(
                x: 2,
                y: (rect.height - barHeight) / 2,
                width: barWidth,
                height: barHeight
            )

            // Background
            let bgPath = NSBezierPath(roundedRect: barRect, xRadius: 3, yRadius: 3)
            NSColor.quaternaryLabelColor.setFill()
            bgPath.fill()

            // Fill
            let fillWidth = max(barWidth * CGFloat(percentage / 100.0), 3)
            let fillRect = NSRect(
                x: barRect.origin.x,
                y: barRect.origin.y,
                width: fillWidth,
                height: barHeight
            )
            let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: 3, yRadius: 3)
            color.setFill()
            fillPath.fill()

            // Border
            let borderPath = NSBezierPath(roundedRect: barRect, xRadius: 3, yRadius: 3)
            NSColor.tertiaryLabelColor.setStroke()
            borderPath.lineWidth = 0.5
            borderPath.stroke()

            return true
        }
        image.isTemplate = false
        return image
    }

    // MARK: - Battery Style

    private static func createBatteryImage(percentage: Double) -> NSImage {
        let bodyWidth: CGFloat = 24
        let bodyHeight: CGFloat = 12
        let tipWidth: CGFloat = 3
        let tipHeight: CGFloat = 6
        let imageSize = NSSize(width: bodyWidth + tipWidth + 4, height: 18)
        let color = color(for: percentage)

        let image = NSImage(size: imageSize, flipped: false) { rect in
            let bodyRect = NSRect(
                x: 2,
                y: (rect.height - bodyHeight) / 2,
                width: bodyWidth,
                height: bodyHeight
            )

            // Battery body
            let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: 2, yRadius: 2)
            NSColor.tertiaryLabelColor.setStroke()
            bodyPath.lineWidth = 1.0
            bodyPath.stroke()

            // Battery tip
            let tipRect = NSRect(
                x: bodyRect.maxX + 1,
                y: (rect.height - tipHeight) / 2,
                width: tipWidth,
                height: tipHeight
            )
            let tipPath = NSBezierPath(roundedRect: tipRect, xRadius: 1, yRadius: 1)
            NSColor.tertiaryLabelColor.setFill()
            tipPath.fill()

            // Fill level
            let padding: CGFloat = 2
            let fillMaxWidth = bodyWidth - padding * 2
            let fillWidth = max(fillMaxWidth * CGFloat(percentage / 100.0), 2)
            let fillRect = NSRect(
                x: bodyRect.origin.x + padding,
                y: bodyRect.origin.y + padding,
                width: fillWidth,
                height: bodyHeight - padding * 2
            )
            let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: 1, yRadius: 1)
            color.setFill()
            fillPath.fill()

            return true
        }
        image.isTemplate = false
        return image
    }
}
