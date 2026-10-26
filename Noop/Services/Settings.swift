import Foundation

/// Local preferences. Everything lives in UserDefaults on this phone.
enum Settings {
    static let nameKey = "profileName"
    static let ageKey = "profileAge"
    static let maxHRKey = "maxHROverride"      // 0 means "estimate from age"
    static let needKey = "sleepNeedHours"
    static let demoKey = "useDemoData"
    static let requestedKey = "healthRequested"

    private static var defaults: UserDefaults { .standard }

    static var age: Int {
        let value = defaults.integer(forKey: ageKey)
        return value == 0 ? 30 : value
    }

    /// Tanaka estimate unless the user has set their own number.
    static var maxHR: Double {
        let override = defaults.integer(forKey: maxHRKey)
        if override > 0 { return Double(override) }
        return (208 - 0.7 * Double(age)).rounded()
    }

    static var sleepNeedHours: Double {
        let value = defaults.double(forKey: needKey)
        return value == 0 ? 8 : value
    }

    static var useDemo: Bool {
        get { defaults.object(forKey: demoKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: demoKey) }
    }

    static var healthRequested: Bool {
        get { defaults.bool(forKey: requestedKey) }
        set { defaults.set(newValue, forKey: requestedKey) }
    }

    static var profile: ScoringProfile {
        ScoringProfile(maxHR: maxHR, baseSleepNeedMin: sleepNeedHours * 60)
    }
}
