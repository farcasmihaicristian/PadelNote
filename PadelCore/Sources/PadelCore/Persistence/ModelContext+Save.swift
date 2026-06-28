import SwiftData

extension ModelContext {
    /// Saves, surfacing failures via `assertionFailure` in debug builds. Use for
    /// fire-and-forget saves that previously swallowed errors with `try?`, so a
    /// persistence failure is at least observable while developing/testing.
    @MainActor
    func saveOrLogFailure(_ caller: StaticString = #function) {
        do {
            try save()
        } catch {
            assertionFailure("PadelCore save failed in \(caller): \(error)")
        }
    }
}
