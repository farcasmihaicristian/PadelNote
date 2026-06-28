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
        return GeometryReader { _ in
            ZStack {
                VStack(spacing: 0) {
                    phoneTeamZone(
                        team: .b,
                        playerNames: [
                            playerSetup.playerNames.playerB1Name,
                            playerSetup.playerNames.playerB2Name,
                        ].compactMap { $0 },
                        playerSlots: [.sideBPlayer1, .sideBPlayer2],
                        fallbackLabel: sideBLabel,
                        serve: serve
                    )

                    phoneTeamZone(
                        team: .a,
                        playerNames: playerSetup.playerNames.playersInCourtDisplayOrder(for: .a),
                        playerSlots: [.sideAPlayer2, .sideAPlayer1],
                        fallbackLabel: sideALabel,
                        serve: serve
                    )
                }

                phoneScoreOverlay
            }
        }
        .ignoresSafeArea(edges: [.horizontal, .bottom])
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

    private var phoneScoreOverlay: some View {
        VStack(spacing: 8) {
            if !state.completedSets.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(state.completedSets.enumerated()), id: \.offset) { _, set in
                        Text(ScoreFormatter.formatSetScore(set))
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            }

            Text(ScoreFormatter.currentSetGames(in: state))
                .font(.title3.weight(.semibold))

            Text(ScoreFormatter.currentGameScore(in: state))
                .font(.system(size: gameScoreFontSize, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(scoreAccessibilityLabel)
        .allowsHitTesting(false)
    }

    private var scoreAccessibilityLabel: String {
        let completed = state.completedSets.map(ScoreFormatter.formatSetScore(_:)).joined(separator: ", ")
        let currentSet = ScoreFormatter.currentSetGames(in: state)
        let game = ScoreFormatter.currentGameScore(in: state)

        if completed.isEmpty {
            return String(localized: "Set score \(currentSet), game score \(game)")
        }
        return String(localized: "Completed sets \(completed), current set \(currentSet), game score \(game)")
    }

    private func phoneTeamZone(
        team: Team,
        playerNames: [String],
        playerSlots: [PlayerSlot],
        fallbackLabel: String,
        serve: ServeContext?
    ) -> some View {
        Button {
            addPoint(for: team)
        } label: {
            ZStack {
                palette.gradient(for: team)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                GeometryReader { proxy in
                    phoneTeamNameRow(
                        playerNames: playerNames,
                        playerSlots: playerSlots,
                        fallbackLabel: fallbackLabel,
                        serve: serve
                    )
                    .padding(.horizontal, 28)
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .offset(y: team == .b ? proxy.size.height * 0.05 : 0)
                }
            }
            .overlay(alignment: serveAlignment(for: team, serve: serve)) {
                serveIndicator(for: team, serve: serve)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .disabled(state.isMatchOver)
        .accessibilityLabel(
            serveAccessibilityLabel(
                for: team,
                label: fallbackLabel,
                playerNames: playerNames,
                playerSlots: playerSlots,
                serve: serve
            )
        )
    }

    @ViewBuilder
    private func phoneTeamNameRow(
        playerNames: [String],
        playerSlots: [PlayerSlot],
        fallbackLabel: String,
        serve: ServeContext?
    ) -> some View {
        if playerNames.count >= 2, playerSlots.count >= 2 {
            HStack(spacing: 0) {
                playerNameLabel(name: playerNames[0], slot: playerSlots[0], serve: serve)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 32)

                playerNameLabel(name: playerNames[1], slot: playerSlots[1], serve: serve)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        } else {
            Text(fallbackLabel)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }

    private func playerNameLabel(name: String, slot: PlayerSlot, serve: ServeContext?) -> some View {
        let isServing = serve?.servingSlot == slot
        return Text(name)
            .font(.title2.weight(isServing ? .bold : .semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, isServing ? 12 : 0)
            .padding(.vertical, isServing ? 6 : 0)
            .background(isServing ? .black.opacity(0.5) : .clear, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(isServing ? palette.serveColor : .clear, lineWidth: 1)
            }
    }

    @ViewBuilder
    private func serveIndicator(for team: Team, serve: ServeContext?) -> some View {
        if let serve, serve.servingTeam == team {
            serveSideChip(for: serve.side)
                .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                .padding(team == .a ? .top : .bottom, 18)
                .padding(.horizontal, 24)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private func serveAlignment(for team: Team, serve: ServeContext?) -> Alignment {
        let vertical: VerticalAlignment = team == .a ? .top : .bottom
        let onRight = serve?.side == .right
        let trailing = team == .a ? onRight : !onRight
        let horizontal: HorizontalAlignment = trailing ? .trailing : .leading
        return Alignment(horizontal: horizontal, vertical: vertical)
    }

    private func serveAccessibilityLabel(
        for team: Team,
        label: String,
        playerNames: [String],
        playerSlots: [PlayerSlot],
        serve: ServeContext?
    ) -> String {
        guard let serve, serve.servingTeam == team else {
            return String(localized: "Point \(label)")
        }
        let side = serve.side == .right
            ? String(localized: "right")
            : String(localized: "left")
        if let slotIndex = playerSlots.firstIndex(of: serve.servingSlot),
           let serverName = playerNames[safe: slotIndex] {
            return String(localized: "Point \(label). \(serverName) serving from the \(side).")
        }
        return String(localized: "Point \(label). Serving from the \(side).")
    }

    private func addPoint(for team: Team) {
        session.addPoint(for: team)
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

private extension Array {
    subscript(safe index: Int?) -> Element? {
        guard let index, indices.contains(index) else { return nil }
        return self[index]
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
