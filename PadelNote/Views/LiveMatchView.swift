import PadelCore
import SwiftData
import SwiftUI

struct LiveMatchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppThemeStore.self) private var themeStore

    let rules: MatchRules
    let playerSetup: MatchPlayerSetup
    var onFinished: () -> Void = {}

    @State private var session: ScoringSession
    @State private var startedAt = Date.now
    @State private var savedMatch: Match?
    @State private var showEndConfirmation = false
    @State private var firstServer: PlayerSlot
    @State private var setServeOrders: [ServeOrder] = []
    @State private var decidingSideOverride: ServeSide?
    @State private var showServeSidePrompt = false
    @ScaledMetric(relativeTo: .largeTitle) private var gameScoreFontSize = 56

    init(
        rules: MatchRules,
        playerSetup: MatchPlayerSetup,
        firstServer: PlayerSlot = .sideAPlayer1,
        onFinished: @escaping () -> Void = {}
    ) {
        self.rules = rules
        self.playerSetup = playerSetup
        self.onFinished = onFinished
        _session = State(initialValue: ScoringSession(rules: rules))
        _firstServer = State(initialValue: firstServer)
    }

    private var state: MatchState { session.state }

    private var palette: ThemePalette {
        themeStore.palette
    }

    private var currentServe: ServeContext? {
        guard !state.isMatchOver else { return nil }
        return ServeEngine.currentServe(
            events: session.events,
            rules: rules,
            orders: setServeOrders,
            decidingSideOverride: decidingSideOverride
        )
    }

    private var needsDecidingSideChoice: Bool {
        guard let serve = currentServe else { return false }
        return serve.isDecidingPoint && decidingSideOverride == nil
    }

    private var sideALabel: String {
        playerSetup.playerNames.courtSideLabel(for: .a)
    }

    private var sideBLabel: String {
        playerSetup.playerNames.courtSideLabel(for: .b)
    }

    var body: some View {
        Group {
            if let savedMatch {
                MatchDetailView(match: savedMatch)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(String(localized: "Done")) {
                                onFinished()
                            }
                            .accessibilityLabel(String(localized: "Done"))
                        }
                    }
            } else {
                liveScoringView
            }
        }
        .navigationBarBackButtonHidden(savedMatch != nil)
    }

    private var liveScoringView: some View {
        // Compute the serve once per render; the banner and both point buttons
        // reuse it rather than each recomputing it via an event-log replay.
        let serve = currentServe
        return VStack(spacing: 24) {
            setsHeader

            VStack(spacing: 8) {
                gameScoreView(ScoreFormatter.currentGameScore(in: state))

                currentSetScoreView
            }

            serveBanner(serve)

            HStack(spacing: 16) {
                pointButton(team: .a, label: sideALabel, serve: serve)
                pointButton(team: .b, label: sideBLabel, serve: serve)
            }
            .padding(.horizontal)

            HStack(spacing: 16) {
                Button {
                    undoPoint()
                } label: {
                    Label(String(localized: "Undo"), systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(session.events.isEmpty || state.isMatchOver)
                .accessibilityLabel(String(localized: "Undo last point"))

                Button(role: .destructive) {
                    showEndConfirmation = true
                } label: {
                    Label(String(localized: "End match"), systemImage: "flag.checkered")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(session.events.isEmpty)
                .accessibilityLabel(String(localized: "End match"))
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top, 24)
        .navigationTitle(String(localized: "Live match"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            syncServeOrders()
            showServeSidePrompt = needsDecidingSideChoice
        }
        .onChange(of: state.isMatchOver) { _, isOver in
            if isOver { finishMatch() }
        }
        .confirmationDialog(
            String(localized: "End this match?"),
            isPresented: $showEndConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "End match"), role: .destructive) {
                finishMatch()
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        }
        .confirmationDialog(
            String(localized: "Deciding point — receiver picks the serve side"),
            isPresented: $showServeSidePrompt,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Serve from right")) {
                decidingSideOverride = .right
            }
            Button(String(localized: "Serve from left")) {
                decidingSideOverride = .left
            }
        }
        .background(alignment: .top) {
            ambientGlow
        }
    }

    @ViewBuilder
    private func serveBanner(_ serve: ServeContext?) -> some View {
        if let serve {
            HStack(spacing: 6) {
                serveSideChip(for: serve.side)
                Text(serveDescription(serve))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(serveDescription(serve))
        }
    }

    private func serveSideChip(for side: ServeSide) -> some View {
        Text(side == .right ? "R" : "L")
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundStyle(palette.serveColor)
            .kerning(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(.black.opacity(0.45), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(palette.serveColor, lineWidth: 1)
            }
    }

    private func serveDescription(_ serve: ServeContext) -> String {
        let server = serverName(serve.servingSlot)
        let side = serve.side == .right
            ? String(localized: "right")
            : String(localized: "left")
        if serve.isDecidingPoint, decidingSideOverride == nil {
            return String(localized: "\(server) to serve — deciding point")
        }
        return String(localized: "\(server) serving from the \(side)")
    }

    private func serverName(_ slot: PlayerSlot) -> String {
        let name = slot.selection(from: playerSetup).trimmedName
        if !name.isEmpty { return name }
        return slot.team == .a ? sideALabel : sideBLabel
    }

    private var setsHeader: some View {
        let sets = state.completedSets
        return HStack(spacing: 12) {
            if sets.isEmpty {
                Text(String(localized: "No sets completed yet"))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(sets.enumerated()), id: \.offset) { index, set in
                    VStack {
                        Text(String(localized: "Set \(index + 1)"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(ScoreFormatter.formatSetScore(set))
                            .font(.headline)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var ambientGlow: some View {
        RadialGradient(
            colors: [
                palette.sideAColor.opacity(0.35),
                palette.sideAColor.opacity(0.12),
                .clear,
            ],
            center: .top,
            startRadius: 20,
            endRadius: 280
        )
        .blur(radius: 38)
        .frame(height: 360)
        .offset(y: -150)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func gameScoreView(_ score: String) -> some View {
        coloredScoreText(score)
            .font(.system(size: gameScoreFontSize, weight: .bold, design: .rounded))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .accessibilityLabel(String(localized: "Game score \(score)"))
    }

    private var currentSetScoreView: some View {
        HStack(spacing: 4) {
            Text(String(localized: "Set \(state.completedSets.count + 1):"))
                .foregroundStyle(.secondary)
            coloredScoreText(ScoreFormatter.currentSetGames(in: state))
        }
        .font(.title3)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func coloredScoreText(_ score: String) -> some View {
        let parts = score.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        if parts.count == 2 {
            HStack(spacing: 4) {
                Text(parts[0])
                    .foregroundStyle(palette.sideAColor)
                Text("-")
                    .foregroundStyle(.secondary)
                Text(parts[1])
                    .foregroundStyle(palette.sideBColor)
            }
        } else {
            Text(score)
                .foregroundStyle(.primary)
        }
    }

    private func pointButton(team: Team, label: String, serve: ServeContext?) -> some View {
        Button {
            addPoint(for: team)
        } label: {
            VStack(spacing: 8) {
                if serve?.servingTeam == team {
                    serveSideChip(for: serve?.side ?? .right)
                        .accessibilityHidden(true)
                }
                Text(label)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text(String(localized: "Point"))
                    .font(.title.bold())
            }
            .frame(maxWidth: .infinity, minHeight: 120)
        }
        .buttonStyle(.borderedProminent)
        .tint(palette.color(for: team))
        .disabled(state.isMatchOver)
        .accessibilityLabel(String(localized: "Point \(label)"))
    }

    private func addPoint(for team: Team) {
        session.addPoint(for: team)
        decidingSideOverride = nil
        syncServeOrders()
        showServeSidePrompt = needsDecidingSideChoice
    }

    private func undoPoint() {
        session.undo()
        decidingSideOverride = nil
        syncServeOrders()
        showServeSidePrompt = needsDecidingSideChoice
    }

    /// Keeps `setServeOrders` aligned with the sets played so far. The serving
    /// order is fixed once a set starts: new sets inherit the previous set's
    /// order (or derive from `firstServer` for the first set).
    private func syncServeOrders() {
        setServeOrders = ServeOrder.aligned(
            setServeOrders,
            completedSetCount: state.completedSets.count,
            firstServer: firstServer
        )
    }

    private func finishMatch() {
        guard savedMatch == nil else { return }
        savedMatch = MatchPersistence.saveCompletedMatch(
            context: modelContext,
            rules: rules,
            events: session.events,
            startedAt: startedAt,
            playerSetup: playerSetup,
            setServeOrders: setServeOrders
        )
    }
}

#Preview {
    NavigationStack {
        LiveMatchView(
            rules: .default,
            playerSetup: MatchPlayerSetup(
                sideAPlayer1: .init(name: "Alex"),
                sideAPlayer2: .init(name: "Maria"),
                sideBPlayer1: .init(name: "Chris"),
                sideBPlayer2: .init(name: "Dana")
            )
        )
    }
    .modelContainer(PreviewData.container)
    .environment(AppThemeStore())
}
