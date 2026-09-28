import PadelCore
import SwiftData
import SwiftUI

struct MatchHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PhoneSyncCoordinator.self) private var syncCoordinator
    @Environment(ProEntitlementStore.self) private var proStore
    @Query(filter: #Predicate<Match> { $0.isComplete }, sort: \Match.startedAt, order: .reverse) private var matches: [Match]
    @State private var showPaywall = false

    private var completedMatches: [Match] {
        matches
    }

    private var hasLockedMatches: Bool {
        !proStore.isPro && completedMatches.contains {
            !ProAccessPolicy.isMatchVisible(startedAt: $0.startedAt, isPro: false)
        }
    }

    private var sections: [(title: String, matches: [Match])] {
        let grouped = Dictionary(grouping: completedMatches) { match in
            Calendar.current.dateComponents([.year, .month], from: match.startedAt)
        }

        return grouped
            .sorted { lhs, rhs in
                let left = Calendar.current.date(from: lhs.key) ?? .distantPast
                let right = Calendar.current.date(from: rhs.key) ?? .distantPast
                return left > right
            }
            .map { element in
                let date = Calendar.current.date(from: element.key) ?? .now
                return (MatchFormatting.monthTitle(for: date), element.value.sorted { $0.startedAt > $1.startedAt })
            }
    }

    var body: some View {
        List {
            if hasLockedMatches {
                Section {
                    Button {
                        showPaywall = true
                    } label: {
                        Label(
                            String(localized: "Older than 30 days requires PadelNote Pro"),
                            systemImage: "lock.fill"
                        )
                    }
                    .accessibilityHint(String(localized: "Unlock full match history"))
                }
            }

            if sections.isEmpty {
                ContentUnavailableView(
                    String(localized: "No match history"),
                    systemImage: "clock.arrow.circlepath",
                    description: Text(String(localized: "Play a match to build your journal."))
                )
            } else {
                ForEach(sections, id: \.title) { section in
                    Section(section.title) {
                        ForEach(section.matches) { match in
                            let visible = ProAccessPolicy.isMatchVisible(
                                startedAt: match.startedAt,
                                isPro: proStore.isPro
                            )
                            if visible {
                                NavigationLink {
                                    MatchDetailView(match: match)
                                } label: {
                                    MatchRowView(match: match)
                                }
                            } else {
                                Button {
                                    showPaywall = true
                                } label: {
                                    HStack {
                                        MatchRowView(match: match)
                                            .opacity(0.45)
                                        Spacer(minLength: 8)
                                        Image(systemName: "lock.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(String(localized: "Locked match, requires PadelNote Pro"))
                            }
                        }
                        .onDelete { offsets in
                            deleteMatches(at: offsets, in: section.matches)
                        }
                    }
                }
            }
        }
        .navigationTitle(String(localized: "History"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            ProPaywallView()
        }
    }

    private func deleteMatches(at offsets: IndexSet, in matches: [Match]) {
        // Resolve to the specific Match objects (by identity) before deleting,
        // independent of the render-time-recomputed section arrays.
        let toDelete = offsets.compactMap { matches.indices.contains($0) ? matches[$0] : nil }
        for match in toDelete {
            modelContext.delete(match)
        }
        try? modelContext.save()
        PlayerPersistence.pruneUnreferencedPlayers(context: modelContext)
        syncCoordinator.syncPhoneContextToWatch()
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        MatchHistoryView()
    }
    .modelContainer(PreviewData.container)
    .environment(PhoneSyncCoordinator(syncListener: PhoneConnectivityListener()))
    .environment(ProEntitlementStore())
}
#endif
