import PadelCore
import SwiftData
import SwiftUI

struct MatchHistoryView: View {
    @Query(sort: \Match.startedAt, order: .reverse) private var matches: [Match]

    private var completedMatches: [Match] {
        matches.filter(\.isCompleted)
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
                            NavigationLink {
                                MatchDetailView(match: match)
                            } label: {
                                MatchRowView(match: match)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(String(localized: "History"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        MatchHistoryView()
    }
    .modelContainer(PreviewData.container)
}
