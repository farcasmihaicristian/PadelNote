# PadelNote

> The Padel scoring app for iPhone + Apple Watch, with HealthKit integration and a rich, journal-style match history. This single document is the source of truth for the project: positioning, scope, architecture, decisions, environment setup, and the full roadmap with current status.

**Tagline:** *"Keep score. Keep history. Keep playing."*

**Bundle IDs:** `farca.PadelNote` (iOS), `farca.PadelNote.watchkitapp` (Watch)
**Minimum OS:** iOS 17 / watchOS 10
**Status:** Milestones 0–6 complete. Next up: branding (M7), then Apple Developer enrollment + TestFlight (M8).

---

## Table of contents

1. [Current status at a glance](#1-current-status-at-a-glance)
2. [Positioning & differentiation](#2-positioning--differentiation)
3. [Product scope (v1)](#3-product-scope-v1)
4. [Tech stack & architecture](#4-tech-stack--architecture)
5. [Scoring engine design](#5-scoring-engine-design)
6. [Screens](#6-screens)
7. [Roadmap — what's done & what's next](#7-roadmap--whats-done--whats-next)
8. [Decision log](#8-decision-log)
9. [Environment & setup](#9-environment--setup)
10. [App Store submission checklist](#10-app-store-submission-checklist)
11. [Working conventions](#11-working-conventions)
12. [Open questions](#12-open-questions)

---

## 1. Current status at a glance

| Milestone | Scope | Status |
|---|---|---|
| 0 | Environment (Mac, Xcode, devices, AnyDesk) | ✅ Done |
| 1 | Project skeleton (iOS + Watch + PadelCore) | ✅ Done |
| 2 | Scoring engine + unit tests | ✅ Done (35 tests green) |
| 3 | Persistence + iPhone home/history | ✅ Done |
| 4 | iPhone match flow (setup → live → detail) | ✅ Done |
| 5 | Watch app + HealthKit + WatchConnectivity sync | ✅ Done |
| 6 | Stats, settings, polish, Spanish localization | ✅ Done |
| 7 | Branding (app icon, launch screen, Watch icon) | ⏭️ Next |
| 8 | Apple Developer enrollment + TestFlight | ⬜ Pending |
| 9 | App Store submission | ⬜ Pending |
| 10 | Post-launch (v1.1+) | ⬜ Backlog |

**Latest tagged work:** `0.6b` — Milestone 6 (Insights screen, Settings Health/About, workout data on match detail, Spanish `Localizable.xcstrings`, Dynamic Type on live score).

**Extras shipped on top of the original plan:**
- HealthKit workouts under 10 minutes are discarded (avoids junk entries while testing).
- Pull-to-refresh on Home re-syncs from the Watch.
- Settings page stores default match rules; New Match setup pre-loads them.
- Insights screen with win rate, average/longest duration, and golden-point conversion.

---

## 2. Positioning & differentiation

The padel scoring category is crowded (Padely, Padel Tally, Padel Point, Padel Score, Padelio, and more). PadelNote's hooks:

1. **The "Note" angle** — every match is a journal entry. Rich history & point-by-point timeline are first-class, not paywalled.
2. **Rule transparency** — Golden Point vs Advantage vs Star Point, classic vs super tie-break, configurable per match and explained in the UI.
3. **No subscription for the core experience** — scoring + history + HealthKit are always free. Optional one-time IAP for advanced stats later.
4. **Apple Watch first** — the Watch app is standalone and the canonical scoring surface.
5. **Privacy-first** — no analytics SDKs in v1, no account required, data lives on-device (and your iCloud later, not ours).

Keep these pillars visible in the App Store description, screenshots, and reviewer notes.

---

## 3. Product scope (v1)

### iPhone app
- Start a new match with configurable rules: sets to win (best-of-1/3/5), games per set (default 6, tie-break at 6–6), tie-break style (classic 7 / super tie-break 10 for deciding set), deuce style (Golden Point / Advantage / Star Point), optional team names.
- Live scoring screen.
- Match history list + detail view with point-by-point timeline.
- Stats/Insights: win rate, average match duration, longest match, golden-point conversion.
- Settings: default rules, HealthKit status, about.

### Apple Watch app
- Start a match from the wrist, tap to add a point to either team, undo last point.
- Shows current game / set / match score.
- Records an `HKWorkout` (`.tennis`, metadata Padel/padel) with heart rate, active energy, distance.

### Apple Health
- Writes the workout to HealthKit (duration, calories, heart-rate samples, distance) — only for matches ≥ 10 minutes.
- Reads heart rate / energy during the live session.

### Sync
- WatchConnectivity for live score sync Watch → iPhone, and the final match record on save.
- CloudKit (private DB) for multi-device history sync — **deferred to v1.1** (see D-05).

---

## 4. Tech stack & architecture

| Concern | Choice | Why |
|---|---|---|
| Language | Swift 5.10+ | Native Watch & HealthKit |
| UI | SwiftUI (iOS 17 / watchOS 10) | One codebase, both platforms |
| Persistence | SwiftData | Modern, CloudKit-ready |
| Sync (later) | CloudKit via `ModelConfiguration(cloudKitDatabase:)` | Free, no backend |
| Watch ⇄ Phone | WatchConnectivity (`WCSession`) | Low-latency live updates |
| Workouts | HealthKit (`HKWorkoutSession` + `HKLiveWorkoutBuilder`) | Proper workout recording |
| Bundle | One project, two app targets + `PadelCore` package | Modern pattern |

### Project layout
```
PadelNote/
├─ PadelNote/              ← iOS app
│  ├─ Views/               ← Home, NewMatchSetup, LiveMatch, MatchHistory,
│  │                          MatchDetail, Stats, Settings, WatchLiveMirror, …
│  ├─ Services/            ← PhoneConnectivityListener, PhoneSyncCoordinator,
│  │                          MatchSyncListening, HealthKitAuthorizationChecker
│  ├─ Localizable.xcstrings ← EN + ES
│  └─ PadelNoteApp.swift
├─ PadelNoteWatch/         ← watchOS app
│  ├─ Views/               ← WatchStart, WatchLiveMatch, WatchMatchSummary
│  ├─ Services/            ← WatchConnectivityPublisher, HealthKitWorkoutRecorder,
│  │                          WorkoutRecording, NoOpWorkoutRecorder, MatchSyncPublishing
│  └─ WatchMatchCoordinator.swift
├─ PadelCore/              ← pure Swift package (no Apple UI frameworks)
│  ├─ Sources/PadelCore/
│  │  ├─ Model/            ← Team, GamePointStyle, TieBreakStyle, MatchRules, MatchState, …
│  │  ├─ Engine/           ← ScoringEngine, ScoreFormatter
│  │  ├─ Persistence/      ← Match, StoredPointEvent, MatchPersistence, MatchFormatting, SampleMatchData
│  │  ├─ Preferences/      ← MatchRulesPreferences
│  │  ├─ Stats/            ← MatchStatistics, MatchInsights, MatchSummary
│  │  └─ Sync/             ← LiveScoreSnapshot, MatchTransferPayload, SyncPayloadCodec
│  └─ Tests/PadelCoreTests/
└─ PadelNote.xcodeproj
```

### Data-flow pattern
- **Watch is source of truth** during a live match (it owns score state and the workout session).
- iPhone **mirrors** the live score (via `updateApplicationContext` + reachable `sendMessage`) and **persists** the final match (via `transferUserInfo`) when you tap Save on the Watch.
- HealthKit / WatchConnectivity / persistence are wrapped behind protocols (`WorkoutRecording`, `MatchSyncPublishing`, `MatchSyncListening`) so the engine and view models stay testable.

---

## 5. Scoring engine design

The engine in `PadelCore` is pure, deterministic, and unit-tested — no UI, no HealthKit. Everything else wraps it.

```swift
enum Team { case a, b }

enum GamePointStyle {
    case advantage     // classic tennis: deuce → advantage → game
    case goldenPoint   // sudden death at 40-40 ("punto de oro")
    case starPoint     // advantage for the first two deuces, then sudden death (see D-11)
}

enum TieBreakStyle {
    case none              // play out games (rare)
    case classic           // first to 7, win by 2, at 6-6
    case superTieBreak10   // first to 10, win by 2 (often for the deciding set)
}

struct MatchRules: Codable, Hashable {
    var setsToWin: Int = 2
    var gamesPerSet: Int = 6
    var winByTwoGames: Bool = true
    var gamePointStyle: GamePointStyle = .advantage   // default preset overrides to .goldenPoint (D-03)
    var setTieBreak: TieBreakStyle = .classic
    var finalSetTieBreak: TieBreakStyle = .superTieBreak10
}
```

- Game points encoded `0,1,2,3` → display `0/15/30/40`; advantage shown as "Ad".
- Pure transition: `apply(point: Team, to: MatchState) -> MatchState`.
- **Undo** = replay the `[PointEvent]` log from zero (simplest correct undo).
- Tests cover deuce, advantage, golden point, star point (deuce #1/#2 advantage, deuce #3 sudden death), tie-break entry at 6-6, set win at 7-5, super tie-break in the deciding set, match win, undo, idempotency, plus the stats insights. Run with `swift test` in `PadelCore/` (no simulator needed).

---

## 6. Screens

### iPhone
1. **Home** — Start match, Insights link, live Watch mirror banner, recent matches; History (top-left) and Settings (top-right) in the toolbar; pull-to-refresh.
2. **New match setup** — rule pickers (pre-loaded from saved defaults) + optional team names.
3. **Live match** — large score readouts, +1 per team, undo, end match.
4. **Match history** — list grouped by month.
5. **Match detail** — final score, sets breakdown, duration, point-by-point timeline, and workout data (avg HR, calories, distance) when available.
6. **Stats / Insights** — win rate, average/longest match, golden-point conversion.
7. **Settings** — default rules, HealthKit status, about.

### Apple Watch
1. **Start** — last rules used + Start.
2. **Live score** — two big tappable zones (Team A / Team B), undo.
3. **End-of-match summary** — final score, duration, avg HR, Save (with a warning if the match was under 10 minutes and not saved to Health).

> SF Symbols, large Dynamic Type, full VoiceOver labels throughout.

---

## 7. Roadmap — what's done & what's next

### ✅ Done

**Milestone 0 — Environment**
Mac/Xcode set up, Apple ID Personal Team, iPhone trusted + WiFi pairing, AnyDesk for remote work.

**Milestone 1 — Project skeleton**
iOS + watchOS targets, `PadelCore` package (Model/Engine/Persistence), HealthKit capability on both targets, Background Modes → Workout processing on the Watch, HealthKit usage strings, clean baseline commit.

**Milestone 2 — Scoring engine + tests**
All domain types, `MatchState`, pure `apply(point:)`, undo via event-log replay, score formatters, ~35 passing tests covering every rule variant including Star Point.

**Milestone 3 — Persistence + iPhone home/history**
SwiftData `Match` + `StoredPointEvent`, ModelContainer wiring, Home (start + recent), history grouped by month, match detail v1, sample data for previews, localized + accessible from day one.

**Milestone 4 — iPhone match flow**
New match setup, live scoring driven by the engine, persistence of match + full point log on end, point-by-point timeline in detail.

**Milestone 5 — Watch + HealthKit + sync**
Watch start/live/summary screens, HealthKit auth + `HKWorkoutSession`/`HKLiveWorkoutBuilder` (`.tennis`, Padel metadata, HR/energy/distance), end-of-match summary + Save, WatchConnectivity (live snapshots + final match), iPhone live mirror + persistence, protocol-wrapped services, real-device test passed.

**Milestone 6 — Stats, polish, localization**
Insights screen, Settings (default rules + HealthKit status + about), workout metrics on match detail, dark mode / Dynamic Type / VoiceOver pass, Spanish `Localizable.xcstrings`.

### ⏭️ Next — Milestone 7: Branding
- [ ] 7.1 App icon — 1024×1024 single-size asset catalog (no Apple logos, no padel-association logos).
- [ ] 7.2 Launch screen.
- [ ] 7.3 Watch app icon.

**Done when:** the app looks shippable on a home screen.

### ⬜ Milestone 8 — Apple Developer account + TestFlight
- [ ] 8.1 Enroll in the Apple Developer Program — **Individual** (no D-U-N-S, fast).
- [ ] 8.2 **Lock the bundle ID** (resolves D-02) and switch Xcode signing to the paid team.
- [ ] 8.3 Create the App Store Connect record (bundle ID, SKU, primary language, category Sports / Health & Fitness).
- [ ] 8.4 Archive in Xcode → upload via Organizer.
- [ ] 8.5 Internal TestFlight round on your iPhone + Watch.
- [ ] 8.6 Fix bugs; repeat uploads.
- [ ] 8.7 Optional external TestFlight (light Apple review).

**Done when:** a TestFlight build has survived real matches on a real court.

### ⬜ Milestone 9 — App Store submission
- [ ] 9.1 Hosted 1-page privacy policy URL — **GitHub Pages**.
- [ ] 9.2 App Privacy declaration: Health & Fitness data → linked to user → not used for tracking; no third-party SDKs.
- [ ] 9.3 Screenshots: 6.7" iPhone (required), Apple Watch (required); no device frames, no in-image marketing copy.
- [ ] 9.4 App Store description + keywords around the differentiation pillars; optional preview video.
- [ ] 9.5 Pricing: Free.
- [ ] 9.6 Reviewer notes: explain padel rules briefly and why the workout type is "Tennis" (no Padel type in HealthKit).
- [ ] 9.7 Rejection-risk pass: clear HealthKit strings, graceful denied-permission handling, Watch standalone/dependency documented.
- [ ] 9.8 Submit for review (typically 24–48 h).
- [ ] 9.9 Release.

### ⬜ Milestone 10 — Post-launch (v1.1+)
CloudKit history sync (D-05) · share match summary as image · Live Activity / Dynamic Island score · rivals & partners head-to-head stats · Siri Shortcuts ("start a Padel match") · court location for "matches near you" · optional one-time "Pro stats" IAP (v1.2+).

---

## 8. Decision log

Each decision: what was chosen, why, and status. `✅ Locked` · `⏳ Pending` · `🔄 Revisable`.

- **D-00 — App name: PadelNote.** "Note" positions it as a journaling/history tool, the core differentiator. ✅ Locked
- **D-01 — Minimum OS: iOS 17 / watchOS 10.** Enables SwiftData, `@Observable`, modern SwiftUI; 90%+ device coverage. ✅ Locked
- **D-02 — Bundle identifier.** Currently `farca.PadelNote` / `farca.PadelNote.watchkitapp`. Must be final before the first TestFlight upload (cannot change after). ⏳ Pending — confirm before M8.
- **D-03 — Default rule preset.** Best-of-3, 6 games, classic tie-break at 6-6, super tie-break in the deciding set, **Golden Point ON**. Matches modern recreational padel. ✅ Locked
- **D-04 — Languages at launch.** English primary + **Spanish** (largest padel demographic). Spanish `.xcstrings` now shipped. ✅ Locked (was 🔄)
- **D-05 — CloudKit sync.** Deferred to v1.1; local SwiftData only in v1. SwiftData makes the later switch a one-line config change. ✅ Locked for v1
- **D-06 — `PadelCore` as a separate Swift Package.** Testable on Mac without a simulator; shared by both app targets; enforces a clean boundary. ✅ Locked
- **D-07 — Watch is source of truth during a live match.** Best UX (wrist), accurate HR, natural Watch→Phone flow. Each point is persisted to mitigate Watch crashes. ✅ Locked
- **D-08 — HealthKit workout type `.tennis`.** No `.padel` type exists; add `HKMetadataKeyWorkoutBrandName = "Padel"` + `"sport" = "padel"`. Fitness app shows "Tennis" — disclose in reviewer notes. ✅ Locked
- **D-09 — No analytics SDK in v1.** Simplest privacy label, lowest review risk, aligns with privacy pillar. ✅ Locked for v1
- **D-10 — Free app, optional one-time IAP later (no subscription).** Removes first-run friction; one-time IAP (advanced stats) planned for v1.2+. ✅ Locked for v1
- **D-11 — Star Point (third deuce style).** Advantage for the first two deuces, then sudden death; caps game length while rewarding deuce wins. Default stays Golden Point; Star Point is opt-in. Kept the "Star Point" name, with a short "Deuce rules explained" note in Settings clarifying it means limited advantage (2 deuces only). ✅ Locked

> Record any new decision here with its rationale before moving on.

---

## 9. Environment & setup

> Development happens on a remote Mac via AnyDesk. Physical-device testing (HealthKit, WatchConnectivity) only works when the iPhone + Mac share a WiFi network — plan those sessions accordingly; use the Simulator otherwise.

### One-time Mac setup
1. **macOS** Sequoia 15+ (update first if needed).
2. **Xcode 16+** from the Mac App Store; then `xcode-select --install` and `sudo xcodebuild -license accept`.
3. **Apple ID** in Xcode → Settings → Accounts (free Personal Team is enough to run on your own devices).
4. **iPhone** paired via USB (tap Trust), then enable **Connect via network** in Window → Devices and Simulators so it works over WiFi.
5. **Apple Watch** is discovered through the paired iPhone — no cable needed.
6. **AnyDesk** installed with unattended access for remote work.

### Project bootstrap (already done — for reference)
- iOS App target `PadelNote` (SwiftUI, Storage: None).
- watchOS target `PadelNoteWatch` (SwiftUI, no Notification Scene).
- Local Swift Package `PadelCore` with `Model/`, `Engine/`, `Persistence/` (plus `Preferences/`, `Stats/`, `Sync/`), linked into both targets.
- HealthKit capability on both targets; Background Modes → Workout processing on the Watch.
- Info.plist usage strings on both targets:
  - `NSHealthShareUsageDescription`: "PadelNote reads your heart rate and calories during matches to show accurate workout stats."
  - `NSHealthUpdateUsageDescription`: "PadelNote saves your padel matches to Apple Health as workouts."

### Remote workflow & accounts
- Connect via AnyDesk; keep the iPhone on the same WiFi as the Mac for device testing, otherwise use the Simulator.
- The free Apple ID covers running on your own devices and local HealthKit/WatchConnectivity testing. The **$99/year Apple Developer Program** is only needed at Milestone 8 (TestFlight + App Store).

### Known device gotcha (iOS 26 / Xcode 26 betas)
The Watch can disconnect in Xcode with `CoreDeviceError 4000 … enablePersonalizedDDI` ("The device disconnected immediately after connecting"). Mitigations: install via Xcode Run (scheme `PadelNote`) rather than manual install, keep Developer Mode on for both iPhone and Watch, use USB + same WiFi, restart both devices, and keep beta OS/Xcode versions aligned.

---

## 10. App Store submission checklist

1. **Apple Developer Program** — enroll ($99/year).
2. **App Store Connect** — app record: bundle ID (must match Xcode), SKU, primary language; category Sports + Health & Fitness.
3. **App Privacy** — Health & Fitness data → linked to user → not used for tracking; no third-party analytics.
4. **Privacy policy URL** — required for health data; host a 1-page policy (GitHub Pages is fine).
5. **Assets** — 6.7" iPhone screenshots + Apple Watch screenshots; no device frames, no in-image marketing copy.
6. **Build** — archive in Xcode → upload via Organizer.
7. **TestFlight** — at least one internal round.
8. **Reviewer notes** — explain padel rules and the "Tennis" workout type; no login/demo account needed.
9. **Common rejection risks** — weak HealthKit usage strings; crash when permissions denied; Watch app non-functional without iPhone (document or support standalone); names/icons implying Apple endorsement; league logos you don't own.
10. **Pricing** — Free in v1.
11. **Submit** — ~24–48 h review for a clean first build.

---

## 11. Working conventions

1. The scoring engine in `PadelCore` is pure Swift — no Apple frameworks in `Engine/`.
2. HealthKit / WatchConnectivity / SwiftData live behind protocols.
3. Watch is source of truth during live matches; phone mirrors and stores history.
4. Every feature lands behind a unit test, a SwiftUI preview, or a TestFlight build.
5. No hard-coded user-visible strings — always `String(localized:)`.
6. Accessibility labels on every interactive element.
7. New decision made? Record it in the [Decision log](#8-decision-log) before moving on.

---

## 12. Open questions

### Resolved
- **Apple Developer enrollment (M8):** Individual (no D-U-N-S; fast).
- **Privacy policy hosting (M9):** GitHub Pages.
- **Star Point naming:** kept the name "Star Point"; added a short "Deuce rules explained" note in Settings clarifying it means limited advantage (2 deuces only).
- **App icon (M7):** propose a first concept — deferred to M7.

### Still open
- **Bundle ID (D-02):** decision deferred to M8, just before enrolling. Choose between `farca.PadelNote` and a reverse-DNS form (e.g. `com.farca.padelnote`). Cannot change after the first TestFlight upload.
