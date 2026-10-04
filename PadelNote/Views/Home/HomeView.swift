import PadelCore
import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(PhoneSyncCoordinator.self) private var syncCoordinator
    @Environment(ProEntitlementStore.self) private var proStore
    @Query private var matches: [Match]

    private var recentMatches: [Match] {
        matches.filter {
            ProAccessPolicy.isMatchVisible(startedAt: $0.startedAt, isPro: proStore.isPro)
        }
    }

    init() {
        var descriptor = FetchDescriptor<Match>(
            predicate: #Predicate { $0.isComplete },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 5
        _matches = Query(descriptor)
    }

    var body: some View {
        @Bindable var syncCoordinator = syncCoordinator

        NavigationStack {
            List {
                if let snapshot = syncCoordinator.liveSnapshot, snapshot.isVisibleOnPhone {
                    Section {
                        NavigationLink {
                            LiveMatchView()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Label(String(localized: "Live on Apple Watch"), systemImage: "applewatch")
                                    .font(.headline)
                                Text(snapshot.scoreLine)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityLabel(String(localized: "Live match on Apple Watch, score \(snapshot.scoreLine)"))
                    }
                }

                Section {
                    NavigationLink {
                        StatsView()
                    } label: {
                        Label(String(localized: "Insights"), systemImage: "chart.bar")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityLabel(String(localized: "Insights"))
                    .accessibilityHint(String(localized: "View match statistics and trends"))

                    NavigationLink {
                        MatchHistoryView()
                    } label: {
                        Label(String(localized: "History"), systemImage: "clock.arrow.circlepath")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityLabel(String(localized: "Match history"))
                    .accessibilityHint(String(localized: "Browse your past matches"))
                }

                Section(String(localized: "Recent matches")) {
                    if recentMatches.isEmpty {
                        ContentUnavailableView(
                            String(localized: "No matches yet"),
                            systemImage: "sportscourt",
                            description: Text(String(localized: "Your completed matches will appear here."))
                        )
                    } else {
                        ForEach(recentMatches) { match in
                            NavigationLink {
                                MatchDetailView(match: match)
                            } label: {
                                MatchRowView(match: match)
                            }
                        }
                    }
                }
            }
            .refreshable {
                await syncCoordinator.refresh()
            }
            .navigationTitle(String(localized: "PadelNote Watch"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Text(String(localized: "Settings"))
                    }
                    .accessibilityLabel(String(localized: "Settings"))
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    HomeView()
        .environment(PhoneSyncCoordinator(syncListener: PhoneConnectivityListener()))
        .environment(CurrentUserStore())
        .environment(ProEntitlementStore())
        .modelContainer(PreviewData.container)
}
#endif
