import Foundation

// MARK: - Sleep

enum SleepStage: String, Codable, CaseIterable, Hashable {
    case awake = "Awake"
    case rem = "REM"
    case light = "Light"
    case deep = "Deep"
}

struct SleepSegment: Codable, Hashable, Identifiable {
    var stage: SleepStage
    var start: Date
    var end: Date

    var id: Date { start }
    var minutes: Double { end.timeIntervalSince(start) / 60 }
}

struct SleepNight: Codable, Hashable {
    var onset: Date
    var wake: Date
    var asleepMin: Double
    var awakeMin: Double
    var lightMin: Double
    var deepMin: Double
    var remMin: Double
    var segments: [SleepSegment]

    /// Time between falling asleep and waking, asleep plus awake.
    var inBedMin: Double { asleepMin + awakeMin }

    /// False when the data source only reports "asleep" without stages.
    var hasStages: Bool { !segments.isEmpty && (lightMin + deepMin + remMin) > 0 }

    var efficiency: Double? {
        inBedMin > 0 ? min(asleepMin / inBedMin, 1) * 100 : nil
    }
}

// MARK: - Recovery

struct RecoveryPart: Hashable, Identifiable {
    var name: String
    var score: Double       // 0...100
    var weight: Double      // share of the final score, 0...1
    var detail: String
    var id: String { name }
}

// MARK: - Day

/// Everything known about one calendar day. A nil value always means "not available",
/// never a guess.
struct DaySummary: Identifiable, Hashable {
    var date: Date                       // start of the day (the day you woke up)
    var id: Date { date }

    // Raw measurements
    var hrv: Double?                     // ms, SDNN overnight average
    var restingHR: Double?               // bpm
    var respiratoryRate: Double?         // breaths per minute, overnight average
    var steps: Double?
    var activeEnergy: Double?            // kcal
    var avgHR: Double?                   // bpm
    var maxHR: Double?                   // bpm
    var zoneMinutes: [Double] = []       // five heart rate zones, empty when unavailable
    var sleep: SleepNight?

    // Derived by ScoringEngine
    var recovery: Double?                // 0...100
    var strain: Double?                  // 0...21
    var sleepNeedMin: Double?
    var sleepPerformance: Double?        // 0...100
    var sleepDebtMin: Double?            // rolling 7 nights
    var sleepConsistency: Double?        // 0...100
    var hrvBaseline: Double?
    var rhrBaseline: Double?
    var respBaseline: Double?
    var recoveryParts: [RecoveryPart] = []

    init(date: Date) {
        self.date = date
    }

    var zoneTotal: Double { zoneMinutes.reduce(0, +) }
}

// MARK: - Workouts

struct WorkoutSummary: Identifiable, Hashable {
    var id: UUID
    var name: String
    var start: Date
    var durationMin: Double
    var energy: Double?
    var avgHR: Double?
    var maxHR: Double?
    var strain: Double?
}

// MARK: - Ranges and tabs

enum TrendRange: Int, CaseIterable, Identifiable {
    case week = 7
    case month = 30
    case quarter = 90

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .week: return "7D"
        case .month: return "30D"
        case .quarter: return "90D"
        }
    }
}

enum AppTab: Int, CaseIterable, Identifiable {
    case home, recovery, sleep, activity, profile

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .recovery: return "Recovery"
        case .sleep: return "Sleep"
        case .activity: return "Activity"
        case .profile: return "Profile"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "square.grid.2x2"
        case .recovery: return "waveform.path.ecg"
        case .sleep: return "moon.stars"
        case .activity: return "flame"
        case .profile: return "person.crop.circle"
        }
    }
}
