import PadelCore
import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(PhoneSyncCoordinator.self) private var syncCoordinator
    @Query private var matches: [Match]
    @State private var showMatchFlow = false

    private var recentMatches: [Match] {
        matches
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
                    Button {
                        showMatchFlow = true
                    } label: {
                        Label(String(localized: "Start match"), systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityLabel(String(localized: "Start match"))
                    .accessibilityHint(String(localized: "Set up a new padel match"))

                    NavigationLink {
                        StatsView()
                    } label: {
                        Label(String(localized: "Insights"), systemImage: "chart.bar")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityLabel(String(localized: "Insights"))
                    .accessibilityHint(String(localized: "View match statistics and trends"))
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
            .navigationTitle(String(localized: "PadelNote"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        MatchHistoryView()
                    } label: {
                        Text(String(localized: "History"))
                    }
                    .accessibilityLabel(String(localized: "Match history"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Text(String(localized: "Settings"))
                    }
                    .accessibilityLabel(String(localized: "Settings"))
                }
            }
            .navigationDestination(isPresented: $showMatchFlow) {
                NewMatchSetupView {
                    showMatchFlow = false
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .environment(PhoneSyncCoordinator(syncListener: PhoneConnectivityListener()))
        .environment(CurrentUserStore())
        .modelContainer(PreviewData.container)
}
