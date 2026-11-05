import MessageUI
import PadelCore
import StoreKit
import SwiftUI

struct SettingsView: View {
    @Environment(PhoneSyncCoordinator.self) private var syncCoordinator
    @Environment(CurrentUserStore.self) private var currentUserStore
    @Environment(AppThemeStore.self) private var themeStore
    @Environment(ProEntitlementStore.self) private var proStore
    @State private var bestOfSets = MatchRulesSettingsForm.bestOfSets(from: .default)
    @State private var gamePointStyle = MatchRules.default.gamePointStyle
    @State private var setTieBreak = MatchRules.default.setTieBreak
    @State private var finalSetTieBreak = MatchRules.default.finalSetTieBreak
    @State private var healthStatus = HealthKitAuthorizationChecker.workoutAuthorizationStatus()
    @State private var workoutActivity = WorkoutActivityPreferences.load()
    @State private var preferredMeSlot = MeProfilePreferences.preferredSlot()
    @State private var serveIndicatorStyle = ServeIndicatorStylePreferences.load()
    @State private var undoButtonPosition = UndoButtonPositionPreferences.load()
    @State private var watchHapticsEnabled = WatchHapticsPreferences.load()
    @State private var showPaywall = false
    @State private var mailDraft: FeedbackDraft?
    @State private var showNoMailAlert = false
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview

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

            Section(String(localized: "Apple Watch")) {
                Toggle(String(localized: "Vibration feedback"), isOn: $watchHapticsEnabled)
                    .accessibilityLabel(String(localized: "Vibration feedback on Apple Watch"))

                Text(String(localized: "Apple Watch vibrates when you score a point, undo, or change the court setup during a match."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

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

            #if DEBUG
            Section {
                Toggle(
                    String(localized: "Unlock Pro (Simulator)"),
                    isOn: Bindable(proStore).debugForceProUnlocked
                )
                Text(String(localized: "Debug only. Use this when StoreKit Configuration fails to load products in the Simulator."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text(String(localized: "Developer"))
            }
            #endif

            feedbackSection

            Section(String(localized: "About")) {
                LabeledContent(String(localized: "App")) {
                    Text(String(localized: "PadelNote Watch"))
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
            undoButtonPosition = themeStore.undoButtonPosition
        }
        .onChange(of: bestOfSets) { _, _ in saveDefaults() }
        .onChange(of: gamePointStyle) { _, _ in saveDefaults() }
        .onChange(of: setTieBreak) { _, _ in saveDefaults() }
        .onChange(of: finalSetTieBreak) { _, _ in saveDefaults() }
        .onChange(of: workoutActivity) { _, newValue in
            WorkoutActivityPreferences.save(newValue)
            syncCoordinator.syncPhoneContextToWatch()
        }
        .onChange(of: watchHapticsEnabled) { _, newValue in
            WatchHapticsPreferences.save(newValue)
            syncCoordinator.syncPhoneContextToWatch()
        }
        .onChange(of: preferredMeSlot) { _, newValue in
            MeProfilePreferences.savePreferredSlot(newValue)
            syncCoordinator.syncPhoneContextToWatch()
        }
        .onChange(of: serveIndicatorStyle) { _, newValue in
            if ProAccessPolicy.isServeStyleUnlocked(style: newValue, isPro: proStore.isPro) {
                ServeIndicatorStylePreferences.save(newValue)
                themeStore.applyServeIndicatorStyle(newValue, persist: false)
                syncCoordinator.syncPhoneContextToWatch()
            } else {
                serveIndicatorStyle = .sideLabels
                showPaywall = true
            }
        }
        .onChange(of: undoButtonPosition) { _, newValue in
            if ProAccessPolicy.isUndoPositionUnlocked(position: newValue, isPro: proStore.isPro) {
                themeStore.applyUndoButtonPosition(newValue)
                syncCoordinator.syncPhoneContextToWatch()
            } else {
                undoButtonPosition = .default
                showPaywall = true
            }
        }
        .onChange(of: themeStore.undoButtonPosition) { _, newValue in
            undoButtonPosition = newValue
        }
        .onChange(of: currentUserStore.isSignedIn) { _, _ in
            syncCoordinator.syncPhoneContextToWatch()
        }
        .sheet(isPresented: $showPaywall) {
            ProPaywallView()
        }
        .sheet(item: $mailDraft) { draft in
            MailComposeView(draft: draft)
                .ignoresSafeArea()
        }
        .alert(String(localized: "No email app found"), isPresented: $showNoMailAlert) {
            Button(String(localized: "Copy address")) {
                UIPasteboard.general.string = LegalURLs.feedbackEmail
            }
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(String(localized: "Send your message to \(LegalURLs.feedbackEmail) from any email app."))
        }
    }

    private var feedbackSection: some View {
        Section {
            Button {
                composeFeedback(.feedback)
            } label: {
                Label(String(localized: "Send feedback"), systemImage: "envelope")
            }

            Button {
                composeFeedback(.problem)
            } label: {
                Label(String(localized: "Report a problem"), systemImage: "ladybug")
            }

            Button {
                if let url = LegalURLs.writeReview {
                    openURL(url)
                } else {
                    requestReview()
                }
            } label: {
                Label(String(localized: "Rate PadelNote"), systemImage: "star")
            }
        } header: {
            Text(String(localized: "Feedback & Support"))
        } footer: {
            Text(String(localized: "Messages go to \(LegalURLs.feedbackEmail). App and device details are added so we can help faster; you can edit them before sending."))
        }
    }

    private func composeFeedback(_ kind: FeedbackDraft.Kind) {
        let draft = FeedbackComposer.draft(kind, isPro: proStore.isPro)
        if MFMailComposeViewController.canSendMail() {
            mailDraft = draft
        } else if let url = draft.mailtoURL {
            openURL(url) { accepted in
                if !accepted {
                    showNoMailAlert = true
                }
            }
        } else {
            showNoMailAlert = true
        }
    }

    @ViewBuilder
    private var meSlotSection: some View {
        MeSlotSettingsSection(preferredMeSlot: $preferredMeSlot)
    }

    private var themeSection: some View {
        Section(String(localized: "Appearance")) {
            if !proStore.isPro {
                Button {
                    showPaywall = true
                } label: {
                    Label(String(localized: "Unlock PadelNote Watch Pro"), systemImage: "star.circle.fill")
                }
            }

            NavigationLink {
                ThemeSelectionView()
            } label: {
                HStack {
                    Text(String(localized: "Theme"))
                    Spacer()
                    ThemeSwatch(theme: themeStore.activeTheme)
                    Text(verbatim: themeStore.activeTheme.name)
                        .foregroundStyle(.secondary)
                    if !proStore.isPro {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }
            .accessibilityLabel(String(localized: "App color theme"))

            Picker(String(localized: "Serve indicator"), selection: $serveIndicatorStyle) {
                ForEach(ServeIndicatorStyle.allCases) { style in
                    HStack {
                        Text(style.displayName)
                        if !ProAccessPolicy.isServeStyleUnlocked(style: style, isPro: proStore.isPro) {
                            Image(systemName: "lock.fill")
                        }
                    }
                    .tag(style)
                }
            }
            .accessibilityLabel(String(localized: "Serve indicator style"))

            Picker(String(localized: "Watch Undo button"), selection: $undoButtonPosition) {
                ForEach(UndoButtonPosition.allCases) { position in
                    HStack {
                        Text(position.displayName)
                        if !ProAccessPolicy.isUndoPositionUnlocked(position: position, isPro: proStore.isPro) {
                            Image(systemName: "lock.fill")
                        }
                    }
                    .tag(position)
                }
            }
            .accessibilityLabel(String(localized: "Undo button side on Apple Watch"))

            Text(String(localized: "Theme and serve indicator apply to live scoring on iPhone and Apple Watch. Free includes the default theme, Left / Right labels, and Undo on the left."))
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
    .environment(ProEntitlementStore())
}
