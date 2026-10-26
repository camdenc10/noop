import Foundation

struct ScoringProfile {
    var maxHR: Double
    var baseSleepNeedMin: Double
}

enum InsightTone {
    case positive, caution, warning, neutral
}

struct Insight: Identifiable {
    let id = UUID()
    var title: String
    var body: String
    var tone: InsightTone
}

/// Every number the app calculates comes from this file. The same constants are shown
/// to the user on the "How scores work" screen.
enum ScoringEngine {

    // MARK: Constants

    static let baselineWindowDays = 28
    static let minBaselineDays = 5

    static let weightHRV = 0.50
    static let weightRHR = 0.25
    static let weightSleep = 0.20
    static let weightResp = 0.05

    /// Lower edge of each heart rate zone as a share of max heart rate.
    static let zoneLowerBounds: [Double] = [0.50, 0.60, 0.70, 0.80, 0.90]
    /// Load points per minute in each zone.
    static let zoneWeights: [Double] = [1, 2, 3, 4, 5]
    static let strainScale = 250.0

    static func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
        min(max(value, low), high)
    }

    private static func mean(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    private static func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1, let average = mean(values) else { return 0 }
        let variance = values.reduce(0) { $0 + ($1 - average) * ($1 - average) } / Double(values.count)
        return variance.squareRoot()
    }

    // MARK: Heart rate zones and strain

    struct HRAnalysis {
        var zoneMinutes: [Double]
        var average: Double
        var maximum: Double
    }

    /// Needs at least 20 readings in the window, otherwise the day has no strain.
    static func analyze(samples: [(date: Date, bpm: Double)], maxHR: Double) -> HRAnalysis? {
        guard samples.count >= 20, maxHR > 0 else { return nil }
        var zones = [Double](repeating: 0, count: 5)
        for i in 0..<(samples.count - 1) {
            let gap = min(max(samples[i + 1].date.timeIntervalSince(samples[i].date), 0), 300) / 60
            if let z = zone(for: samples[i].bpm, maxHR: maxHR) {
                zones[z] += gap
            }
        }
        let values = samples.map { $0.bpm }
        return HRAnalysis(zoneMinutes: zones,
                          average: values.reduce(0, +) / Double(values.count),
                          maximum: values.max() ?? 0)
    }

    /// Zone index 0...4 for Z1...Z5, or nil below 50% of max heart rate.
    static func zone(for bpm: Double, maxHR: Double) -> Int? {
        guard maxHR > 0 else { return nil }
        let fraction = bpm / maxHR
        for z in stride(from: 4, through: 0, by: -1) where fraction >= zoneLowerBounds[z] {
            return z
        }
        return nil
    }

    static func load(zoneMinutes: [Double]) -> Double {
        zip(zoneMinutes, zoneWeights).reduce(0) { $0 + $1.0 * $1.1 }
    }

    /// 0...21, flattening toward the top so extreme days don't run off the scale.
    static func strain(zoneMinutes: [Double]) -> Double? {
        guard zoneMinutes.count == 5 else { return nil }
        return 21 * (1 - exp(-load(zoneMinutes: zoneMinutes) / strainScale))
    }

    static func zoneRange(_ index: Int, maxHR: Double) -> String {
        let low = Int((zoneLowerBounds[index] * maxHR).rounded())
        if index == 4 { return "\(low)+ bpm" }
        let high = Int((zoneLowerBounds[index + 1] * maxHR).rounded()) - 1
        return "\(low)-\(high) bpm"
    }

    // MARK: Sleep

    static func sleepNeed(base: Double, previousStrain: Double?, recentDeficit: Double) -> Double {
        var need = base
        if let strain = previousStrain {
            need += clamp((strain - 10) * 6, 0, 60)
        }
        need += clamp(recentDeficit * 0.2, 0, 60)
        return need
    }

    // MARK: Recovery

    static func recovery(hrv: Double?, restingHR: Double?, respiratory: Double?, sleepPerformance: Double?,
                         hrvBase: Double?, rhrBase: Double?, respBase: Double?) -> (score: Double, parts: [RecoveryPart])? {
        var parts: [(name: String, score: Double, weight: Double, detail: String)] = []

        if let hrv = hrv, let base = hrvBase, base > 0 {
            let score = clamp(50 + 150 * (hrv / base - 1), 0, 100)
            parts.append(("HRV", score, weightHRV,
                          "\(Int(hrv.rounded())) ms vs \(Int(base.rounded())) baseline"))
        }
        if let rhr = restingHR, let base = rhrBase {
            let score = clamp(50 + 8 * (base - rhr), 0, 100)
            parts.append(("Resting HR", score, weightRHR,
                          "\(Int(rhr.rounded())) bpm vs \(Int(base.rounded())) baseline"))
        }
        if let sleep = sleepPerformance {
            parts.append(("Sleep", clamp(sleep, 0, 100), weightSleep,
                          "\(Int(sleep.rounded()))% sleep performance"))
        }
        if let rate = respiratory, let base = respBase {
            let score = clamp(50 + 40 * (base - rate), 0, 100)
            parts.append(("Respiration", score, weightResp,
                          String(format: "%.1f vs %.1f baseline", rate, base)))
        }

        let hasCoreSignal = parts.contains { $0.name == "HRV" || $0.name == "Resting HR" }
        let totalWeight = parts.reduce(0) { $0 + $1.weight }
        guard hasCoreSignal, totalWeight > 0 else { return nil }

        let result = parts.map {
            RecoveryPart(name: $0.name, score: $0.score, weight: $0.weight / totalWeight, detail: $0.detail)
        }
        let score = result.reduce(0) { $0 + $1.score * $1.weight }
        return (score, result)
    }

    // MARK: Full pass

    private struct NightLog {
        var date: Date
        var need: Double
        var asleep: Double
        var onsetShifted: Double     // minutes, 18:00 = 1080, wraps past midnight
        var wakeMinutes: Double
    }

    /// Fills in every derived field. Days are processed oldest first so baselines only
    /// use what came before each day.
    static func finalize(_ raw: [DaySummary], profile: ScoringProfile) -> [DaySummary] {
        var days = raw.sorted { $0.date < $1.date }
        var log: [NightLog] = []
        let calendar = Calendar.current

        for i in days.indices {
            // Baselines from up to 28 previous days
            let history = days[max(0, i - baselineWindowDays)..<i]
            func baseline(_ values: [Double]) -> Double? {
                values.count >= minBaselineDays ? mean(values) : nil
            }
            days[i].hrvBaseline = baseline(history.compactMap { $0.hrv })
            days[i].rhrBaseline = baseline(history.compactMap { $0.restingHR })
            days[i].respBaseline = baseline(history.compactMap { $0.respiratoryRate })

            // Strain
            if !days[i].zoneMinutes.isEmpty {
                days[i].strain = strain(zoneMinutes: days[i].zoneMinutes)
            }

            // Sleep
            if let night = days[i].sleep {
                let date = days[i].date
                let previousStrain = i > 0 ? days[i - 1].strain : nil
                let recentDeficit = log
                    .filter { date.timeIntervalSince($0.date) <= 3 * 86_400 && $0.date < date }
                    .reduce(0) { $0 + max(0, $1.need - $1.asleep) }
                let need = sleepNeed(base: profile.baseSleepNeedMin,
                                     previousStrain: previousStrain,
                                     recentDeficit: recentDeficit)
                days[i].sleepNeedMin = need
                days[i].sleepPerformance = min(night.asleepMin / need, 1) * 100

                let onset = calendar.dateComponents([.hour, .minute], from: night.onset)
                var onsetMinutes = Double((onset.hour ?? 0) * 60 + (onset.minute ?? 0))
                if onsetMinutes < 18 * 60 { onsetMinutes += 1440 }
                let wake = calendar.dateComponents([.hour, .minute], from: night.wake)
                let wakeMinutes = Double((wake.hour ?? 0) * 60 + (wake.minute ?? 0))
                log.append(NightLog(date: date, need: need, asleep: night.asleepMin,
                                    onsetShifted: onsetMinutes, wakeMinutes: wakeMinutes))

                // 7-night debt: shortfalls minus surpluses, never below zero
                let week = log.filter { date.timeIntervalSince($0.date) < 7 * 86_400 }
                days[i].sleepDebtMin = max(0, week.reduce(0) { $0 + ($1.need - $1.asleep) })

                // Consistency: spread of bedtime and wake time over the last 5 nights
                let recent = log.filter { date.timeIntervalSince($0.date) < 5 * 86_400 }
                if recent.count >= 3 {
                    let spread = (standardDeviation(recent.map { $0.onsetShifted })
                                  + standardDeviation(recent.map { $0.wakeMinutes })) / 2
                    days[i].sleepConsistency = clamp(100 - spread * (100.0 / 90.0), 0, 100)
                }
            }

            // Recovery
            if let result = recovery(hrv: days[i].hrv,
                                     restingHR: days[i].restingHR,
                                     respiratory: days[i].respiratoryRate,
                                     sleepPerformance: days[i].sleepPerformance,
                                     hrvBase: days[i].hrvBaseline,
                                     rhrBase: days[i].rhrBaseline,
                                     respBase: days[i].respBaseline) {
                days[i].recovery = result.score
                days[i].recoveryParts = result.parts
            }
        }
        return days
    }

    // MARK: Insights

    static func insights(for day: DaySummary, history: [DaySummary]) -> [Insight] {
        var items: [Insight] = []

        guard let recovery = day.recovery else {
            items.append(Insight(title: "Recovery unavailable",
                                 body: "A score needs overnight HRV or resting heart rate, plus at least \(minBaselineDays) days of history to compare against.",
                                 tone: .neutral))
            return items
        }

        if let hrv = day.hrv, let base = day.hrvBaseline, base > 0 {
            let pct = (hrv / base - 1) * 100
            if pct >= 8 {
                items.append(Insight(title: "HRV is up \(Int(pct.rounded()))%",
                                     body: "Overnight HRV is above your \(baselineWindowDays)-day baseline, a sign your nervous system has recovered well.",
                                     tone: .positive))
            } else if pct <= -12 {
                items.append(Insight(title: "HRV is down \(Int(abs(pct).rounded()))%",
                                     body: "Overnight HRV is well below your baseline. Stress, illness, alcohol and hard training can all do this.",
                                     tone: .warning))
            }
        }

        if let rhr = day.restingHR, let base = day.rhrBaseline {
            let diff = rhr - base
            if diff >= 3 {
                items.append(Insight(title: "Resting heart rate is elevated",
                                     body: "\(Int(diff.rounded())) bpm above your baseline. Your body may still be working to recover.",
                                     tone: .caution))
            } else if diff <= -2 {
                items.append(Insight(title: "Resting heart rate is low",
                                     body: "\(Int(abs(diff).rounded())) bpm below your baseline, which usually goes with good recovery.",
                                     tone: .positive))
            }
        }

        if let debt = day.sleepDebtMin, debt >= 90 {
            let hours = Int(debt) / 60
            let minutes = Int(debt) % 60
            items.append(Insight(title: "Sleep debt is building",
                                 body: "You're about \(hours)h \(minutes)m short over the last week. An earlier night would help more than any other single change.",
                                 tone: .caution))
        }

        if let consistency = day.sleepConsistency, consistency < 70 {
            items.append(Insight(title: "Irregular sleep schedule",
                                 body: "Your bedtime and wake time have varied a lot recently. A steadier schedule tends to lift recovery.",
                                 tone: .caution))
        }

        let effort: String
        let tone: InsightTone
        if recovery >= 70 {
            effort = "You're primed for a hard session. A strain of 14 to 18 is a reasonable target."
            tone = .positive
        } else if recovery >= 40 {
            effort = "Aim for moderate effort today, roughly a strain of 8 to 13."
            tone = .neutral
        } else {
            effort = "Keep today light, under a strain of 8, and protect tonight's sleep."
            tone = .warning
        }
        items.append(Insight(title: "Suggested effort", body: effort, tone: tone))

        return Array(items.prefix(4))
    }
}
