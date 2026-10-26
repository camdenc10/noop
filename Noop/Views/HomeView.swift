import SwiftUI

struct HomeView: View {
    @Environment(AppStore.self) private var store
    @Environment(SensorMonitor.self) private var sensor
    @State private var cursor = DayCursor()
    @State private var showSensor = false
    var goTo: (AppTab) -> Void

    private var index: Int? { cursor.index(in: store.days) }
    private var day: DaySummary? { index.map { store.days[$0] } }

    var body: some View {
        Screen {
            header
            if store.isDemo || store.isSyncing {
                HStack(spacing: 8) {
                    if store.isDemo { DemoChip() }
                    if store.isSyncing { ProgressView().tint(Theme.green).scaleEffect(0.7) }
                }
            }
            if let day = day {
                ringRow(day)
                recoveryCard(day)
                strainCard(day)
                sleepCard(day)
                moreMetrics(day)
            } else {
                emptyState
            }
        }
        .refreshable { await store.sync(full: false) }
        .sheet(isPresented: $showSensor) { SensorSheet() }
    }

    // MARK: Header

    private var dayTitle: String {
        guard let day = day else { return "TODAY" }
        if cursor.offsetFromLatest == 0 { return "TODAY" }
        if cursor.offsetFromLatest == 1 { return "YESTERDAY" }
        return day.date.formatted(.dateTime.month(.abbreviated).day()).uppercased()
    }

    private var header: some View {
        HStack(spacing: 0) {
            Button { goTo(.profile) } label: {
                Image(systemName: "person")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 1.6))
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 0) {
                arrow("chevron.left", enabled: (index ?? 0) > 0) {
                    withAnimation(.snappy) { cursor.offsetFromLatest += 1 }
                }
                Text(dayTitle)
                    .font(.system(size: 14, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(.white)
                    .frame(minWidth: 108)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.14), in: Capsule())
                arrow("chevron.right", enabled: cursor.offsetFromLatest > 0) {
                    withAnimation(.snappy) { cursor.offsetFromLatest -= 1 }
                }
            }
            .padding(4)
            .background(Color.white.opacity(0.07), in: Capsule())

            Spacer()

            StrapBadge(level: sensor.batteryLevel, isConnected: sensor.isConnected) { showSensor = true }
                .frame(minWidth: 42, alignment: .trailing)
        }
        .padding(.top, 6)
    }

    private func arrow(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(enabled ? Color.white : Color.white.opacity(0.25))
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: Three rings

    private func ringRow(_ day: DaySummary) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ringColumn("Sleep", tab: .sleep) {
                HeroRing(progress: day.sleepPerformance.map { $0 / 100 },
                         value: Fmt.whole(day.sleepPerformance),
                         suffix: day.sleepPerformance == nil ? nil : "%",
                         color: Theme.sleepRing, size: 108)
            }
            ringColumn("Recovery", tab: .recovery) {
                HeroRing(progress: day.recovery.map { $0 / 100 },
                         value: Fmt.whole(day.recovery),
                         suffix: day.recovery == nil ? nil : "%",
                         color: Theme.recoveryColor(day.recovery), size: 108)
            }
            ringColumn("Strain", tab: .activity) {
                HeroRing(progress: day.strain.map { $0 / 21 },
                         value: Fmt.decimal(day.strain),
                         color: Theme.strainRing, size: 108)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 22)
        .padding(.bottom, 8)
    }

    private func ringColumn<Ring: View>(_ title: String, tab: AppTab,
                                        @ViewBuilder ring: () -> Ring) -> some View {
        Button { goTo(tab) } label: {
            VStack(spacing: 14) {
                ring()
                HStack(spacing: 5) {
                    Text(title.uppercased())
                        .font(.system(size: 13, weight: .bold))
                        .tracking(1.4)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(Theme.textSecondary)
                }
                .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Detail cards

    private func recoveryCard(_ day: DaySummary) -> some View {
        let color = Theme.recoveryColor(day.recovery)
        return Button { goTo(.recovery) } label: {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Recovery", badge: recoveryLabel(day.recovery), badgeColor: color)
                MetricLine(label: "HRV", value: Fmt.whole(day.hrv), unit: "ms",
                           delta: Baseline.hrv(day.hrv, day.hrvBaseline),
                           baselineText: day.hrvBaseline.map { "avg \(Int($0.rounded()))" })
                HairlineDivider()
                MetricLine(label: "Resting HR", value: Fmt.whole(day.restingHR), unit: "bpm",
                           delta: Baseline.rhr(day.restingHR, day.rhrBaseline),
                           baselineText: day.rhrBaseline.map { "avg \(Int($0.rounded()))" })
            }
            .card()
        }
        .buttonStyle(PressableStyle())
    }

    private func recoveryLabel(_ score: Double?) -> String {
        guard let score = score else { return "Unavailable" }
        if score >= 70 { return "Primed" }
        if score >= 40 { return "Moderate" }
        return "Low"
    }

    private func strainCard(_ day: DaySummary) -> some View {
        let target = strainTarget(day.recovery)
        return Button { goTo(.activity) } label: {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Strain", badge: target.map { "Target \($0.lowerBound)-\($0.upperBound)" },
                             badgeColor: Theme.textSecondary)
                HStack {
                    MetricLine(label: "Calories", value: Fmt.thousands(day.activeEnergy), unit: "kcal")
                    Spacer(minLength: 12)
                    MetricLine(label: "Avg / Max HR",
                               value: "\(Fmt.whole(day.avgHR))/\(Fmt.whole(day.maxHR))", unit: "bpm")
                }
                ZoneBar(minutes: day.zoneMinutes)
            }
            .card()
        }
        .buttonStyle(PressableStyle())
    }

    private func strainTarget(_ recovery: Double?) -> ClosedRange<Int>? {
        guard let recovery = recovery else { return nil }
        if recovery >= 70 { return 14...18 }
        if recovery >= 40 { return 8...13 }
        return 0...8
    }

    private func sleepCard(_ day: DaySummary) -> some View {
        Button { goTo(.sleep) } label: {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Sleep", badge: day.sleep.map { "\(Fmt.duration($0.asleepMin)) asleep" },
                             badgeColor: Theme.textSecondary)
                HStack {
                    MetricLine(label: "Asleep / Needed",
                               value: "\(Fmt.duration(day.sleep?.asleepMin))/\(Fmt.duration(day.sleepNeedMin))")
                    Spacer(minLength: 12)
                    MetricLine(label: "Debt", value: Fmt.duration(day.sleepDebtMin),
                               valueColor: (day.sleepDebtMin ?? 0) >= 90 ? Theme.yellow : .white)
                    Spacer(minLength: 12)
                    MetricLine(label: "Consistency", value: Fmt.whole(day.sleepConsistency),
                               unit: day.sleepConsistency == nil ? "" : "%")
                }
                if let night = day.sleep, night.hasStages {
                    StageBar(night: night)
                }
            }
            .card()
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: More metrics

    private func moreMetrics(_ day: DaySummary) -> some View {
        VStack(spacing: 14) {
            MetricCard(title: "Steps",
                       value: day.steps.map { Fmt.thousands($0) },
                       detail: store.average(range: .week, value: { $0.steps })
                           .map { "7-day avg \(Fmt.thousands($0))" },
                       series: store.series(range: .week) { $0.steps },
                       color: Theme.blue, bars: true,
                       progress: day.steps.map { $0 / 10_000 })
            MetricCard(title: "HRV, 30 days",
                       value: day.hrv.map { Fmt.whole($0) }, unit: "ms",
                       detail: day.hrvBaseline.map { "Baseline \(Int($0.rounded())) ms" },
                       series: store.series(range: .month) { $0.hrv },
                       color: Theme.green)
            MetricCard(title: "Respiratory rate",
                       value: day.respiratoryRate.map { Fmt.decimal($0) }, unit: "rpm",
                       detail: day.respBaseline.map { "Baseline \(Fmt.decimal($0))" },
                       series: store.series(range: .month) { $0.respiratoryRate },
                       color: Theme.violet)
            MetricCard(title: "Recovery, 30 days",
                       value: day.recovery.map { Fmt.whole($0) }, unit: "%",
                       detail: store.average(range: .month, value: { $0.recovery })
                           .map { "30-day avg \(Int($0.rounded()))%" },
                       series: store.series(range: .month) { $0.recovery },
                       color: Theme.recoveryColor(day.recovery))
        }
    }

    // MARK: Pieces

    private func sectionTitle(_ title: String, badge: String?, badgeColor: Color) -> some View {
        HStack {
            Eyebrow(text: title, color: .white)
            Spacer()
            if let badge = badge {
                StatusBadge(text: badge, color: badgeColor)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("No data yet")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(.white)
            Text("Connect Apple Health from Profile, or switch on demo data to explore.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button("Open Profile") { goTo(.profile) }
                .buttonStyle(.borderedProminent)
        }
        .card(padding: 28)
    }
}

/// Slim stacked bar of sleep stages for the Home card.
struct StageBar: View {
    let night: SleepNight

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(night.segments) { segment in
                        Capsule()
                            .fill(Theme.stageColor(segment.stage))
                            .frame(width: max(geo.size.width * segment.minutes / max(night.asleepMin + night.awakeMin, 1) - 2, 2))
                    }
                }
            }
            .frame(height: 8)
            HStack {
                legend("Deep", night.deepMin, .deep)
                legend("REM", night.remMin, .rem)
                legend("Light", night.lightMin, .light)
                legend("Awake", night.awakeMin, .awake)
            }
        }
    }

    private func legend(_ name: String, _ minutes: Double, _ stage: SleepStage) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Circle().fill(Theme.stageColor(stage)).frame(width: 5, height: 5)
                Text(name.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.textSecondary)
            }
            Text(Fmt.duration(minutes))
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
    }
}
