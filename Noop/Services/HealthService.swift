import Foundation
import HealthKit

/// Reads Apple Health. Read-only: Noop never writes to Health.
/// Anything Health cannot provide comes back as nil, never as a made-up number.
final class HealthService {
    private let store = HKHealthStore()
    private let calendar = Calendar.current

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType()]
        let quantities: [HKQuantityTypeIdentifier] = [
            .heartRate, .heartRateVariabilitySDNN, .restingHeartRate,
            .respiratoryRate, .stepCount, .activeEnergyBurned
        ]
        for id in quantities {
            if let type = HKQuantityType.quantityType(forIdentifier: id) { types.insert(type) }
        }
        if let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(sleep) }
        return types
    }

    func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    // MARK: Day

    /// Collects one calendar day. Overnight metrics (HRV, respiration, sleep) belong to
    /// the day you woke up on.
    func fetchDay(_ date: Date, profile: ScoringProfile) async -> DaySummary {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = min(calendar.date(byAdding: .day, value: 1, to: dayStart)!, Date())
        let nightStart = calendar.date(byAdding: .hour, value: -6, to: dayStart)!   // 18:00 the evening before
        let nightEnd = calendar.date(byAdding: .hour, value: 15, to: dayStart)!     // 15:00

        var day = DaySummary(date: dayStart)

        async let sleep = fetchSleep(from: nightStart, to: min(nightEnd, Date()))
        async let steps = sum(.stepCount, unit: .count(), from: dayStart, to: dayEnd)
        async let energy = sum(.activeEnergyBurned, unit: .kilocalorie(), from: dayStart, to: dayEnd)
        async let resting = average(.restingHeartRate, unit: bpmUnit, from: dayStart, to: dayEnd)
        async let samples = heartRateSamples(from: dayStart, to: dayEnd)

        let night = await sleep
        day.sleep = night
        day.steps = await steps
        day.activeEnergy = await energy
        day.restingHR = await resting

        // Overnight window: asleep period when known, otherwise midnight to 9am
        let overnightStart = night?.onset ?? dayStart
        let overnightEnd = night?.wake ?? min(calendar.date(byAdding: .hour, value: 9, to: dayStart)!, dayEnd)
        if overnightEnd > overnightStart {
            day.hrv = await average(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli),
                                    from: overnightStart, to: overnightEnd)
            day.respiratoryRate = await average(.respiratoryRate, unit: bpmUnit,
                                                from: overnightStart, to: overnightEnd)
        }

        if let analysis = ScoringEngine.analyze(samples: await samples, maxHR: profile.maxHR) {
            day.zoneMinutes = analysis.zoneMinutes
            day.avgHR = analysis.average
            day.maxHR = analysis.maximum
        }
        return day
    }

    // MARK: Quantities

    private var bpmUnit: HKUnit { HKUnit.count().unitDivided(by: .minute()) }

    private func quantityType(_ id: HKQuantityTypeIdentifier) -> HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: id)
    }

    private func statistic(_ id: HKQuantityTypeIdentifier, options: HKStatisticsOptions,
                           from: Date, to: Date) async -> HKStatistics? {
        guard let type = quantityType(id), to > from else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate,
                                          options: options) { _, result, _ in
                continuation.resume(returning: result)
            }
            store.execute(query)
        }
    }

    private func sum(_ id: HKQuantityTypeIdentifier, unit: HKUnit, from: Date, to: Date) async -> Double? {
        let result = await statistic(id, options: .cumulativeSum, from: from, to: to)
        return result?.sumQuantity()?.doubleValue(for: unit)
    }

    private func average(_ id: HKQuantityTypeIdentifier, unit: HKUnit, from: Date, to: Date) async -> Double? {
        let result = await statistic(id, options: .discreteAverage, from: from, to: to)
        return result?.averageQuantity()?.doubleValue(for: unit)
    }

    private func heartRateSamples(from: Date, to: Date) async -> [(date: Date, bpm: Double)] {
        guard let type = quantityType(.heartRate), to > from else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: .strictStartDate)
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        let unit = bpmUnit
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate,
                                      limit: HKObjectQueryNoLimit, sortDescriptors: sort) { _, results, _ in
                let points = (results as? [HKQuantitySample] ?? []).map {
                    (date: $0.startDate, bpm: $0.quantity.doubleValue(for: unit))
                }
                continuation.resume(returning: points)
            }
            store.execute(query)
        }
    }

    // MARK: Sleep

    private func fetchSleep(from: Date, to: Date) async -> SleepNight? {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis), to > from else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: [])
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        let samples: [HKCategorySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate,
                                      limit: HKObjectQueryNoLimit, sortDescriptors: sort) { _, results, _ in
                continuation.resume(returning: results as? [HKCategorySample] ?? [])
            }
            store.execute(query)
        }
        return Self.buildNight(from: samples)
    }

    private static func stage(for value: Int) -> SleepStage? {
        switch HKCategoryValueSleepAnalysis(rawValue: value) {
        case .awake: return .awake
        case .asleepREM: return .rem
        case .asleepDeep: return .deep
        case .asleepCore: return .light
        case .asleepUnspecified: return .light
        default: return nil          // "in bed" is ignored
        }
    }

    /// Picks the one source that best describes the night (stages beat plain "asleep",
    /// then the longest) so two devices never double count.
    static func buildNight(from samples: [HKCategorySample]) -> SleepNight? {
        let grouped = Dictionary(grouping: samples) { $0.sourceRevision.source.bundleIdentifier }
        var best: (score: Double, samples: [HKCategorySample])?

        for (_, group) in grouped {
            var asleep = 0.0
            var hasStages = false
            for sample in group {
                guard let stage = stage(for: sample.value) else { continue }
                if stage == .awake { continue }
                asleep += sample.endDate.timeIntervalSince(sample.startDate) / 60
                if sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                    sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                    sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue {
                    hasStages = true
                }
            }
            let score = asleep + (hasStages ? 10_000 : 0)
            if asleep > 0, best == nil || score > best!.score { best = (score, group) }
        }
        guard let chosen = best?.samples else { return nil }

        let ordered = chosen
            .compactMap { sample -> SleepSegment? in
                guard let stage = stage(for: sample.value) else { return nil }
                return SleepSegment(stage: stage, start: sample.startDate, end: sample.endDate)
            }
            .sorted { $0.start < $1.start }

        let asleepSegments = ordered.filter { $0.stage != .awake }
        guard let first = asleepSegments.first, let last = asleepSegments.last else { return nil }

        // Trim leading/trailing awake periods and clip overlaps
        var segments: [SleepSegment] = []
        var cursor = first.start
        for segment in ordered where segment.end > first.start && segment.start < last.end {
            let start = max(segment.start, cursor)
            let end = min(segment.end, last.end)
            guard end > start else { continue }
            segments.append(SleepSegment(stage: segment.stage, start: start, end: end))
            cursor = end
        }

        func total(_ stage: SleepStage) -> Double {
            segments.filter { $0.stage == stage }.reduce(0) { $0 + $1.minutes }
        }
        let light = total(.light), deep = total(.deep), rem = total(.rem), awake = total(.awake)
        let hasStages = deep + rem > 0

        return SleepNight(onset: first.start, wake: last.end,
                          asleepMin: light + deep + rem, awakeMin: awake,
                          lightMin: hasStages ? light : 0, deepMin: deep, remMin: rem,
                          segments: hasStages ? segments : [])
    }

    // MARK: Workouts

    func fetchWorkouts(since: Date, profile: ScoringProfile) async -> [WorkoutSummary] {
        let predicate = HKQuery.predicateForSamples(withStart: since, end: Date(), options: .strictStartDate)
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        let workouts: [HKWorkout] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate,
                                      limit: HKObjectQueryNoLimit, sortDescriptors: sort) { _, results, _ in
                continuation.resume(returning: results as? [HKWorkout] ?? [])
            }
            store.execute(query)
        }

        var output: [WorkoutSummary] = []
        for workout in workouts {
            let samples = await heartRateSamples(from: workout.startDate, to: workout.endDate)
            let analysis = ScoringEngine.analyze(samples: samples, maxHR: profile.maxHR)
            let energy = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
                .sumQuantity()?.doubleValue(for: .kilocalorie())
            output.append(WorkoutSummary(id: workout.uuid,
                                         name: Self.name(for: workout.workoutActivityType),
                                         start: workout.startDate,
                                         durationMin: workout.duration / 60,
                                         energy: energy,
                                         avgHR: analysis?.average,
                                         maxHR: analysis?.maximum,
                                         strain: analysis.flatMap { ScoringEngine.strain(zoneMinutes: $0.zoneMinutes) }))
        }
        return output
    }

    static func name(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Run"
        case .walking: return "Walk"
        case .cycling: return "Cycling"
        case .swimming: return "Swim"
        case .hiking: return "Hike"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining, .traditionalStrengthTraining: return "Strength"
        case .highIntensityIntervalTraining: return "HIIT"
        case .rowing: return "Rowing"
        case .elliptical: return "Elliptical"
        case .coreTraining: return "Core"
        case .pilates: return "Pilates"
        case .soccer: return "Soccer"
        case .basketball: return "Basketball"
        case .tennis: return "Tennis"
        default: return "Workout"
        }
    }
}
