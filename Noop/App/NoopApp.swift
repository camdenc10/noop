import SwiftUI
import SwiftData

@main
struct NoopApp: App {
    @State private var store = AppStore()
    @State private var sensor = SensorMonitor()

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.black
        appearance.shadowColor = UIColor(white: 1, alpha: 0.08)

        let normal = UIColor(red: 0x5A / 255, green: 0x5A / 255, blue: 0x5F / 255, alpha: 1)
        let selected = UIColor(red: 0x1C / 255, green: 0xFF / 255, blue: 0x80 / 255, alpha: 1)
        for item in [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance] {
            item.normal.iconColor = normal
            item.normal.titleTextAttributes = [.foregroundColor: normal]
            item.selected.iconColor = selected
            item.selected.titleTextAttributes = [.foregroundColor: selected]
        }
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(sensor)
                .preferredColorScheme(.dark)
                .tint(Theme.green)
        }
        .modelContainer(for: [DayRecord.self, WorkoutRecord.self])
    }
}
