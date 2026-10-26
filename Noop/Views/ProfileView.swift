import SwiftUI

struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @AppStorage(Settings.nameKey) private var name = ""

    @State private var age = Settings.age
    @State private var maxHROverride = UserDefaults.standard.integer(forKey: Settings.maxHRKey)
    @State private var needHours = Settings.sleepNeedHours
    @State private var showMethod = false
    @State private var confirmClear = false

    private var dirty: Bool {
        age != Settings.age
            || maxHROverride != UserDefaults.standard.integer(forKey: Settings.maxHRKey)
            || needHours != Settings.sleepNeedHours
    }

    private var estimatedMax: Int { Int((208 - 0.7 * Double(age)).rounded()) }

    var body: some View {
        Screen {
            ScreenHeader(title: "Profile", subtitle: "Settings")
            identity
            dataSource
            body_
            about
        }
        .sheet(isPresented: $showMethod) { MethodologyView() }
        .confirmationDialog("Delete the data Noop saved on this phone?", isPresented: $confirmClear,
                            titleVisibility: .visible) {
            Button("Delete local data", role: .destructive) { store.clearLocalData() }
        } message: {
            Text("Your Apple Health data is not touched. It will be read again on the next sync.")
        }
    }

    // MARK: Sections

    private var identity: some View {
        HStack(spacing: 14) {
            AvatarView(name: name, size: 54)
            TextField("Your name", text: $name)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .textContentType(.givenName)
                .submitLabel(.done)
        }
        .card()
    }

    private var dataSource: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "Data source", color: .white)
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.isDemo ? "Demo data" : "Apple Health")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                    Text(store.isDemo
                         ? "Sample numbers so you can explore. Not your health."
                         : (store.lastSync.map { "Synced \($0.formatted(.relative(presentation: .named)))" } ?? "Not synced yet"))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                if store.isSyncing { ProgressView().tint(Theme.green) }
            }
            if store.isDemo {
                actionButton("Connect Apple Health", filled: true) {
                    Task { await store.connectHealth() }
                }
            } else {
                actionButton("Sync now", filled: true) { Task { await store.sync(full: false) } }
                actionButton("Rebuild full history", filled: false) { Task { await store.sync(full: true) } }
                actionButton("Switch to demo data", filled: false) { store.setDemo(true) }
            }
            if let message = store.statusMessage {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.yellow)
            }
            Text("Noop only reads Health and never writes to it. Everything is processed and stored on this phone. There is no account and nothing is uploaded.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
        }
        .card()
    }

    private var body_: some View {
        VStack(alignment: .leading, spacing: 16) {
            Eyebrow(text: "Your body and sleep", color: .white)
            Stepper(value: $age, in: 14...90) {
                row("Age", "\(age)")
            }
            Stepper(value: $maxHROverride, in: 0...230) {
                row("Max heart rate", maxHROverride == 0 ? "Auto \(estimatedMax) bpm" : "\(maxHROverride) bpm")
            }
            Stepper(value: $needHours, in: 5...11, step: 0.25) {
                row("Baseline sleep need", Fmt.duration(needHours * 60))
            }
            if dirty {
                actionButton("Apply and recalculate", filled: true) {
                    UserDefaults.standard.set(age, forKey: Settings.ageKey)
                    UserDefaults.standard.set(maxHROverride, forKey: Settings.maxHRKey)
                    UserDefaults.standard.set(needHours, forKey: Settings.needKey)
                    store.profileChanged()
                }
            }
            Text("Max heart rate sets your five zones and therefore your strain. Set 0 to estimate it from age.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
        }
        .card()
    }

    private var about: some View {
        VStack(spacing: 0) {
            linkRow("How scores work", symbol: "function") { showMethod = true }
            HairlineDivider()
            linkRow("Delete local data", symbol: "trash", tint: Theme.red) { confirmClear = true }
                .disabled(store.isDemo)
        }
        .card(padding: 4)
    }

    // MARK: Pieces

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
            Spacer()
            Text(value).font(.system(size: 15, weight: .heavy)).monospacedDigit().foregroundStyle(Theme.green)
                .padding(.trailing, 6)
        }
    }

    private func actionButton(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(filled ? Color.black : Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(filled ? Theme.green : Theme.raised,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }

    private func linkRow(_ title: String, symbol: String, tint: Color = .white,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 22)
                Text(title).font(.system(size: 15, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .foregroundStyle(tint)
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
