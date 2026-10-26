import SwiftUI

/// Remembers which day a detail screen is showing. nil means the latest day.
struct DayCursor {
    var offsetFromLatest = 0   // 0 = latest, 1 = the day before, ...

    func index(in days: [DaySummary]) -> Int? {
        guard !days.isEmpty else { return nil }
        return max(days.count - 1 - offsetFromLatest, 0)
    }
}

struct RecoveryView: View {
    @Environment(AppStore.self) private var store
    @State private var cursor = DayCursor()
    @State private var range: TrendRange = .month
    @State private var showMethod = false

    private var index: Int? { cursor.index(in: store.days) }
    private var day: DaySummary? { index.map { store.days[$0] } }

    var body: some View {
        Screen {
            ScreenHeader(title: "Recovery", subtitle: "Readiness") {
                if let day = day {
                    DayStepper(date: day.date,
                               canGoBack: (index ?? 0) > 0,
                               canGoForward: cursor.offsetFromLatest > 0,
                               back: { withAnimation(.snappy) { cursor.offsetFromLatest += 1 } },
                               forward: { withAnimation(.snappy) { cursor.offsetFromLatest -= 1 } })
                }
            }
            if let day = day {
                hero(day)
                statTiles(day)
                breakdown(day)
                history
                insights(day)
                Button { showMethod = true } label: {
                    Text("HOW RECOVERY IS CALCULATED")
                        .font(.system(size: 11, weight: .bold)).tracking(1.1)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            } else {
                UnavailableNote(text: "No data yet").card()
            }
        }
        .sheet(isPresented: $showMethod) { MethodologyView() }
    }

    private func hero(_ day: DaySummary) -> some View {
        let color = Theme.recoveryColor(day.recovery)
        return VStack(spacing: 18) {
            HeroRing(progress: day.recovery.map { $0 / 100 },
                     value: Fmt.whole(day.recovery),
                     suffix: day.recovery == nil ? nil : "%",
                     caption: "Recovery", color: color, size: 220)
            if let score = day.recovery {
                StatusBadge(text: score >= 70 ? "Primed to perform" : (score >= 40 ? "Moderate" : "Take it easy"),
                            color: color)
            } else {
                Text("Needs overnight HRV or resting heart rate, and at least \(ScoringEngine.minBaselineDays) days of history.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .card(padding: 24)
    }

    private func statTiles(_ day: DaySummary) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatTile(title: "HRV", value: Fmt.whole(day.hrv), unit: "ms",
                         delta: Baseline.hrv(day.hrv, day.hrvBaseline),
                         baselineText: day.hrvBaseline.map { "vs \(Int($0.rounded())) avg" } ?? "")
                StatTile(title: "Resting HR", value: Fmt.whole(day.restingHR), unit: "bpm",
                         delta: Baseline.rhr(day.restingHR, day.rhrBaseline),
                         baselineText: day.rhrBaseline.map { "vs \(Int($0.rounded())) avg" } ?? "")
            }
            HStack(spacing: 12) {
                StatTile(title: "Respiratory", value: Fmt.decimal(day.respiratoryRate), unit: "rpm",
                         delta: Baseline.respiratory(day.respiratoryRate, day.respBaseline),
                         baselineText: day.respBaseline.map { "vs \(Fmt.decimal($0)) avg" } ?? "")
                StatTile(title: "Sleep", value: Fmt.whole(day.sleepPerformance), unit: "%",
                         baselineText: day.sleepNeedMin == nil ? "" : "performance")
            }
        }
    }

    private func breakdown(_ day: DaySummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "What made up this score", color: .white)
            if day.recoveryParts.isEmpty {
                UnavailableNote()
            } else {
                ForEach(day.recoveryParts) { part in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(part.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("\(Int((part.weight * 100).rounded()))%")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Theme.textTertiary)
                            Spacer()
                            Text(Fmt.whole(part.score))
                                .font(.system(size: 14, weight: .heavy))
                                .monospacedDigit()
                                .foregroundStyle(Theme.recoveryColor(part.score))
                        }
                        ProgressBar(progress: part.score / 100, color: Theme.recoveryColor(part.score))
                        Text(part.detail)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
        }
        .card()
    }

    private var history: some View {
        let points = store.series(range: range, value: { $0.recovery },
                                  tint: { Theme.recoveryColor($0) })
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Eyebrow(text: "Recovery history", color: .white)
                Spacer()
                if let avg = store.average(range: range, value: { $0.recovery }) {
                    Text("AVG \(Int(avg.rounded()))%")
                        .font(.system(size: 11, weight: .bold)).tracking(0.8)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            RangePicker(range: $range)
            if points.count > 1 {
                TrendChart(points: points, color: Theme.green, style: .bar,
                           format: { "\(Int($0.rounded()))%" }, height: 150)
                    .id(range)
            } else {
                UnavailableNote()
            }
            HairlineDivider()
            trendLine("HRV", unit: "ms", color: Theme.green) { $0.hrv }
            trendLine("Resting HR", unit: "bpm", color: Theme.red) { $0.restingHR }
        }
        .card()
    }

    private func trendLine(_ title: String, unit: String, color: Color,
                           value: @escaping (DaySummary) -> Double?) -> some View {
        let points = store.series(range: range, value: value)
        return VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: title)
            if points.count > 1 {
                TrendChart(points: points, color: color, style: .line,
                           format: { "\(Int($0.rounded())) \(unit)" }, height: 100)
                    .id(range)
            } else {
                UnavailableNote()
            }
        }
    }

    private func insights(_ day: DaySummary) -> some View {
        let items = ScoringEngine.insights(for: day, history: store.history(upTo: day.date))
        return VStack(alignment: .leading, spacing: 16) {
            Eyebrow(text: "Insights", color: .white)
            ForEach(items) { InsightRow(insight: $0) }
        }
        .card()
    }
}
