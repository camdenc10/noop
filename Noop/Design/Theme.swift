import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

/// Noop design tokens. Pure black canvas, charcoal cards, three performance colors.
enum Theme {
    static let black = Color(hex: 0x000000)
    static let canvasTop = Color(hex: 0x1C2027)
    static var canvas: LinearGradient {
        LinearGradient(colors: [canvasTop, Color(hex: 0x0B0D10), black], startPoint: .top, endPoint: .bottom)
    }
    static let card = Color(hex: 0x171717)
    static let raised = Color(hex: 0x222222)
    static let border = Color.white.opacity(0.08)
    static let track = Color.white.opacity(0.10)
    static let textSecondary = Color(hex: 0x8E8E93)
    static let textTertiary = Color(hex: 0x5A5A5F)

    static let green = Color(hex: 0x1CFF80)
    static let yellow = Color(hex: 0xFFE12E)
    static let red = Color(hex: 0xFF3B52)
    static let blue = Color(hex: 0x3D8BFF)
    static let violet = Color(hex: 0xB67CFF)
    static let lightSleep = Color(hex: 0x6FA8FF)
    static let sleepRing = Color(hex: 0x86A5C9)
    static let strainRing = Color(hex: 0x3D8BFF)
    static let deepSleep = Color(hex: 0x3558FF)

    /// 70 and above is green, 40 to 69 yellow, below 40 red.
    static func recoveryColor(_ score: Double?) -> Color {
        guard let score = score else { return textTertiary }
        if score >= 70 { return green }
        if score >= 40 { return yellow }
        return red
    }

    /// 85 and above is green, 70 to 84 yellow, below 70 red.
    static func sleepColor(_ score: Double?) -> Color {
        guard let score = score else { return textTertiary }
        if score >= 85 { return green }
        if score >= 70 { return yellow }
        return red
    }

    static func zoneColor(_ index: Int) -> Color {
        let colors: [Color] = [Color(hex: 0x5F6B7A), blue, green, yellow, red]
        return colors[min(max(index, 0), 4)]
    }

    static func stageColor(_ stage: SleepStage) -> Color {
        switch stage {
        case .awake: return Color(hex: 0xA1A1A6)
        case .rem: return violet
        case .light: return lightSleep
        case .deep: return deepSleep
        }
    }

    static func toneColor(_ tone: InsightTone) -> Color {
        switch tone {
        case .positive: return green
        case .caution: return yellow
        case .warning: return red
        case .neutral: return textSecondary
        }
    }
}

// MARK: - Formatting

enum Fmt {
    /// Minutes as "7:12".
    static func duration(_ minutes: Double?) -> String {
        guard let minutes = minutes else { return "—" }
        let total = Int(minutes.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func whole(_ value: Double?) -> String {
        guard let value = value else { return "—" }
        return String(Int(value.rounded()))
    }

    static func decimal(_ value: Double?, places: Int = 1) -> String {
        guard let value = value else { return "—" }
        return String(format: "%.\(places)f", value)
    }

    static func thousands(_ value: Double?) -> String {
        guard let value = value else { return "—" }
        return Int(value.rounded()).formatted()
    }
}

// MARK: - Card

struct CardModifier: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
