import Foundation
import SwiftData

/// Raw measurements for one day, cached on the phone so the app opens instantly.
/// Scores are never stored: they are recalculated from these values every time,
/// so changing the algorithm or your profile updates your whole history.
@Model
final class DayRecord {
    @Attribute(.unique) var date: Date
    var hrv: Double?
    var restingHR: Double?
    var respiratoryRate: Double?
    var steps: Double?
    var activeEnergy: Double?
    var avgHR: Double?
    var maxHR: Double?
    var zoneMinutes: [Double]
    var sleepData: Data?

    init(date: Date) {
        self.date = date
        self.zoneMinutes = []
    }

    func apply(_ day: DaySummary) {
        hrv = day.hrv
        restingHR = day.restingHR
        respiratoryRate = day.respiratoryRate
        steps = day.steps
        activeEnergy = day.activeEnergy
        avgHR = day.avgHR
        maxHR = day.maxHR
        zoneMinutes = day.zoneMinutes
        if let sleep = day.sleep {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970
            sleepData = try? encoder.encode(sleep)
        } else {
            sleepData = nil
        }
    }

    var summary: DaySummary {
        var day = DaySummary(date: date)
        day.hrv = hrv
        day.restingHR = restingHR
        day.respiratoryRate = respiratoryRate
        day.steps = steps
        day.activeEnergy = activeEnergy
        day.avgHR = avgHR
        day.maxHR = maxHR
        day.zoneMinutes = zoneMinutes
        if let data = sleepData {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            day.sleep = try? decoder.decode(SleepNight.self, from: data)
        }
        return day
    }
}

@Model
final class WorkoutRecord {
    @Attribute(.unique) var key: String
    var name: String
    var start: Date
    var durationMin: Double
    var energy: Double?
    var avgHR: Double?
    var maxHR: Double?
    var strain: Double?

    init(_ workout: WorkoutSummary) {
        self.key = "\(Int(workout.start.timeIntervalSince1970))-\(workout.name)"
        self.name = workout.name
        self.start = workout.start
        self.durationMin = workout.durationMin
        self.energy = workout.energy
        self.avgHR = workout.avgHR
        self.maxHR = workout.maxHR
        self.strain = workout.strain
    }

    var summary: WorkoutSummary {
        WorkoutSummary(id: UUID(), name: name, start: start, durationMin: durationMin,
                       energy: energy, avgHR: avgHR, maxHR: maxHR, strain: strain)
    }
}
