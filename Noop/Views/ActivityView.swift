import SwiftUI

struct ActivityView: View {
    @Environment(AppStore.self) private var store
    @State private var cursor = DayCursor()
    @State private var range: TrendRange = .week

    private var index: Int? { cursor.index(in: store.days) }
    private var day: DaySummary? { index.map { store.days[$0] } }

    var body: some View {
        Screen {
            ScreenHeader(title: "Activity", subtitle: "Strain") {
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
                zones(day)
                totals(day)
                workoutList(day)
                charts
            } else {
                UnavailableNote(text: "No data yet").card()
            }
        }
    }

    private func strainColor(_ strain: Double?) -> Color {
        guard let strain = strain else { return Theme.textTertiary }
        if strain >= 14 { return Theme.red }
        if strain >= 10 { return Theme.yellow }
        return Theme.green
    }

    private func hero(_ day: DaySummary) -> some View {
        VStack(spacing: 16) {
            HeroRing(progress: day.strain.map { $0 / 21 },
                     value: Fmt.decimal(day.strain),
                     caption: "Strain · 0-21",
                     color: strainColor(day.strain), size: 220)
            Text(day.strain == nil
                 ? "Needs heart rate readings from Health to calculate strain."
                 : "Strain flattens toward 21: the last few points take far more effort than the first.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 22)
    }

    private func zones(_ day: DaySummary) -> some View {
        let maxHR = Settings.maxHR
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Eyebrow(text: "Heart rate zones", color: .white)
                Spacer()
                Text("MAX \(Int(maxHR)) BPM")
                    .font(.system(size: 11, weight: .bold)).tracking(0.8)
                    .foregroundStyle(Theme.textSecondary)
            }
            if day.zoneMinutes.count == 5 {
                ForEach(0..<5, id: \.self) { i in
                    let minutes = day.zoneMinutes[i]
                    VStack(spacing: 6) {
                        HStack {
                            Text("Zone \(i + 1)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                            Text(ScoringEngine.zoneRange(i, maxHR: maxHR))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Theme.textTertiary)
                            Spacer()
                            Text(Fmt.duration(minutes))
                                .font(.system(size: 15, weight: .heavy))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                        }
                        ProgressBar(progress: minutes / max(day.zoneMinutes.max() ?? 1, 1),
                                    color: Theme.zoneColor(i))
                    }
                }
            } else {
                UnavailableNote(text: "Heart rate zones unavailable")
            }
        }
        .card()
    }

    private func totals(_ day: DaySummary) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatTile(title: "Steps", value: Fmt.thousands(day.steps),
                         baselineText: store.average(range: .month, value: { $0.steps })
                            .map { "30-day avg \(Fmt.thousands($0))" } ?? "")
                StatTile(title: "Active kcal", value: Fmt.thousands(day.activeEnergy),
                         baselineText: store.average(range: .month, value: { $0.activeEnergy })
                            .map { "30-day avg \(Fmt.thousands($0))" } ?? "")
            }
            HStack(spacing: 12) {
                StatTile(title: "Average HR", value: Fmt.whole(day.avgHR), unit: "bpm")
                StatTile(title: "Max HR", value: Fmt.whole(day.maxHR), unit: "bpm")
            }
        }
    }

    private func workoutList(_ day: DaySummary) -> some View {
        let recent = Array(store.workouts.prefix(8))
        return VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "Workout history", color: .white)
            if recent.isEmpty {
                UnavailableNote(text: "No workouts recorded")
            } else {
                ForEach(Array(recent.enumerated()), id: \.element.id) { offset, workout in
                    if offset > 0 { HairlineDivider() }
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(workout.name)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                            Text("\(workout.start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())) · \(Int(workout.durationMin.rounded())) min")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            BigNumber(text: Fmt.decimal(workout.strain), size: 22,
                                      color: workout.strain == nil ? Theme.textTertiary : strainColor(workout.strain))
                            Text(workout.energy.map { "\(Int($0.rounded())) kcal" } ?? "kcal unavailable")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            }
        }
        .card()
    }

    private var charts: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "Activity trends", color: .white)
            RangePicker(range: $range)
            chart("Strain", color: Theme.yellow, style: .bar,
                  format: { String(format: "%.1f", $0) }) { $0.strain }
            chart("Steps", color: Theme.blue, style: .bar,
                  format: { Fmt.thousands($0) }) { $0.steps }
            chart("Active calories", color: Theme.red, style: .line,
                  format: { "\(Int($0.rounded())) kcal" }) { $0.activeEnergy }
        }
        .card()
    }

    @ViewBuilder
    private func chart(_ title: String, color: Color, style: TrendChart.Style,
                       format: @escaping (Double) -> String,
                       value: @escaping (DaySummary) -> Double?) -> some View {
        let points = store.series(range: range, value: value)
        Eyebrow(text: title, color: Theme.textTertiary)
        if points.count > 1 {
            TrendChart(points: points, color: color, style: style, format: format, height: 110)
                .id(range)
        } else {
            UnavailableNote()
        }
    }
}
