import PadelCore
import SwiftUI

struct SettingsView: View {
    @Environment(PhoneSyncCoordinator.self) private var syncCoordinator
    @Environment(CurrentUserStore.self) private var currentUserStore
    @Environment(AppThemeStore.self) private var themeStore
    @State private var bestOfSets = MatchRulesSettingsForm.bestOfSets(from: .default)
    @State private var gamePointStyle = MatchRules.default.gamePointStyle
    @State private var setTieBreak = MatchRules.default.setTieBreak
    @State private var finalSetTieBreak = MatchRules.default.finalSetTieBreak
    @State private var healthStatus = HealthKitAuthorizationChecker.workoutAuthorizationStatus()
    @State private var workoutActivity = WorkoutActivityPreferences.load()
    @State private var preferredMeSlot = MeProfilePreferences.preferredSlot()
    @State private var serveIndicatorStyle = ServeIndicatorStylePreferences.load()

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        Form {
            AccountAuthSection()

            Section {
                Text(String(localized: "These options are used as defaults when you start a new match."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            MatchRulesSettingsForm(
                bestOfSets: $bestOfSets,
                gamePointStyle: $gamePointStyle,
                setTieBreak: $setTieBreak,
                finalSetTieBreak: $finalSetTieBreak
            )

            meSlotSection

            themeSection

            Section(String(localized: "Health")) {
                LabeledContent(String(localized: "HealthKit access")) {
                    Text(HealthKitAuthorizationChecker.statusLabel(for: healthStatus))
                }
                .accessibilityLabel(
                    String(
                        localized: "HealthKit access \(HealthKitAuthorizationChecker.statusLabel(for: healthStatus))"
                    )
                )

                Picker(String(localized: "Workout type"), selection: $workoutActivity) {
                    ForEach(WorkoutActivityKind.allCases) { activity in
                        Text(activity.displayName).tag(activity)
                    }
                }
                .accessibilityLabel(String(localized: "Workout type recorded on Apple Watch"))

                Text(String(localized: "Workouts are recorded on Apple Watch during matches. HealthKit has no padel type, so pick the closest sport. Manage permissions in the Health app."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section(String(localized: "About")) {
                LabeledContent(String(localized: "App")) {
                    Text("PadelNote")
                }
                LabeledContent(String(localized: "Version")) {
                    Text(appVersion)
                }
                Text(String(localized: "Keep score. Keep history. Keep playing."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(String(localized: "Settings"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadDefaults()
            healthStatus = HealthKitAuthorizationChecker.workoutAuthorizationStatus()
            workoutActivity = WorkoutActivityPreferences.load()
            syncCoordinator.syncDefaultRulesToWatch()
            preferredMeSlot = MeProfilePreferences.preferredSlot()
            serveIndicatorStyle = themeStore.serveIndicatorStyle
        }
        .onChange(of: bestOfSets) { _, _ in saveDefaults() }
        .onChange(of: gamePointStyle) { _, _ in saveDefaults() }
        .onChange(of: setTieBreak) { _, _ in saveDefaults() }
        .onChange(of: finalSetTieBreak) { _, _ in saveDefaults() }
        .onChange(of: workoutActivity) { _, newValue in
            WorkoutActivityPreferences.save(newValue)
            syncCoordinator.syncPhoneContextToWatch()
        }
        .onChange(of: preferredMeSlot) { _, newValue in
            MeProfilePreferences.savePreferredSlot(newValue)
            syncCoordinator.syncPhoneContextToWatch()
        }
        .onChange(of: serveIndicatorStyle) { _, newValue in
            ServeIndicatorStylePreferences.save(newValue)
            themeStore.applyServeIndicatorStyle(newValue, persist: false)
            syncCoordinator.syncPhoneContextToWatch()
        }
        .onChange(of: currentUserStore.isSignedIn) { _, _ in
            syncCoordinator.syncPhoneContextToWatch()
        }
    }

    @ViewBuilder
    private var meSlotSection: some View {
        MeSlotSettingsSection(preferredMeSlot: $preferredMeSlot)
    }

    private var themeSection: some View {
        Section(String(localized: "Appearance")) {
            NavigationLink {
                ThemeSelectionView()
            } label: {
                HStack {
                    Text(String(localized: "Theme"))
                    Spacer()
                    ThemeSwatch(theme: themeStore.activeTheme)
                    Text(String(localized: String.LocalizationValue(themeStore.activeTheme.name)))
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityLabel(String(localized: "App color theme"))

            Picker(String(localized: "Serve indicator"), selection: $serveIndicatorStyle) {
                ForEach(ServeIndicatorStyle.allCases) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .accessibilityLabel(String(localized: "Serve indicator style"))

            Text(String(localized: "Theme and serve indicator apply to live scoring on iPhone and Apple Watch."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func loadDefaults() {
        let values = MatchRulesSettingsForm.loadValues(from: MatchRulesPreferences.load())
        bestOfSets = values.bestOfSets
        gamePointStyle = values.gamePointStyle
        setTieBreak = values.setTieBreak
        finalSetTieBreak = values.finalSetTieBreak
    }

    private func saveDefaults() {
        let rules = MatchRulesSettingsForm.makeRules(
            bestOfSets: bestOfSets,
            gamePointStyle: gamePointStyle,
            setTieBreak: setTieBreak,
            finalSetTieBreak: finalSetTieBreak
        )
        MatchRulesPreferences.save(rules)
        syncCoordinator.syncDefaultRulesToWatch()
    }
}

private struct ThemeSwatch: View {
    let theme: AppTheme

    var body: some View {
        Circle()
            .fill(Color(hex: theme.team1Top))
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(Color(hex: theme.team2Top))
                    .frame(width: 11)
            }
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(.white.opacity(0.25), lineWidth: 1)
            }
            .frame(width: 22, height: 22)
            .accessibilityHidden(true)
    }
}

private struct MeSlotSettingsSection: View {
    @Binding var preferredMeSlot: PlayerSlot

    /// Top or bottom of the court. Bottom is side A, top is side B.
    private enum CourtEnd: String, CaseIterable, Identifiable {
        case bottom
        case top

        var id: String { rawValue }

        var label: String {
            switch self {
            case .bottom: String(localized: "Bottom")
            case .top: String(localized: "Top")
            }
        }

        var isTop: Bool { self == .top }
    }

    /// Left or right within a side. Right is player 1, left is player 2.
    private enum CourtSide: String, CaseIterable, Identifiable {
        case left
        case right

        var id: String { rawValue }

        var label: String {
            switch self {
            case .left: String(localized: "Left")
            case .right: String(localized: "Right")
            }
        }

        var isLeft: Bool { self == .left }
    }

    private static func slot(end: CourtEnd, side: CourtSide) -> PlayerSlot {
        switch (end, side) {
        case (.bottom, .right): .sideAPlayer1
        case (.bottom, .left): .sideAPlayer2
        case (.top, .right): .sideBPlayer1
        case (.top, .left): .sideBPlayer2
        }
    }

    private var currentEnd: CourtEnd {
        switch preferredMeSlot {
        case .sideBPlayer1, .sideBPlayer2: .top
        case .sideAPlayer1, .sideAPlayer2: .bottom
        }
    }

    private var currentSide: CourtSide {
        switch preferredMeSlot {
        case .sideAPlayer2, .sideBPlayer2: .left
        case .sideAPlayer1, .sideBPlayer1: .right
        }
    }

    private var preferredEnd: Binding<CourtEnd> {
        Binding(
            get: { currentEnd },
            set: { preferredMeSlot = Self.slot(end: $0, side: currentSide) }
        )
    }

    private var preferredSide: Binding<CourtSide> {
        Binding(
            get: { currentSide },
            set: { preferredMeSlot = Self.slot(end: currentEnd, side: $0) }
        )
    }

    var body: some View {
        Section(String(localized: "Your match setup")) {
            Picker(String(localized: "Preferred side"), selection: preferredEnd) {
                ForEach(CourtEnd.allCases) { end in
                    Text(end.label).tag(end)
                }
            }
            .accessibilityLabel(String(localized: "Preferred side on new match"))

            Picker(String(localized: "Default side"), selection: preferredSide) {
                ForEach(CourtSide.allCases) { side in
                    Text(side.label).tag(side)
                }
            }
            .accessibilityLabel(String(localized: "Default left or right on new match"))
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(PhoneSyncCoordinator(syncListener: PhoneConnectivityListener()))
    .environment(CurrentUserStore())
    .environment(AppThemeStore())
}
