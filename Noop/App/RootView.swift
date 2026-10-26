import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: AppTab = .home

    var body: some View {
        TabView(selection: $tab) {
            ForEach(AppTab.allCases) { item in
                screen(for: item)
                    .tabItem { Label(item.title, systemImage: item.symbol) }
                    .tag(item)
            }
        }
        .background(Theme.black)
        .task { store.attach(context) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, !store.isDemo {
                Task { await store.sync(full: false) }
            }
        }
    }

    @ViewBuilder
    private func screen(for tab: AppTab) -> some View {
        switch tab {
        case .home: HomeView(goTo: { self.tab = $0 })
        case .recovery: RecoveryView()
        case .sleep: SleepView()
        case .activity: ActivityView()
        case .profile: ProfileView()
        }
    }
}

/// Shared page chrome: black canvas and a scroll view with consistent margins.
struct Screen<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            Theme.black.ignoresSafeArea()
            Theme.canvas.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    content()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
    }
}
