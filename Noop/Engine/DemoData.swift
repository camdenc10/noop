import Foundation

/// Small deterministic random generator so demo data looks the same on every launch.
struct SeededRNG: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    /// 0..<1
    mutating func unit() -> Double {
        Double(next() >> 11) / 9007199254740992.0
    }

    /// Roughly bell shaped, -1...1
    mutating func centered() -> Double {
        let a = unit()
        let b = unit()
        let c = unit()
        return (a + b + c - 1.5) / 1.5
    }

    mutating func range(_ low: Double, _ high: Double) -> Double {
        low + unit() * (high - low)
    }
}

/// Realistic demo numbers for the first launch and for screenshots.
/// Shown with a DEMO badge in the app and never mixed with real Health data.
enum DemoData {

    static func generate(profile: ScoringProfile,
                         now: Date = Date(),
                         dayCount: Int = 118) -> (days: [DaySummary], workouts: [WorkoutSummary]) {
        var rng = SeededRNG(state: 0xA11CE5EED)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let elapsed = min(max(now.timeIntervalSince(today) / 3600 / 21, 0.15), 1)

        var days: [DaySummary] = []
        var workouts: [WorkoutSummary] = []
        var previousStrain = 10.0
        let workoutNames = ["Run", "Strength", "Cycling", "HIIT"]

        for offset in stride(from: dayCount - 1, through: 0, by: -1) {
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            let index = dayCount - 1 - offset
            let weekday = calendar.component(.weekday, from: date)
            let isToday = offset == 0
            let trains = [2, 3, 5, 7].contains(weekday) || rng.unit() < 0.08

            // Heart rate zones for the day
            var zones: [Double]
            if trains {
                zones = [rng.range(55, 85), rng.range(25, 45), rng.range(10, 24), rng.range(3, 12), rng.range(0, 4)]
            } else {
                zones = [rng.range(35, 70), rng.range(3, 16), rng.range(0, 5), rng.range(0, 2), 0]
            }
            if isToday { zones = zones.map { $0 * elapsed } }
            let strain = ScoringEngine.strain(zoneMinutes: zones) ?? 0

            // Overnight physiology reacts to the previous day's strain
            let wave = 5.5 * sin(Double(index) / 8.5)
            let hrv = 63 + wave - 0.9 * (previousStrain - 10) + rng.centered() * 5
            let rhr = 51 + 0.35 * (previousStrain - 10) - (hrv - 63) * 0.04 + rng.centered() * 1.4
            let respiratory = 14.9 + rng.centered() * 0.45 + max(0, previousStrain - 13) * 0.08

            // Sleep
            let asleep = ScoringEngine.clamp(475 + 24 * sin(Double(index) / 5.5)
                                             - 7 * max(0, previousStrain - 12)
                                             + rng.centered() * 38, 330, 540)
            let awake = rng.range(22, 48)
            let deep = asleep * rng.range(0.16, 0.21)
            let rem = asleep * rng.range(0.21, 0.26)
            let light = asleep - deep - rem
            let bedtimeShift = Int(-85 + rng.centered() * 50)
            let bedtime = calendar.date(byAdding: .minute, value: bedtimeShift, to: date)!
            let segments = makeSegments(bedtime: bedtime, light: light, deep: deep, rem: rem, awake: awake)

            var day = DaySummary(date: date)
            day.hrv = hrv
            day.restingHR = rhr
            day.respiratoryRate = respiratory
            day.zoneMinutes = zones
            if let first = segments.first, let last = segments.last {
                day.sleep = SleepNight(onset: first.start, wake: last.end,
                                       asleepMin: asleep, awakeMin: awake,
                                       lightMin: light, deepMin: deep, remMin: rem,
                                       segments: segments)
            }

            // Activity
            let stepBase = trains ? rng.range(9200, 14200) : rng.range(4300, 9300)
            let steps = (stepBase * (isToday ? elapsed : 1)).rounded()
            day.steps = steps
            day.activeEnergy = (steps * 0.042 + strain * 31 + rng.range(-20, 20)).rounded()
            day.avgHR = 66 + strain * 1.5
            day.maxHR = min(profile.maxHR - 2, 118 + strain * 4.6 + rng.centered() * 4)
            days.append(day)

            // One workout on training days
            if trains && (!isToday || elapsed >= 0.45) {
                let name = workoutNames[(index + weekday) % workoutNames.count]
                let duration = rng.range(34, 74).rounded()
                let hour = rng.unit() < 0.5 ? 6.5 : 17.5
                let start = date.addingTimeInterval(hour * 3600)
                let workoutStrain = ScoringEngine.clamp(strain - 3.2 + rng.centered() * 1.2, 4, 19)
                workouts.append(WorkoutSummary(id: UUID(),
                                               name: name,
                                               start: start,
                                               durationMin: duration,
                                               energy: (duration * (6.5 + workoutStrain * 0.45)).rounded(),
                                               avgHR: (118 + workoutStrain * 3.4).rounded(),
                                               maxHR: min(profile.maxHR - 1, 140 + workoutStrain * 3.6).rounded(),
                                               strain: workoutStrain))
            }
            previousStrain = strain
        }

        let finalized = ScoringEngine.finalize(days, profile: profile)
        return (finalized, workouts.sorted { $0.start > $1.start })
    }

    /// Five sleep cycles: light, deep, light, REM, with short awake periods in between.
    private static func makeSegments(bedtime: Date, light: Double, deep: Double, rem: Double, awake: Double) -> [SleepSegment] {
        let deepWeights: [Double] = [0.38, 0.30, 0.18, 0.10, 0.04]
        let remWeights: [Double] = [0.07, 0.14, 0.21, 0.28, 0.30]
        let awakeWeights: [Double] = [0.0, 0.25, 0.20, 0.15, 0.40]

        var segments: [SleepSegment] = []
        var cursor = bedtime

        func add(_ stage: SleepStage, _ minutes: Double) {
            guard minutes >= 0.5 else { return }
            let end = cursor.addingTimeInterval(minutes * 60)
            segments.append(SleepSegment(stage: stage, start: cursor, end: end))
            cursor = end
        }

        for cycle in 0..<5 {
            add(.awake, awake * awakeWeights[cycle])
            let lightPerCycle = light / 5
            add(.light, lightPerCycle * 0.55)
            add(.deep, deep * deepWeights[cycle])
            add(.light, lightPerCycle * 0.45)
            add(.rem, rem * remWeights[cycle])
        }
        return segments
    }
}
