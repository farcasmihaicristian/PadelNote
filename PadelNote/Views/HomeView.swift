import PadelCore
import SwiftData
import SwiftUI

struct HomeView: View {
    @Query(sort: \Match.startedAt, order: .reverse) private var matches: [Match]
    @State private var showMatchFlow = false

    private var recentMatches: [Match] {
        Array(matches.prefix(5))
    }

    var body: some View {
        NavigationStack {
            List {
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
            .navigationTitle(String(localized: "PadelNote"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        MatchHistoryView()
                    } label: {
                        Text(String(localized: "History"))
                    }
                    .accessibilityLabel(String(localized: "Match history"))
                }
            }
        }
        .fullScreenCover(isPresented: $showMatchFlow) {
            NavigationStack {
                NewMatchSetupView {
                    showMatchFlow = false
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(PreviewData.container)
}
