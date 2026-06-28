# Plan — Code Improvements & Optimizations (current codebase)

> A grounded improvement backlog for PadelNote **as it stands today**, before the [app-themes](app-themes.md) work. Focus: correctness/data-integrity bugs, performance, duplication, and maintainability — no new product features.

**How this was produced:** a read-only audit of `PadelCore`, the iOS target, and the watchOS target (engine/model/stats, persistence/sync, iOS views/services, watch views/coordinator). Findings are tied to real `file:line` locations. Two of the highest-impact items were verified directly against source (✅ **verified** below).

**Why now:** several P1 performance items live in the same live-match / stats views the themes plan will touch. Doing the correctness fixes (P0) and the shared-logic extraction (P2) first keeps the themes work from layering color onto duplicated/expensive code.

---

## Priority summary

| # | Item | Priority | Impact | Effort | Area |
|---|---|---|---|---|---|
| P0-1 | Live-score sync silently drops serve info (codec) | **P0** | High | Low | sync |
| P0-2 | `saveTransferredMatch` rebuilds all points + no stale-overwrite guard | **P0** | High | Med | persistence |
| P0-3 | Completed match can be lost if `transferUserInfo` fails | **P0** | High | Low | sync |
| P0-4 | `findOrCreatePlayer` can mint duplicate Player rows in one batch | **P0** | Med-High | Med | persistence |
| P0-5 | Name-only auto-linking merges different people's stats | **P0** | Med | Med | persistence |
| P1-1 | Expensive derived data recomputed in SwiftUI `body` | **P1** | High | Med | iOS views |
| P1-2 | `MatchDetailView` timeline is O(n²) engine replays | **P1** | High | Med | iOS views |
| P1-3 | Serve computed by full event-log replay, not memoized | **P1** | High | Med | engine |
| P1-4 | Stats replay each match 2–3× per player; repeated filter passes | **P1** | High | Med | stats |
| P1-5 | Unbounded `@Query` + in-memory filtering (`isCompleted` faults all points) | **P1** | High | Med | persistence/views |
| P2-1 | Serve-order / lineup / deciding-side logic duplicated phone↔watch | **P2** | Med | Med | core extraction |
| P2-2 | Deciding/golden-point detection duplicated in 3 files | **P2** | Med | Low | core |
| P2-3 | 4-slot payload↔roster↔names mapping hand-copied ~6 places | **P2** | Med | Med | persistence |
| P3-1 | `WatchMatchCoordinator` is a 595-line god object | **P3** | Med | High | watch arch |
| P3-2 | Inconsistent/swallowed persistence + sync error handling | **P3** | Med | Med | cross-cutting |
| P3-3 | Workout start/end task race on cancel | **P3** | Med | Med | watch concurrency |
| P4 | Polish cluster (a11y, localization, HK store, dup row views, …) | **P4** | Low | Low | misc |

---

## P0 — Correctness & data-integrity (fix first)

### P0-1 — Live-score sync drops serve info on every update ✅ verified
- **Where:** `encodeLiveScore` [SyncPayloadCodec.swift:30-63](../../PadelCore/Sources/PadelCore/Sync/SyncPayloadCodec.swift#L30-L63); decode fallback [:113-160](../../PadelCore/Sources/PadelCore/Sync/SyncPayloadCodec.swift#L113-L160).
- **Problem:** Unlike the other payload kinds (which embed a full JSON blob via `encoded<T>`), `encodeLiveScore` hand-builds a flat dictionary that contains **no `payload` blob and none of `servingTeam` / `serveSide` / `servingPlayerName`**. The watch sets those fields in `publishSnapshot()` ([WatchMatchCoordinator.swift:559-573](../../PadelNoteWatch/WatchMatchCoordinator.swift#L559-L573)), but they're discarded in transit, so the phone's live mirror serve line ([WatchLiveMirrorView.swift:49-58](../../PadelNote/Views/WatchLiveMirrorView.swift#L49-L58)) is always empty.
- **Fix:** Have `encodeLiveScore` embed `JSONEncoder().encode(snapshot)` under `payloadKey` (mirroring `encoded<T>`), keeping the flat keys only as a legacy fallback. Add a round-trip test asserting serve fields survive.
- **Effort:** Low.

### P0-2 — `saveTransferredMatch` rebuilds all points and can be clobbered by a stale retransmit ✅ verified
- **Where:** [MatchPersistence.swift:75-118](../../PadelCore/Sources/PadelCore/Persistence/MatchPersistence.swift#L75-L118) + `replacePoints` [:120-131](../../PadelCore/Sources/PadelCore/Persistence/MatchPersistence.swift#L120-L131).
- **Problem:** Re-receiving an already-saved match (the normal case — the watch re-flushes pending matches on each activation) **deletes every `StoredPointEvent` and re-inserts all of them**, and unconditionally overwrites `startedAt/endedAt/rules/winner/...` ([:98-109](../../PadelCore/Sources/PadelCore/Persistence/MatchPersistence.swift#L98-L109)) with **no ordering guard** — an out-of-order/older retransmit can overwrite a newer record.
- **Fix:** Skip `replacePoints` when the existing point count + event sequence already match (no-op). Add a monotonic guard (compare `payload.endedAt` / a version field) before overwriting.
- **Effort:** Med.

### P0-3 — Completed match lost if `transferUserInfo` fails
- **Where:** `sendCompletedMatch` removes the pending entry immediately after queueing ([WatchConnectivityPublisher.swift:52-58](../../PadelNoteWatch/Services/WatchConnectivityPublisher.swift#L52-L58)); no `didFinish userInfoTransfer:error:` delegate.
- **Problem:** The pending-match safety net is cleared before the OS confirms delivery; a failed transfer is unrecoverable.
- **Fix:** Implement `WCSessionDelegate.session(_:didFinish:error:)` and only `removePendingCompletedMatch` when `error == nil`; otherwise leave it for the next flush. Also log/inspect `outstandingUserInfoTransfers`.
- **Effort:** Low.

### P0-4 — `findOrCreatePlayer` can create duplicate Player rows in one resolve batch
- **Where:** [PlayerPersistence.swift:12-33](../../PadelCore/Sources/PadelCore/Persistence/PlayerPersistence.swift#L12-L33), `resolveRoster` [:62-78](../../PadelCore/Sources/PadelCore/Persistence/PlayerPersistence.swift#L62-L78); called up to 4× (+ per-set lineups) without an intervening save in [MatchPersistence.swift:61-72](../../PadelCore/Sources/PadelCore/Persistence/MatchPersistence.swift#L61-L72).
- **Problem:** `fetch().first` then `insert` without `processPendingChanges()` — a just-inserted, unsaved player for the same normalized name isn't reliably visible to the next lookup, so two slots with the same name can mint two `Player` rows. `Player.id` is unique but `normalizedName` is **not**, so the store won't reject it.
- **Fix:** Maintain an in-batch `[normalizedName: Player]` cache in `resolveRoster` (or `processPendingChanges()` between lookups). Add a test resolving a roster with a repeated name.
- **Effort:** Med.

### P0-5 — Name-only auto-linking merges different people
- **Where:** `linkableSlots`/`applyLinks` [UserAccountPersistence.swift:117-156](../../PadelCore/Sources/PadelCore/Persistence/UserAccountPersistence.swift#L117-L156); `backfillUnlinkedMatches` [PlayerPersistence.swift:220-252](../../PadelCore/Sources/PadelCore/Persistence/PlayerPersistence.swift#L220-L252).
- **Problem:** Linking matches purely on `normalizeName(...) == player.normalizedName`. Two different people sharing a normalized name (common first names, diacritic/case folding) get merged into one identity across history, silently corrupting per-player stats. `applyLinks` also hard-codes a positional `switch index {0,1,2,3}` coupled to tuple order.
- **Fix:** Only auto-link when the slot id is `nil` **and** no other distinct player shares that normalized name; otherwise record a merge candidate for user confirmation. Replace the positional switch with a slot-enum + keypath mapping (ties into P2-3).
- **Effort:** Med.

---

## P1 — Performance

The dominant theme: **expensive derived data (engine replays, JSON decodes, full-history `map(\.summary)`, DB fetches) computed inside `body`-evaluated computed properties**, so it re-runs on every render and grows with history.

### P1-1 — Cache derived stats/summaries out of `body`
- **Where:** `StatsView` [:10-33](../../PadelNote/Views/StatsView.swift#L10-L33), `PlayerDetailView` [:8-41](../../PadelNote/Views/PlayerDetailView.swift#L8-L41) (also re-derives full history at each navigation level), `NewMatchSetupView` [:27-33](../../PadelNote/Views/NewMatchSetupView.swift#L27-L33) (full DB fetches in computed vars, per keystroke).
- **Fix:** Compute `summaries`/insights once via an `@Observable` view model or `.task(id:)` keyed on the match-set identity; populate `NewMatchSetupView`'s name lists in `onAppear` (next to the existing prune) or back them with `@Query`.
- **Impact/Effort:** High / Med.

### P1-2 — `MatchDetailView` timeline is O(n²) replays
- **Where:** [MatchDetailView.swift:47-64](../../PadelNote/Views/MatchDetailView.swift#L47-L64); each row calls `match.scoreLine(afterPointCount:)` (full `ScoringEngine.replay` of a prefix, [Match.swift:202-214](../../PadelCore/Sources/PadelCore/Persistence/Match.swift#L202-L214)) **twice** (display + a11y).
- **Fix:** Replay once, capturing the score line after each point into `[String]`; reuse the same string for `Text` and accessibility. Consider a PadelCore "score line per point" helper. Also bind `inProgressSetSummary` to a single local ([:23,33](../../PadelNote/Views/MatchDetailView.swift#L23)).
- **Impact/Effort:** High / Med.

### P1-3 — Serve recomputed by full event-log replay, multiple times per render
- **Where:** `ServeEngine.timeline`/`currentServe` ([ServeEngine.swift:67,187](../../PadelCore/Sources/PadelCore/Engine/ServeEngine.swift#L67)); consumed as a computed property in [LiveMatchView.swift:37](../../PadelNote/Views/LiveMatchView.swift#L37) and across [WatchLiveMatchView.swift](../../PadelNoteWatch/Views/WatchLiveMatchView.swift) (`playerNameLabel`/`serveIndicator`/`serveAlignment`/`serveAccessibilityLabel`) and `publishSnapshot`.
- **Problem:** `timeline` replays the whole log from an empty state on every call, ignoring `ScoringSession`'s cached `stateHistory`; a single render triggers several replays, and it re-runs per point as the log grows.
- **Fix:** Read `serve` into one `let` at the top of each `body` and pass it to helpers. In the coordinator, cache the `ServeContext` keyed by `(events.count, decidingSideOverride, setServeOrders)`. Longer term, expose an incremental serve cursor reusing the session's cached state.
- **Impact/Effort:** High / Med.

### P1-4 — Stats replay each match 2–3× per player and re-filter repeatedly
- **Where:** [MatchStatistics.swift:179,205,220](../../PadelCore/Sources/PadelCore/Stats/MatchStatistics.swift#L179) (timeline + replay + goldenPointCounts, all full replays per match per player); repeated `summaries.filter(\.isCompleted)` at [:5,47,94,144](../../PadelCore/Sources/PadelCore/Stats/MatchStatistics.swift#L5); O(n²) prefix-dedupe in player picker [PlayerPersistence.swift:179-206](../../PadelCore/Sources/PadelCore/Persistence/PlayerPersistence.swift#L179-L206).
- **Fix:** Replay each match **once** into a reusable per-match derived struct (final state, completed sets, serve timeline, golden-point situations); feed all player/team computations from it. Filter completed matches once at the API boundary (e.g. a `computeAll(...)`). Replace nested-`contains` dedupe with a sorted single pass.
- **Impact/Effort:** High / Med.

### P1-5 — Unbounded `@Query` + in-memory filtering; `isCompleted` faults all points
- **Where:** `@Query` with no predicate/limit in [HomeView.swift:7](../../PadelNote/Views/HomeView.swift#L7), [StatsView.swift:7-8](../../PadelNote/Views/StatsView.swift#L7-L8), [PlayerDetailView.swift:8-9](../../PadelNote/Views/PlayerDetailView.swift#L8-L9), [MatchHistoryView.swift:8](../../PadelNote/Views/MatchHistoryView.swift#L8); history-wide fetches with no predicate in [PlayerPersistence.swift:112-177](../../PadelCore/Sources/PadelCore/Persistence/PlayerPersistence.swift#L112-L177) (called every sync via `distinctDisplayNames`, [PhoneSyncCoordinator.swift:46](../../PadelNote/Services/PhoneSyncCoordinator.swift#L46)).
- **Problem:** `Match.isCompleted` ([Match.swift:180](../../PadelCore/Sources/PadelCore/Persistence/Match.swift#L180)) reads `sortedPoints`, faulting **all** point rows for **every** match just to decide "completed" — and it's re-evaluated on every render and every sync.
- **Fix:** Persist a stored `isCompleted`/`endedAt`-based flag so filtering can be a SwiftData predicate (and `HomeView` can use `fetchLimit`). Batch the per-id `fetchPlayer` loop into one `#Predicate { ids.contains($0.id) }`. Cache `distinctDisplayNames` instead of recomputing on every context sync.
- **Impact/Effort:** High / Med.

> Lower-impact perf items rolled in here: `MatchScoreText.make` runs a replay twice per row and can skip the replay entirely for finished matches ([MatchScoreText.swift:7-26](../../PadelNote/Views/MatchScoreText.swift#L7-L26), [MatchRowView.swift:14,35](../../PadelNote/Views/MatchRowView.swift#L14)); `players.first(where:)` lookups inside `ForEach` → build a `[UUID: Player]` map ([StatsView.swift:83](../../PadelNote/Views/StatsView.swift#L83), [PlayerDetailView.swift:115](../../PadelNote/Views/PlayerDetailView.swift#L115)); `persistLiveState()` re-encodes the whole match per point — hoist a static `JSONEncoder` and split immutable header from the per-point delta ([WatchMatchCoordinator.swift:314-327](../../PadelNoteWatch/WatchMatchCoordinator.swift#L314-L327), [WatchMatchStore.swift:59-98](../../PadelNoteWatch/Services/WatchMatchStore.swift#L59-L98)); drop the redundant `sendMessage` double-send or throttle it ([WatchConnectivityPublisher.swift:44-50](../../PadelNoteWatch/Services/WatchConnectivityPublisher.swift#L44-L50)).

---

## P2 — Duplication → extract into PadelCore (pure & testable)

### P2-1 — Serve-order / lineup / deciding-side logic duplicated phone↔watch
- **Where:** iOS `LiveMatchView.syncServeOrders()` [:257-271](../../PadelNote/Views/LiveMatchView.swift#L257-L271) vs watch `WatchMatchCoordinator.syncSetServeOrders()` [:204-221](../../PadelNoteWatch/WatchMatchCoordinator.swift#L204-L221) (near-verbatim); plus duplicated `currentServe`/`needsDecidingSideChoice`/deciding-override clearing ([LiveMatchView.swift:37-50](../../PadelNote/Views/LiveMatchView.swift#L37-L50) vs [WatchMatchCoordinator.swift:107-122](../../PadelNoteWatch/WatchMatchCoordinator.swift#L107-L122)); watch-only `syncSetLineups` is also general.
- **Fix:** Add pure helpers in PadelCore — e.g. `ServeOrder.aligned(orders:completedSetCount:firstServer:)` and a small `LiveServeModel` value type (`currentServe`, `needsDecidingSideChoice`, `chooseDecidingSide`, `clearOverride`). Both targets consume them; unit-test the inherit/truncate behavior.
- **Impact/Effort:** Med / Med.

### P2-2 — Deciding/golden-point detection duplicated in 3 files
- **Where:** `ServeEngine.isDecidingPoint` [:243](../../PadelCore/Sources/PadelCore/Engine/ServeEngine.swift#L243), `ScoreFormatter` [:38-52](../../PadelCore/Sources/PadelCore/Engine/ScoreFormatter.swift#L38-L52), `MatchStatistics.isGoldenPointSituation` [:332](../../PadelCore/Sources/PadelCore/Stats/MatchStatistics.swift#L332).
- **Fix:** Single source of truth, e.g. `MatchState.isSuddenDeathPoint`; all three call it. Add a test asserting the three former call sites agree across rule styles.
- **Impact/Effort:** Med / Low.

### P2-3 — 4-slot payload↔roster↔names mapping hand-copied ~6 places
- **Where:** [MatchPersistence.swift:55-72,98-109](../../PadelCore/Sources/PadelCore/Persistence/MatchPersistence.swift#L55-L72); [PlayerPersistence.swift:67-95,118-130,225-241](../../PadelCore/Sources/PadelCore/Persistence/PlayerPersistence.swift#L67-L95); [UserAccountPersistence.swift:118-156](../../PadelCore/Sources/PadelCore/Persistence/UserAccountPersistence.swift#L118-L156); [Match.swift:57-94,107-114](../../PadelCore/Sources/PadelCore/Persistence/Match.swift#L57-L94).
- **Fix:** Centralize conversions — `MatchPlayerSetup(payload:)`, `MatchTransferPayload(roster:names:)`, `Match.apply(roster:names:metrics:)` — and replace positional `applyLinks` with a slot-enum + keypaths.
- **Impact/Effort:** Med / Med.

> Also: `Array[safe:]` is redefined privately per file ([MatchStatistics.swift:350-354](../../PadelCore/Sources/PadelCore/Stats/MatchStatistics.swift#L350-L354), [WatchLiveMatchView.swift:314-319](../../PadelNoteWatch/Views/WatchLiveMatchView.swift#L314-L319)) → one internal extension. Duplicated summary-row views ([StatsView.swift:115-147](../../PadelNote/Views/StatsView.swift#L115-L147) ≈ [PlayerDetailView.swift:144-176](../../PadelNote/Views/PlayerDetailView.swift#L144-L176)) → one shared row.

---

## P3 — Architecture & robustness

### P3-1 — `WatchMatchCoordinator` god object
- **Where:** [WatchMatchCoordinator.swift](../../PadelNoteWatch/WatchMatchCoordinator.swift) (595 lines): scoring/phase machine + serve/lineup engine + persistence orchestration + workout lifecycle + sync + player/me-profile setup + summary formatting. The "continue-new-set then end" rollback (`rulesBeforeContinue`/`continueBaselineEventCount`, [:336-339,364-381,469-490](../../PadelNoteWatch/WatchMatchCoordinator.swift#L336-L339)) is subtle and untested.
- **Fix:** Extract (a) a pure `ServeLineupEngine` (→ P2-1), (b) a `LiveMatchPersistence` helper behind a protocol wrapping `WatchMatchStore` (so crash-recovery is testable without real `UserDefaults`), (c) model continuation as an explicit `enum ContinuationState`. Keep the coordinator a thin phase/lifecycle orchestrator. Add tests for the three continue paths.
- **Impact/Effort:** Med / High.

### P3-2 — Inconsistent / swallowed error handling
- **Where:** `saveCompletedMatch` ends in `try? context.save()` and returns the match regardless ([MatchPersistence.swift:39](../../PadelCore/Sources/PadelCore/Persistence/MatchPersistence.swift#L39)) — inconsistent with `saveTransferredMatch`'s `do/catch`; widespread `try?` on fetch/save across [PlayerPersistence.swift](../../PadelCore/Sources/PadelCore/Persistence/PlayerPersistence.swift)/[UserAccountPersistence.swift](../../PadelCore/Sources/PadelCore/Persistence/UserAccountPersistence.swift); codec `encoded<T>` drops the payload on encode failure and all decoders `try?` ([SyncPayloadCodec.swift:85-91](../../PadelCore/Sources/PadelCore/Sync/SyncPayloadCodec.swift#L85-L91)); empty `sendMessage` error closure ([WatchConnectivityPublisher.swift:47-49](../../PadelNoteWatch/Services/WatchConnectivityPublisher.swift#L47-L49)).
- **Fix:** Make `saveCompletedMatch` `throws`/`-> Match?` and surface failures at [LiveMatchView.swift:275](../../PadelNote/Views/LiveMatchView.swift#L275); `assertionFailure`/log swallowed saves in debug; add a `version: Int` to transfer payloads for explicit migration.
- **Impact/Effort:** Med / Med.

### P3-3 — Workout start/end task race
- **Where:** `startWorkoutInBackground` [:302-312](../../PadelNoteWatch/WatchMatchCoordinator.swift#L302-L312), `saveMatch`/`discardMatch` await the task then `end()`, `reset()` cancels it [:418-419](../../PadelNoteWatch/WatchMatchCoordinator.swift#L418-L419); `HealthKitWorkoutRecorder.start` isn't cancellation-aware between awaits ([:87-91](../../PadelNoteWatch/Services/HealthKitWorkoutRecorder.swift#L87-L91)).
- **Problem:** A cancel mid-start can leave an `HKWorkoutSession` started with no matching `end()`.
- **Fix:** Check `Task.isCancelled` after each `await` in `start()` and tear down if cancelled; have `reset()`/`discardMatch` drive the recorder to a terminal state (`end()`/`cancelStart()`) rather than just cancelling.
- **Impact/Effort:** Med / Med.

---

## P4 — Polish (low effort, low risk)

- **`CurrentUserStore.restoreSession`** stale-credential callback can sign out a re-authenticated user / use a torn-down context — re-validate `accountID`/`modelContext` inside the `@MainActor` block ([CurrentUserStore.swift:34-43](../../PadelNote/Services/CurrentUserStore.swift#L34-L43)).
- **`HealthKitAuthorizationChecker`** creates a new `HKHealthStore()` per status check → share one static instance ([HealthKitAuthorizationChecker.swift:14-15](../../PadelNote/Services/HealthKitAuthorizationChecker.swift#L14-L15)).
- **`MatchPlayersEditSection`** saves only on `onDisappear`/`onSubmit` (edits can be lost on background/kill) and builds an a11y label with plain interpolation instead of `String(localized:)` ([MatchPlayersEditSection.swift:48,59,71-95](../../PadelNote/Views/MatchPlayersEditSection.swift#L48)).
- **`NewMatchSetupView`** "First serve" picker + rows lack accessibility labels ([:74-80,113-116](../../PadelNote/Views/NewMatchSetupView.swift#L74-L80)).
- **`MatchHistoryView.deleteMatches`** indexes into a render-time-recomputed sorted slice → delete by identity ([MatchHistoryView.swift:49-67](../../PadelNote/Views/MatchHistoryView.swift#L49-L67)).
- **HealthKit force-unwraps** `quantityType(forIdentifier:)!` ×3 → `compactMap`/guard ([HealthKitWorkoutRecorder.swift:38-40](../../PadelNoteWatch/Services/HealthKitWorkoutRecorder.swift#L38-L40)).
- **`workoutWarning: String?`** overloaded for 3 meanings (incl. the *normal* "under 10 min") → small enum so views can style/prioritize and tests assert on cases ([WatchMatchCoordinator.swift:38,392](../../PadelNoteWatch/WatchMatchCoordinator.swift#L38)).
- **`GuestPlayerNaming`** parses a localized display string to detect guests (locale-fragile) → use a structured marker/index ([GuestPlayerNaming.swift:34-47](../../PadelCore/Sources/PadelCore/Preferences/GuestPlayerNaming.swift#L34-L47)).
- **`ScoringSession.state`** `?? MatchState(rules:)` fallback masks a broken invariant → `precondition(!stateHistory.isEmpty)` ([ScoringEngine.swift:230-232](../../PadelCore/Sources/PadelCore/Engine/ScoringEngine.swift#L230-L232)).
- **Synthetic point timestamps** fabricated at fixed 20s/30s intervals → carry a real offset on `PointEvent` or document as non-analytic ([MatchPersistence.swift:32,143](../../PadelCore/Sources/PadelCore/Persistence/MatchPersistence.swift#L32)).

---

## Test-coverage gaps to close alongside

- `winByTwoGames: false` set-win boundary (with/without tie-break) — currently untested ([ScoringEngine.swift:147-157](../../PadelCore/Sources/PadelCore/Engine/ScoringEngine.swift#L147-L157)).
- Deciding/golden-point agreement across the 3 call sites (P2-2).
- Serve-order/lineup alignment + continue-new-set rollback once extracted to core (P2-1, P3-1).
- `resolveRoster` duplicate-name → single Player (P0-4); re-received-match no-op + stale-overwrite guard (P0-2).
- `LiveScoreSnapshot` round-trip preserves serve fields (P0-1); codec behavior on missing/malformed `payload`.
- `GuestPlayerNaming` and the `UserDefaults`-backed `*Preferences` enums have **no** tests today.

---

## Suggested sequencing

1. **P0 bugs** (small, high value; P0-1/P0-3 are quick wins) + their regression tests.
2. **P2 extractions** (serve/lineup, deciding-point, mapping) — removes duplication *before* perf and themes work touch the same code.
3. **P1 performance** — view-model/memoization pass (StatsView, PlayerDetailView, MatchDetailView, NewMatchSetupView, MatchRowView), serve memoization, stats single-replay, and the `isCompleted`-flag/`@Query`-predicate change.
4. **P3 architecture** (coordinator split, error handling, workout race) — larger, do when P0–P2 are stable.
5. **P4 polish** — opportunistic, alongside the above.

> Do **P1-1/P1-3** before the themes plan's live-match/Stats changes so color treatments land on memoized, decomposed views rather than on the current `body`-recompute paths.

---

## Out of scope

- New features (themes, CloudKit, Live Activity, etc. — tracked elsewhere).
- Broad restyle/redesign of screens.
- Dependency or tooling changes.
