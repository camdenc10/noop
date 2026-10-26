import SwiftUI

// MARK: - Typography

/// Small uppercase label.
struct Eyebrow: View {
    let text: String
    var color: Color = Theme.textSecondary

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(color)
    }
}

/// Heavy condensed numerals used for every headline number.
struct BigNumber: View {
    let text: String
    var size: CGFloat = 34
    var color: Color = .white

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .heavy))
            .tracking(-size * 0.015)
            .monospacedDigit()
            .foregroundStyle(color)
            .fontWidth(.condensed)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .contentTransition(.numericText())
    }
}

// MARK: - Rings

struct RingView: View {
    var progress: Double?
    var color: Color
    var lineWidth: CGFloat = 10

    @State private var shown: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: shown)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .opacity(shown > 0.003 ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { shown = clamped }
        }
        .onChange(of: progress) { _, _ in
            withAnimation(.easeOut(duration: 0.6)) { shown = clamped }
        }
    }

    private var clamped: Double {
        min(max(progress ?? 0, 0), 1)
    }
}

/// A ring with its number in the middle. Proportions scale from `size`.
struct HeroRing: View {
    var progress: Double?
    var value: String
    var suffix: String? = nil
    var caption: String = ""
    var color: Color
    var size: CGFloat

    var body: some View {
        ZStack {
            RingView(progress: progress, color: color, lineWidth: size * 0.085)
            VStack(spacing: size * 0.015) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    BigNumber(text: value, size: size * (value.count >= 3 ? 0.27 : 0.34), color: progress == nil ? Theme.textTertiary : .white)
                    if let suffix = suffix {
                        Text(suffix)
                            .font(.system(size: size * 0.13, weight: .bold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                if !caption.isEmpty {
                    Eyebrow(text: caption, color: Theme.textTertiary)
                }
            }
            .padding(.horizontal, size * 0.12)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Badges

struct StatusBadge: View {
    let text: String
    var color: Color

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(1.1)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay(Capsule().strokeBorder(color.opacity(0.55), lineWidth: 1))
    }
}

struct DemoChip: View {
    var body: some View {
        Text("DEMO DATA")
            .font(.system(size: 9, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(Theme.yellow)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Theme.yellow.opacity(0.12), in: Capsule())
    }
}

struct AvatarView: View {
    let name: String
    var size: CGFloat = 36

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2).compactMap { $0.first }
        return String(parts).uppercased()
    }

    var body: some View {
        ZStack {
            Circle().fill(Theme.card)
            Circle().strokeBorder(Theme.border, lineWidth: 1)
            if initials.isEmpty {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Text(initials)
                    .font(.system(size: size * 0.36, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Baseline comparison

struct Delta {
    var text: String
    var up: Bool
    var color: Color
}

enum Baseline {
    /// Higher HRV than baseline is better.
    static func hrv(_ value: Double?, _ base: Double?) -> Delta? {
        guard let value = value, let base = base, base > 0 else { return nil }
        let pct = (value / base - 1) * 100
        let color: Color = pct >= 5 ? Theme.green : (pct <= -5 ? Theme.red : Theme.textSecondary)
        return Delta(text: String(format: "%.0f%%", abs(pct)), up: pct >= 0, color: color)
    }

    /// Lower resting heart rate than baseline is better.
    static func rhr(_ value: Double?, _ base: Double?) -> Delta? {
        guard let value = value, let base = base else { return nil }
        let diff = value - base
        let color: Color = diff <= -1 ? Theme.green : (diff >= 2 ? Theme.red : Theme.textSecondary)
        return Delta(text: String(format: "%.0f bpm", abs(diff)), up: diff >= 0, color: color)
    }

    /// Lower respiratory rate than baseline is better.
    static func respiratory(_ value: Double?, _ base: Double?) -> Delta? {
        guard let value = value, let base = base else { return nil }
        let diff = value - base
        let color: Color = diff <= -0.3 ? Theme.green : (diff >= 0.6 ? Theme.red : Theme.textSecondary)
        return Delta(text: String(format: "%.1f", abs(diff)), up: diff >= 0, color: color)
    }
}

struct DeltaTag: View {
    let delta: Delta?
    var baselineText: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            if let delta = delta {
                HStack(spacing: 3) {
                    Image(systemName: delta.up ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                        .font(.system(size: 7))
                    Text(delta.text)
                        .font(.system(size: 12, weight: .bold))
                        .monospacedDigit()
                }
                .foregroundStyle(delta.color)
            }
            Text(baselineText)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
        }
    }
}

// MARK: - Metric rows and tiles

/// Label, number and optional baseline comparison on one line.
struct MetricLine: View {
    let label: String
    let value: String
    var unit: String = ""
    var delta: Delta? = nil
    var baselineText: String? = nil
    var valueColor: Color = .white

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Eyebrow(text: label)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    BigNumber(text: value, size: 24, color: valueColor)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            Spacer(minLength: 4)
            if delta != nil || baselineText != nil {
                DeltaTag(delta: delta, baselineText: baselineText ?? "")
            }
        }
    }
}

struct HairlineDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.border)
            .frame(height: 1)
    }
}

/// Vertical stat tile used in pairs.
struct StatTile: View {
    let title: String
    let value: String
    var unit: String = ""
    var delta: Delta? = nil
    var baselineText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: title)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                BigNumber(text: value, size: 36, color: value == "—" ? Theme.textTertiary : .white)
                if !unit.isEmpty && value != "—" {
                    Text(unit)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            HStack(spacing: 6) {
                if let delta = delta {
                    HStack(spacing: 3) {
                        Image(systemName: delta.up ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                            .font(.system(size: 7))
                        Text(delta.text)
                            .font(.system(size: 12, weight: .bold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(delta.color)
                }
                Text(baselineText.isEmpty && delta == nil ? "Unavailable" : baselineText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .card()
    }
}

struct ProgressBar: View {
    var progress: Double
    var color: Color
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                Capsule()
                    .fill(color)
                    .frame(width: max(geo.size.width * min(max(progress, 0), 1), progress > 0 ? height : 0))
            }
        }
        .frame(height: height)
    }
}

/// Full-width card with a number and a thin chart on the right.
struct MetricCard: View {
    let title: String
    let value: String?
    var unit: String = ""
    var detail: String? = nil
    var detailColor: Color = Theme.textSecondary
    var series: [TrendPoint] = []
    var color: Color = Theme.green
    var bars = false
    var progress: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(text: title)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        BigNumber(text: value ?? "—", size: 30, color: value == nil ? Theme.textTertiary : .white)
                        if value != nil && !unit.isEmpty {
                            Text(unit)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    if let detail = detail {
                        Text(detail)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(detailColor)
                    } else if value == nil {
                        Text("Unavailable")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                Spacer(minLength: 8)
                if series.count > 1 {
                    Sparkline(points: series, color: color, bars: bars)
                        .frame(width: 112, height: 48)
                }
            }
            if let progress = progress {
                ProgressBar(progress: progress, color: color)
            }
        }
        .card()
    }
}

// MARK: - Heart rate zones

/// Stacked bar plus a legend with minutes per zone.
struct ZoneBar: View {
    let minutes: [Double]

    private var total: Double { max(minutes.reduce(0, +), 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if minutes.isEmpty {
                Text("Heart rate zones unavailable")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
            } else {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { i in
                            Capsule()
                                .fill(Theme.zoneColor(i))
                                .frame(width: max((geo.size.width - 8) * (minutes[i] / total), 3))
                        }
                    }
                }
                .frame(height: 6)

                HStack {
                    ForEach(0..<5, id: \.self) { i in
                        VStack(spacing: 2) {
                            HStack(spacing: 4) {
                                Circle().fill(Theme.zoneColor(i)).frame(width: 5, height: 5)
                                Text("Z\(i + 1)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Text("\(Int(minutes[i].rounded()))m")
                                .font(.system(size: 12, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

// MARK: - Screen chrome

struct ScreenHeader<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                if let subtitle = subtitle {
                    Eyebrow(text: subtitle)
                }
                Text(title)
                    .font(.system(size: 36, weight: .heavy))
                    .tracking(-0.6)
                    .foregroundStyle(.white)
                    .fontWidth(.condensed)
            }
            Spacer()
            trailing()
        }
        .padding(.top, 8)
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = { EmptyView() }
    }
}

/// Chevrons around a date for moving between days.
struct DayStepper: View {
    let date: Date
    let canGoBack: Bool
    let canGoForward: Bool
    let back: () -> Void
    let forward: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            stepButton("chevron.left", enabled: canGoBack, action: back)
            Text(date.formatted(.dateTime.month(.abbreviated).day()).uppercased())
                .font(.system(size: 12, weight: .bold))
                .tracking(1)
                .foregroundStyle(.white)
                .frame(minWidth: 52)
            stepButton("chevron.right", enabled: canGoForward, action: forward)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(Theme.card, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
    }

    private func stepButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(enabled ? Color.white : Theme.textTertiary)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

struct InsightRow: View {
    let insight: Insight

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Capsule()
                .fill(Theme.toneColor(insight.tone))
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Text(insight.body)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Empty state shown instead of a chart when there isn't enough data.
struct UnavailableNote: View {
    var text: String = "Not enough data yet"

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.textTertiary)
            .frame(maxWidth: .infinity, minHeight: 90)
    }
}
