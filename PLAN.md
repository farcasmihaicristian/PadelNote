# PadelNote — Master Plan

> The complete, ordered roadmap from "nothing built yet" to "live on the App Store".
> Sources: [`PROJECT_GUIDE.md`](./PROJECT_GUIDE.md) (what to build), [`DECISIONS.md`](./DECISIONS.md) (why), [`SETUP.md`](./SETUP.md) (environment).
> Check items off as you go. Each milestone has a clear "done when" so progress is unambiguous.

**Constraint reminder:** Development happens on a remote Mac via AnyDesk. Physical device testing (HealthKit, WatchConnectivity) only works when iPhone + Mac share a WiFi network — plan those tasks for sessions when that's possible, use the Simulator otherwise.

---

## Milestone 0 — Environment (the day the Mac is at your place)

Follow `SETUP.md` end-to-end. Summary:

- [ ] 0.1 macOS updated, your admin account created, Apple ID signed in
- [ ] 0.2 AnyDesk installed, unattended access configured, tested from Windows PC
- [ ] 0.3 Xcode 16+ installed, command line tools, license accepted
- [ ] 0.4 Apple ID added in Xcode → Accounts (free Personal Team)
- [ ] 0.5 iPhone 14 Pro Max trusted via USB, **"Connect via network" enabled**
- [ ] 0.6 Test app runs on physical iPhone
- [ ] 0.7 AnyDesk session verified: Xcode usable, iPhone visible over WiFi

**Done when:** you can close the laptop, remote in from Windows, and still deploy to your iPhone.

---

## Milestone 1 — Project skeleton (Days 1–2, part 1)

Per `PROJECT_GUIDE.md` §4:

- [ ] 1.1 Create Xcode project: iOS App, name `PadelNote`, SwiftUI, bundle ID `com.<yourname>.padelnote` (placeholder OK for now — see D-02)
- [ ] 1.2 Add watchOS target (independent Watch App, not legacy paired type)
- [ ] 1.3 Create local Swift Package `PadelCore` with folders `Model/`, `Engine/`, `Persistence/` + `Tests/PadelCoreTests/`
- [ ] 1.4 Add `PadelCore` as a dependency of both app targets; verify both targets build
- [ ] 1.5 Add capabilities early (§5): HealthKit on both targets, Background Modes → "Workout processing" on watchOS
- [ ] 1.6 Add Info.plist keys: `NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription` (use the exact wording from §5 — weak descriptions are a top rejection cause)
- [ ] 1.7 First git commit: clean baseline

**Done when:** empty iOS + Watch apps build and run; `PadelCore` imports in both.

---

## Milestone 2 — Scoring engine + tests (Days 1–2, part 2)

The heart of the app. Pure Swift, no Apple frameworks (convention §13, decision D-06).

- [ ] 2.1 Domain types: `Team`, `GamePointStyle` (`.advantage`, `.goldenPoint`, `.starPoint` — golden point only after two deuces), `TieBreakStyle`, `MatchRules` (§3)
- [ ] 2.2 `MatchState`: game points, games per set, completed sets, tie-break state, match-over state
- [ ] 2.3 Pure transition function `apply(point: Team, to: MatchState) -> MatchState`
- [ ] 2.4 Undo support (event log: replaying `[PointEvent]` from zero is the simplest correct undo)
- [ ] 2.5 Score formatters: `0/15/30/40`, "Ad", tie-break digits, set summaries
- [ ] 2.6 Unit tests (~30): deuce, advantage, golden point, star point (2 deuces → sudden death), tie-break entry at 6-6, set win at 7-5, super tie-break in deciding set, match win, undo, idempotency
- [ ] 2.7 All tests green via `swift test` (no simulator needed — works fine over AnyDesk)

**Done when:** every rule variant in `MatchRules` is covered by a passing test.

---

## Milestone 3 — Persistence + iPhone home/history (Days 3–4)

- [ ] 3.1 SwiftData models in `PadelCore/Persistence`: `Match`, `PointEvent`, stored `MatchRules` (local only — CloudKit deferred per D-05)
- [ ] 3.2 ModelContainer wiring in the iOS app
- [ ] 3.3 **Home screen**: "Start match" button + recent matches list
- [ ] 3.4 **Match history screen**: list grouped by month
- [ ] 3.5 **Match detail screen** (v1 of it): final score, sets breakdown, duration
- [ ] 3.6 Seed sample data for SwiftUI previews
- [ ] 3.7 From day one: `String(localized:)` for every visible string, accessibility labels on every interactive element (§13)

**Done when:** you can browse fake match history on the simulator with localized, accessible UI.

---

## Milestone 4 — iPhone match flow (Days 5–6)

- [ ] 4.1 **New match setup screen**: pickers for sets, golden/star point, tie-break style, optional player/team names — defaults per D-03
- [ ] 4.2 Explain Golden Point / Star Point inline in the UI (rule-transparency pillar, and D-03 trade-off)
- [ ] 4.3 **Live match screen**: big score readouts, +1 per team, undo, end match — all driven by the `PadelCore` engine
- [ ] 4.4 On match end: persist `Match` + full `PointEvent` log to SwiftData
- [ ] 4.5 Match detail now shows the point-by-point timeline (the "Note" differentiator)

**Done when:** a full match can be played, scored, ended, and reviewed on the iPhone alone.

---

## Milestone 5 — Watch app + HealthKit + sync (Days 7–9)

Watch is source of truth during a live match (D-07). Needs physical devices on the same network as the Mac for real testing.

- [x] 5.1 Watch **start screen**: last-used rules + "Start"
- [x] 5.2 Watch **live score screen**: two big tap zones (Team A top / Team B bottom), Digital Crown or button to undo — reuses the same `PadelCore` engine
- [x] 5.3 HealthKit authorization flow (`requestAuthorization(toShare:read:)`), graceful handling when denied (rejection risk §10)
- [x] 5.4 `HKWorkoutSession` + `HKLiveWorkoutBuilder` on the Watch: `.tennis` type with `HKMetadataKeyWorkoutBrandName = "Padel"` and `"sport" = "padel"` metadata (D-08); collect HR, active energy, distance
- [x] 5.5 Watch **end-of-match summary**: final score, duration, avg HR, "Save" → finalize workout
- [x] 5.6 WatchConnectivity (§7): `updateApplicationContext` for live score snapshots, `transferUserInfo` for the point log, final `Match` sent to phone on match end
- [x] 5.7 iPhone mirrors the live Watch score and persists the received match
- [x] 5.8 Wrap HealthKit/WatchConnectivity behind protocols so view models stay testable (§13)
- [x] 5.9 Real-device test: full match on the Watch → workout appears in Apple Health → match appears in iPhone history

**Done when:** a match scored entirely from the wrist produces a HealthKit workout and a synced history entry on the phone.

### Next step — real-device test (5.9)

Simulator can exercise UI and scoring, but **HealthKit workouts and WatchConnectivity need physical devices** (per §5.9 above).

1. Install both apps on paired iPhone + Watch (same WiFi as Mac for deploy)
2. Open **PadelNote** on Watch → **Start** → grant Health access
3. Score points — iPhone Home should show live mirror
4. Finish match → **Save** on Watch
5. Match should appear in iPhone history; workout should appear in Apple Health

---

## Milestone 6 — Stats, polish, localization (Days 10–11)

- [x] 6.1 **Stats/Insights screen**: win rate, longest match, average duration, golden-point conversion %
- [x] 6.2 **Settings screen**: default rules, HealthKit permission status, about
- [x] 6.3 Match detail enriched with HealthKit data: calories, avg HR
- [x] 6.4 Dark mode pass, Dynamic Type pass, VoiceOver pass on every screen
- [x] 6.5 Spanish (ES) localization via `.xcstrings` (D-04 — strings were localized from day one, so this is translation work only)

**Done when:** the app is feature-complete for v1 in EN + ES, accessible, and looks right in dark mode.

---

## Milestone 7 — Branding (Day 12)

- [ ] 7.1 App icon, 1024×1024 single-size asset catalog (no Apple logos, no padel-association logos — §10 rejection risks)
- [ ] 7.2 Launch screen
- [ ] 7.3 Watch app icon

**Done when:** the app looks shippable on a home screen.

---

## Milestone 8 — Apple Developer account + TestFlight (Days 13–14)

The $99/year wall — everything before this works with a free Apple ID.

- [ ] 8.1 Enroll in the Apple Developer Program (individual; instant-ish, no D-U-N-S needed)
- [ ] 8.2 **Lock the bundle ID** (resolves D-02 — cannot change after first upload) and update Xcode signing to the paid team
- [ ] 8.3 Create the app record in App Store Connect: bundle ID, SKU, primary language, category Sports / Health & Fitness
- [ ] 8.4 Archive in Xcode → upload via Organizer
- [ ] 8.5 Internal TestFlight round: install on your iPhone + Watch, play real matches for several days
- [ ] 8.6 Fix bugs; repeat upload as needed
- [ ] 8.7 Optional: external TestFlight (friends / padel partners; requires a light Apple review)

**Done when:** a TestFlight build has survived real matches on a real court.

---

## Milestone 9 — App Store submission (Week 4)

Per `PROJECT_GUIDE.md` §10:

- [ ] 9.1 Privacy policy: 1-page, hosted (GitHub Pages is fine); URL into App Store Connect
- [ ] 9.2 App Privacy declaration: Health & Fitness data → linked to user → not used for tracking; no third-party SDKs (D-09 keeps this simple)
- [ ] 9.3 Screenshots: 6.7" iPhone (required), Apple Watch (required); no device frames, no marketing copy in-image
- [ ] 9.4 App Store description + keywords built around the differentiation pillars (§0); optional preview video
- [ ] 9.5 Pricing: Free (D-10)
- [ ] 9.6 **Reviewer notes**: explain padel rules briefly and why the workout type is "Tennis" (no Padel type in HealthKit) — pre-empts the most likely rejection
- [ ] 9.7 Pre-submission rejection-risk pass: HealthKit usage strings clear? App survives denied permissions on first launch? Watch app standalone or dependency documented?
- [ ] 9.8 Submit for review (typical 24–48 h)
- [ ] 9.9 Release 🎉

**Done when:** PadelNote is live on the App Store.

---

## Milestone 10 — Post-launch (v1.1+)

Backlog, in rough priority order (`PROJECT_GUIDE.md` §11):

- [ ] CloudKit sync of match history (planned in D-05; one `ModelConfiguration` change + entitlements + migration testing)
- [ ] Share match summary as image
- [ ] Live Activity / Dynamic Island for current score
- [ ] Rivals & partners head-to-head stats
- [ ] Siri Shortcuts ("start a Padel match")
- [ ] Court location for "matches near you"
- [ ] Optional one-time "Pro stats" IAP (D-10, v1.2+)

---

## Standing rules (apply to every milestone)

From `PROJECT_GUIDE.md` §13:

1. Engine stays pure Swift — no Apple frameworks in `Engine/`
2. HealthKit / WatchConnectivity / SwiftData behind protocols
3. Watch = source of truth during live matches
4. Every feature lands behind a unit test, a SwiftUI preview, or a TestFlight build
5. No hard-coded user-visible strings — ever
6. Accessibility labels on every interactive element — from the first screen
7. New decision made? Record it in `DECISIONS.md` before moving on
