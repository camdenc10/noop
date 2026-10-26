import SwiftUI

struct SleepView: View {
    @Environment(AppStore.self) private var store
    @State private var cursor = DayCursor()
    @State private var range: TrendRange = .week

    private var index: Int? { cursor.index(in: store.days) }
    private var day: DaySummary? { index.map { store.days[$0] } }

    var body: some View {
        Screen {
            ScreenHeader(title: "Sleep", subtitle: "Last night") {
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
                timeline(day)
                stages(day)
                needAndDebt(day)
                history
            } else {
                UnavailableNote(text: "No data yet").card()
            }
        }
    }

    private func hero(_ day: DaySummary) -> some View {
        let color = Theme.sleepColor(day.sleepPerformance)
        return VStack(spacing: 18) {
            HeroRing(progress: day.sleepPerformance.map { $0 / 100 },
                     value: Fmt.whole(day.sleepPerformance),
                     suffix: day.sleepPerformance == nil ? nil : "%",
                     caption: "Performance", color: color, size: 200)
            HStack {
                bigStat("Asleep", Fmt.duration(day.sleep?.asleepMin))
                bigStat("Needed", Fmt.duration(day.sleepNeedMin))
                bigStat("Efficiency", day.sleep?.efficiency.map { "\(Int($0.rounded()))%" } ?? "—")
            }
        }
        .frame(maxWidth: .infinity)
        .card(padding: 22)
    }

    private func bigStat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Eyebrow(text: title)
            BigNumber(text: value, size: 24, color: value == "—" ? Theme.textTertiary : .white)
        }
        .frame(maxWidth: .infinity)
    }

    private func timeline(_ day: DaySummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Eyebrow(text: "Sleep stages", color: .white)
                Spacer()
                if let night = day.sleep {
                    Text("\(night.onset.formatted(date: .omitted, time: .shortened)) – \(night.wake.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            if let night = day.sleep, night.hasStages {
                HypnogramView(night: night)
            } else if day.sleep != nil {
                UnavailableNote(text: "This source doesn't report sleep stages")
            } else {
                UnavailableNote(text: "No sleep recorded")
            }
        }
        .card()
    }

    private func stages(_ day: DaySummary) -> some View {
        let night = day.sleep
        let total = max(night?.asleepMin ?? 0, 1)
        return VStack(spacing: 14) {
            ForEach([SleepStage.deep, SleepStage.rem, SleepStage.light, SleepStage.awake], id: \.self) { stage in
                let minutes: Double? = night.map { value(for: stage, in: $0) }
                VStack(spacing: 6) {
                    HStack {
                        Circle().fill(Theme.stageColor(stage)).frame(width: 7, height: 7)
                        Text(stage.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        if let minutes = minutes, night?.hasStages == true {
                            Text("\(Int((minutes / (stage == .awake ? total + minutes : total) * 100).rounded()))%")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Theme.textTertiary)
                            Text(Fmt.duration(minutes))
                                .font(.system(size: 15, weight: .heavy))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                                .frame(width: 52, alignment: .trailing)
                        } else {
                            Text("—").foregroundStyle(Theme.textTertiary)
                        }
                    }
                    ProgressBar(progress: night?.hasStages == true ? (minutes ?? 0) / total : 0,
                                color: Theme.stageColor(stage))
                }
            }
        }
        .card()
    }

    private func value(for stage: SleepStage, in night: SleepNight) -> Double {
        switch stage {
        case .deep: return night.deepMin
        case .rem: return night.remMin
        case .light: return night.lightMin
        case .awake: return night.awakeMin
        }
    }

    private func needAndDebt(_ day: DaySummary) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatTile(title: "Sleep debt", value: Fmt.duration(day.sleepDebtMin), unit: "h",
                         baselineText: "last 7 nights")
                StatTile(title: "Consistency", value: Fmt.whole(day.sleepConsistency), unit: "%",
                         baselineText: day.sleepConsistency == nil ? "needs 3 nights" : "last 5 nights")
            }
            if let need = day.sleepNeedMin {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(text: "How tonight's need is set", color: .white)
                    let base = Settings.sleepNeedHours * 60
                    Text("Baseline \(Fmt.duration(base)), plus \(Fmt.duration(max(need - base, 0))) for yesterday's strain and recent sleep debt.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .card()
            }
        }
    }

    private var history: some View {
        let points = store.series(range: range, value: { $0.sleepPerformance },
                                  tint: { Theme.sleepColor($0) })
        let hours = store.series(range: range, value: { $0.sleep.map { $0.asleepMin / 60 } })
        return VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "Sleep trends", color: .white)
            RangePicker(range: $range)
            if points.count > 1 {
                Eyebrow(text: "Performance", color: Theme.textTertiary)
                TrendChart(points: points, color: Theme.green, style: .bar,
                           format: { "\(Int($0.rounded()))%" }, height: 120).id(range)
                Eyebrow(text: "Hours asleep", color: Theme.textTertiary)
                TrendChart(points: hours, color: Theme.lightSleep, style: .line,
                           format: { String(format: "%.1f h", $0) }, height: 100).id(range)
            } else {
                UnavailableNote()
            }
        }
        .card()
    }
}
