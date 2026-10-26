import Foundation
import SwiftData
import SwiftUI
import Observation

/// Single source of truth for the UI. Holds either demo data or the user's Apple Health data,
/// never a mix of the two.
@Observable
@MainActor
final class AppStore {
    static let historyDays = 118          // 90 days shown plus 28 for baselines

    private(set) var days: [DaySummary] = []           // oldest first
    private(set) var workouts: [WorkoutSummary] = []   // newest first
    private(set) var isDemo: Bool = Settings.useDemo
    private(set) var isSyncing = false
    private(set) var lastSync: Date?
    private(set) var statusMessage: String?

    /// Bump to make views re-read profile-dependent values after Profile edits.
    private(set) var profileRevision = 0

    private var context: ModelContext?
    private let health = HealthService()

    var today: DaySummary? { days.last }
    var healthAvailable: Bool { health.isAvailable }

    // MARK: Setup

    func attach(_ context: ModelContext) {
        guard self.context == nil else { return }
        self.context = context
        reload()
        if !isDemo { Task { await sync(full: days.isEmpty) } }
    }

    // MARK: Loading

    func reload() {
        let profile = Settings.profile
        if isDemo {
            let demo = DemoData.generate(profile: profile)
            days = demo.days
            workouts = demo.workouts
            return
        }
        guard let context = context else { return }
        let dayRecords = (try? context.fetch(FetchDescriptor<DayRecord>(sortBy: [SortDescriptor(\.date)]))) ?? []
        let workoutRecords = (try? context.fetch(FetchDescriptor<WorkoutRecord>(sortBy: [SortDescriptor(\.start, order: .reverse)]))) ?? []
        days = ScoringEngine.finalize(dayRecords.map { $0.summary }, profile: profile)
        workouts = workoutRecords.map { $0.summary }
    }

    func setDemo(_ enabled: Bool) {
        Settings.useDemo = enabled
        isDemo = enabled
        statusMessage = nil
        reload()
        if !enabled { Task { await sync(full: days.isEmpty) } }
    }

    /// Called after name, age, max HR or sleep need change.
    func profileChanged() {
        profileRevision += 1
        reload()
        if !isDemo { Task { await sync(full: true) } }
    }

    // MARK: Apple Health

    func connectHealth() async {
        guard health.isAvailable else {
            statusMessage = "Health data isn't available on this device."
            return
        }
        do {
            try await health.requestAuthorization()
            Settings.healthRequested = true
            setDemo(false)
        } catch {
            statusMessage = "Couldn't request Health access: \(error.localizedDescription)"
        }
    }

    func sync(full: Bool) async {
        guard !isDemo, !isSyncing, let context = context else { return }
        isSyncing = true
        statusMessage = nil
        defer { isSyncing = false }

        let profile = Settings.profile
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let count = full ? Self.historyDays : 3

        for offset in stride(from: count - 1, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let fetched = await health.fetchDay(date, profile: profile)

            let existing = (try? context.fetch(FetchDescriptor<DayRecord>(predicate: #Predicate { $0.date == date })))?.first
            let record = existing ?? DayRecord(date: date)
            record.apply(fetched)
            if existing == nil { context.insert(record) }

            // Show progress as the history fills in
            if full && offset % 20 == 0 {
                try? context.save()
                reload()
            }
        }

        let since = calendar.date(byAdding: .day, value: -(count - 1), to: today) ?? today
        let fetchedWorkouts = await health.fetchWorkouts(since: since, profile: profile)
        for workout in fetchedWorkouts {
            let record = WorkoutRecord(workout)
            let key = record.key
            let exists = ((try? context.fetch(FetchDescriptor<WorkoutRecord>(predicate: #Predicate { $0.key == key })))?.first) != nil
            if !exists { context.insert(record) }
        }

        try? context.save()
        lastSync = Date()
        reload()

        if days.allSatisfy({ $0.hrv == nil && $0.restingHR == nil && $0.sleep == nil && $0.steps == nil }) {
            statusMessage = "No Health data found. In Settings > Health > Data Access & Devices > Noop, make sure categories are turned on."
        }
    }

    func clearLocalData() {
        guard let context = context else { return }
        try? context.delete(model: DayRecord.self)
        try? context.delete(model: WorkoutRecord.self)
        try? context.save()
        reload()
    }

    // MARK: Helpers for views

    func day(before date: Date, offset: Int) -> DaySummary? {
        guard let index = days.firstIndex(where: { $0.date == date }) else { return nil }
        let target = index + offset
        return days.indices.contains(target) ? days[target] : nil
    }

    func history(upTo date: Date) -> [DaySummary] {
        days.filter { $0.date <= date }
    }

    func workouts(on date: Date) -> [WorkoutSummary] {
        let calendar = Calendar.current
        return workouts.filter { calendar.isDate($0.start, inSameDayAs: date) }
    }

    /// Days that actually have a value, newest `range` days only.
    func series(range: TrendRange,
                value: (DaySummary) -> Double?,
                tint: ((Double) -> Color)? = nil) -> [TrendPoint] {
        days.suffix(range.rawValue).compactMap { day in
            guard let v = value(day) else { return nil }
            return TrendPoint(date: day.date, value: v, tint: tint?(v))
        }
    }

    func average(range: TrendRange, value: (DaySummary) -> Double?) -> Double? {
        let values = days.suffix(range.rawValue).compactMap(value)
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
}
