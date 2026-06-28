# Plan — Mac build & verification follow-up

> The code-improvement work in [code-improvements.md](code-improvements.md) was implemented on a **Windows host with no Swift/Xcode toolchain**, so none of it is compile-verified. This document is the checklist to run **on the Mac**: verify the changes build and behave, then finish the items that were deliberately deferred because they couldn't be done safely without a compiler.

**Branch:** changes were committed to `main`. Start from a clean pull.

---

## 0. Orientation — what changed and why

The improvement pass touched 30 files (+~475/−264) plus 3 new files. Full rationale per item is in [code-improvements.md](code-improvements.md). The high-signal areas to keep in mind while verifying:

- **PadelCore** (pure, unit-tested): scoring/serve/stats engine, persistence, sync codec, models.
- **iOS views**: live match, stats, player detail, match detail, history, new-match setup.
- **watchOS**: `WatchMatchCoordinator`, connectivity publisher, workout recorder, store.

New files (auto-included — PadelCore is SPM; the app uses Xcode 16 file-system-synchronized groups, so no `.pbxproj` edits were needed — **confirm this assumption holds**):
- `PadelCore/Sources/PadelCore/Persistence/ModelContext+Save.swift`
- `PadelCore/Tests/PadelCoreTests/CodeImprovementsTests.swift`
- `PadelNote/Views/PlayerStatRowView.swift`

---

## 1. Build & test PadelCore first (no simulator needed)

```bash
cd PadelCore
swift build
swift test
```

- [ ] `swift build` succeeds.
- [ ] `swift test` passes — existing suites **plus** the new `CodeImprovementsTests` (serve-field codec round-trip, `ServeOrder.aligned`, `isSuddenDeathPoint`, schema version, duplicate-name merge, stale-retransmit guard, namesake-skip, `scoreLinesBySequence`).
- [ ] Confirm the edited existing test still passes: `PlayerPersistenceTests.saveCompletedMatchLinksPlayersInRoster` (now unwraps `Match?` via `#require`).

**Compile spots most likely to need a fix (check these first if PadelCore won't build):**
- `MatchStatistics.goldenPointCounts` now returns a 3-tuple `(opportunities, wins, completedSets)` — both call sites (`insights(for:)`, `playerInsights`) were updated to use named access. Confirm no positional-destructuring leftovers.
- `MatchTransferPayload.schemaVersion` (optional, custom `init(from:)` + synthesized `encode`) — confirm Codable still round-trips.
- `ModelContext+Save.swift` — `@MainActor func saveOrLogFailure(_:)`; confirm `import SwiftData` resolves and all callers are `@MainActor`.
- `PlayerPersistence` cache-aware overloads (`resolveRoster/resolveSlot/findOrCreatePlayer` with `cache: inout [String: Player]`) — confirm overload resolution.
- `ScoringEngine.ScoringSession.state` now has `assert(!stateHistory.isEmpty)` — fine in tests, but watch for any test that constructs an empty history.

## 2. Build the app targets (Xcode)

Open `PadelNote.xcodeproj` and build both schemes (iOS + watchOS).

- [ ] **iOS** target builds.
- [ ] **watchOS** target builds.
- [ ] Confirm `PlayerStatRowView.swift` and `ModelContext+Save.swift` are actually in their targets (file-system-synchronized groups should include them automatically; if not, add them manually).

**Compile spots most likely to need a fix (Swift can't be checked on Windows — these are the riskiest blind edits):**
- **`let … return View` bodies** restructured to compute derived data once: `StatsView`, `PlayerDetailView`, `MatchDetailView`, `MatchRowView`, `LiveMatchView.liveScoringView`. Verify the `@ViewBuilder`/explicit-return form compiles and previews render.
- **`WatchMatchCoordinator`**: `@ObservationIgnored private var serveCache` + the memoized `currentServe`; the new `ContinuationState` enum replacing `rulesBeforeContinue`/`continueBaselineEventCount` (4 call sites). Confirm `import Observation` is present and the `if case let .pending(...)` matches compile.
- **`WatchConnectivityPublisher`**: the `session(_:didFinish:error:)` delegate signature and `inFlightTransfers` set.
- **`LiveMatchView`**: `serveBanner(_:)` and `pointButton(team:label:serve:)` now take the serve param.
- **`MatchScoreText.Rendered`** struct + `rendered(for:)`; callers in `MatchRowView`/`MatchDetailView`.

## 3. Manual / device verification of behavior changes

Some fixes only manifest at runtime — verify with a real iPhone + Watch on the same Wi-Fi (HealthKit/WatchConnectivity don't work in isolation):

- [ ] **P0-1 (serve on phone mirror):** start a match on the Watch; on the iPhone Home → "Live on Apple Watch" mirror, the **Serving** row now shows the server + side (was always blank before).
- [ ] **P0-2 (no duplicate point churn / stale guard):** complete a match on the Watch, let it sync, then trigger re-sync (relaunch the Watch app) — the match isn't rebuilt/duplicated and isn't overwritten.
- [ ] **P0-3 (transfer reliability):** complete a match while the iPhone is unreachable, then bring it back — the pending match still arrives (it's retained until delivery is confirmed).
- [ ] **P0-4 (no duplicate players):** start a match naming the **same person in two slots** (e.g. both "Sam") → only one `Sam` appears in the player registry / Insights.
- [ ] **P0-5 (no stat merging):** with two different registered players sharing a name, confirm the "Link past matches?" offer does **not** fire (ambiguous namesake) and doesn't merge their histories.
- [ ] **P1 perf:** Insights, Player detail, and a long Match detail timeline scroll smoothly with a sizeable history.
- [ ] **P3-1 (continue-new-set):** finish a match, tap "Continue new set", then **End** without playing a point → the original decided result is preserved; then repeat but play a point first → the new set is kept.
- [ ] **P3-3 (workout):** start a match then immediately discard/back out → no orphaned `HKWorkoutSession` (no lingering green workout indicator); a >10-min match still saves to Health.
- [ ] **P3-2 behavior change:** if a phone-scored match fails to save, the app now stays on the live screen (returns `nil`) instead of showing an unsaved detail — confirm normal saves still navigate to detail.

## 4. Run the linters/format you normally use

- [ ] SwiftFormat / SwiftLint (if configured) over the changed files.
- [ ] Resolve any new warnings (e.g. the now-unused `rules` parameter in `ServeEngine.isDecidingPoint` — harmless, can be `_ rules` or removed).

---

## 5. Deferred items to finish on the Mac

These were **intentionally not done** on Windows because they need a compiler and/or carry data-migration risk. Each is safe to do iteratively with Xcode + tests.

### 5.1 Stored `isCompleted` flag + `@Query` predicates (rest of P1-5)
- **Why deferred:** SwiftData `@Query` predicates can't reference computed properties, and the relationship still faults to evaluate `isCompleted`. A full fix needs a **stored** flag and a lightweight migration.
- **Do:** add a stored `isComplete: Bool` (or rely on `endedAt`) to `Match`, set it on every save/mutation, backfill existing rows once, then switch `HomeView`/`MatchHistoryView`/`StatsView` `@Query`s to predicate + `fetchLimit` (Home only needs the 5 most recent). Verify migration on a populated store.

### 5.2 `workoutWarning` → enum
- **Why deferred:** low value, touches the coordinator + 2 views with an error-prone string→enum mapping.
- **Do:** replace `var workoutWarning: String?` with `enum WorkoutWarning { case unavailable, stoppedMidMatch, notSavedTooShort, failed(String) }`; style/prioritize in `WatchLiveMatchView`/`WatchMatchSummaryView` (the "under 10 min" case is normal, not an error); add tests asserting on cases.

### 5.3 `GuestPlayerNaming` structured marker
- **Why deferred:** changing the stored format needs a migration for existing "Guest N" names.
- **Do:** store guests by a stable structured marker/index rather than parsing a localized display string; keep backward parsing for already-stored names; add tests across locales.

### 5.4 Synthetic point timestamps
- **Why deferred:** needs a `PointEvent` / transfer-payload schema change.
- **Do:** carry a real per-point time (or relative offset) on `PointEvent` and persist it, or formally document `StoredPointEvent.timestamp` as synthetic and not for analytics. (`MatchTransferPayload.schemaVersion` is already in place to gate the migration.)

### 5.5 `Array[safe:]` consolidation (cosmetic)
- **Why deferred:** the file-private copies span PadelCore and the app target (plus an `Int?` variant on the Watch); a single shared one isn't worth a public API across the module boundary.
- **Do (optional):** one `public` (or `@usableFromInline internal`) extension in PadelCore + drop the per-file copies, if you want the tidiness.

### 5.6 Larger `WatchMatchCoordinator` decomposition (rest of P3-1)
- **Why deferred:** only the explicit `ContinuationState` was done; a full split is risky blind.
- **Do (optional):** extract a `LiveMatchPersistence` protocol wrapping `WatchMatchStore` (so crash-recovery is unit-testable without real `UserDefaults`) and move serve/lineup helpers into the pure core, leaving the coordinator a thin lifecycle orchestrator. Add tests for crash recovery and the three continue-new-set paths.

---

## 6. Done when

- [ ] PadelCore builds + all tests green.
- [ ] Both app targets build with no new errors.
- [ ] The §3 device behaviors verified on real iPhone + Watch.
- [ ] Deferred items (§5) triaged — at least 5.1 (the remaining P1-5 perf) and 5.2/5.3/5.4 scheduled or done.
- [ ] Then it's safe to proceed to the [app-themes](app-themes.md) work (do §5.1 and the serve/stats memoization verification first, since themes touch the same live/stats views).
