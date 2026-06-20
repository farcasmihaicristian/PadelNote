import PadelCore
import SwiftData
import SwiftUI

struct LiveMatchView: View {
    @Environment(\.modelContext) private var modelContext

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
        VStack(spacing: 24) {
            setsHeader

            VStack(spacing: 8) {
                Text(ScoreFormatter.currentGameScore(in: state))
                    .font(.system(size: gameScoreFontSize, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .accessibilityLabel(String(localized: "Game score \(ScoreFormatter.currentGameScore(in: state))"))

                Text(
                    String(
                        localized: "Set \(state.completedSets.count + 1): \(ScoreFormatter.currentSetGames(in: state))"
                    )
                )
                .font(.title3)
                .foregroundStyle(.secondary)
            }

            serveBanner

            HStack(spacing: 16) {
                pointButton(team: .a, label: sideALabel)
                pointButton(team: .b, label: sideBLabel)
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
            Button(String(localized: "Receive right")) {
                decidingSideOverride = .right
            }
            Button(String(localized: "Receive left")) {
                decidingSideOverride = .left
            }
        }
    }

    @ViewBuilder
    private var serveBanner: some View {
        if let serve = currentServe {
            HStack(spacing: 6) {
                Image(systemName: "arrowtriangle.right.fill")
                    .foregroundStyle(.orange)
                Text(serveDescription(serve))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(serveDescription(serve))
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

    private func pointButton(team: Team, label: String) -> some View {
        Button {
            addPoint(for: team)
        } label: {
            VStack(spacing: 8) {
                if currentServe?.servingTeam == team {
                    Image(systemName: "arrowtriangle.up.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
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
        let activeSetIndex = state.completedSets.count
        let targetCount = activeSetIndex + 1

        if setServeOrders.count > targetCount {
            setServeOrders = Array(setServeOrders.prefix(targetCount))
        }
        while setServeOrders.count < targetCount {
            let order = setServeOrders.last ?? ServeOrder.standard(firstServer: firstServer)
            setServeOrders.append(order)
        }
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
}
