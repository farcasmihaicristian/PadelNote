# PadelNote — Project Reference Guide

> Single source of truth for building **PadelNote**, the Padel scoring app for iPhone and Apple Watch, with HealthKit integration and App Store submission. Refer to this file at the start of every work session.

> **Learning context:** This project is also a hands-on tutorial. Every architectural and product decision is an opportunity to understand *why*, not just *what*. Explanations for all decisions (tech stack choices, rule presets, UI patterns, App Store strategy) are documented in [`DECISIONS.md`](./DECISIONS.md). Read that file alongside this one when you want the reasoning behind a choice.

**Project name:** PadelNote
**Working bundle ID:** `com.yourname.padelnote` *(replace `yourname` with your Apple Developer Team identifier when registering the app)*
**Tagline (draft):** *"Keep score. Keep history. Keep playing."*

---

## 0. Positioning & Differentiation

The padel scoring app space on the App Store is crowded (Padely, Padel Tally, Padel Point, Padel Score, Padelio, Padelistics, PADEL'EM, Padel Watch, Padel Scoreboard, PadelPro, Padel Score Keeper, and more). PadelNote needs a clear hook to stand out.

**Our differentiation pillars:**
1. **The "Note" angle** — every match is a journal entry. Rich history & point-by-point timeline are first-class, not buried behind a paywall.
2. **Rule transparency** — Golden Point vs Advantage, classic vs super tie-break, configurable per match and clearly explained in UI.
3. **No subscription for the core experience** — scoring + history + HealthKit are always free. Optional one-time IAP for advanced stats later.
4. **Apple Watch first** — the Watch app is fully standalone and the canonical scoring surface, not an afterthought.
5. **Privacy-first** — no analytics SDKs in v1, no account required, data lives on-device + iCloud (your iCloud, not ours).

Keep these pillars visible in App Store description, screenshots, and reviewer notes.

---

## 1. Product Scope (MVP — v1)

### iPhone app
- Start a new match with configurable rules:
  - Number of sets to win the match (best-of-1, best-of-3, best-of-5)
  - Games per set (default 6, tie-break at 6–6)
  - Tie-break rules (classic 7 points, super tie-break 10 points for deciding set)
  - **Golden Point** (sudden death at deuce, no advantage) vs **Advantage** (classic)
  - Optional: name the 4 players / 2 teams
- Live scoring screen
- Match history list + detail view
- Stats: win rate, average match duration, sets won, golden points won, etc.

### Apple Watch app
- Start / resume a match from the wrist
- Tap to add a point to either team
- Undo last point
- Show current game / set / match score
- Records an `HKWorkout` (`workoutActivityType = .tennis`, metadata `"sport" = "padel"`) with heart rate, active energy, distance

### Apple Health
- Write workout to HealthKit (duration, calories, heart rate samples, distance)
- Read heart rate / energy during the live session

### Sync
- WatchConnectivity for live score sync iPhone ⇄ Watch
- CloudKit (private DB) for multi-device history sync (optional in v1, recommended in v1.1)

---

## 2. Tech Stack

| Concern | Choice | Why |
|---|---|---|
| Language | **Swift 5.10+** | Required for native Apple Watch & HealthKit |
| UI | **SwiftUI** (iOS 17 / watchOS 10 minimum) | Single codebase across iPhone & Watch |
| Persistence | **SwiftData** (backed by CoreData) | Modern, simple, CloudKit-ready |
| Sync (later) | **CloudKit** via SwiftData `ModelConfiguration(cloudKitDatabase:)` | Free, no backend |
| Watch ⇄ Phone | **WatchConnectivity** (`WCSession`) | Standard, low-latency live updates |
| Workouts | **HealthKit** (`HKWorkoutSession` on Watch, `HKWorkoutBuilder`) | Required for proper workout recording |
| Bundle | One Xcode project, two targets: iOS app + watchOS app (independent watchOS app, iOS 17+) | Modern pattern |

---

## 3. Padel Scoring Engine — Design

The scoring engine is the heart of the app and must be **pure / deterministic / unit-testable** (no UI, no HealthKit). Everything else wraps it.

### Domain model

```swift
enum Team { case a, b }

enum GamePointStyle {
    case advantage     // classic tennis: deuce → advantage → game
    case goldenPoint   // sudden death at 40-40 ("punto de oro")
    case starPoint // after two deuces get to goldenPoint
}

enum TieBreakStyle {
    case none                // play out games (rare)
    case classic             // first to 7, win by 2, at 6-6
    case superTieBreak10     // first to 10, win by 2 (often for final set)
}

struct MatchRules: Codable, Hashable {
    var setsToWin: Int = 2           // best-of-3 → 2; best-of-5 → 3
    var gamesPerSet: Int = 6
    var winByTwoGames: Bool = true   // 7-5 vs 6-5 etc.
    var gamePointStyle: GamePointStyle = .advantage
    var setTieBreak: TieBreakStyle = .classic
    var finalSetTieBreak: TieBreakStyle = .superTieBreak10  // common in padel
}
```

### Score state rules
- Game points encoded as `0, 1, 2, 3` → display `"0", "15", "30", "40"`
- Track `gamesA / gamesB` for the current set
- Track completed sets array `[SetScore]`
- Track `isTieBreak` and tie-break points if active
- A pure function `apply(point: Team, to: MatchState) -> MatchState` transitions state

### Tests to cover (~30)
Deuce, advantage, golden point, tie-break entry at 6-6, set win at 7-5, super tie-break in deciding set, match win, undo, idempotent application.

---

## 4. Project / Xcode Setup

This section is a step-by-step walkthrough. Follow it exactly in order. The result is a compilable skeleton with no logic yet — a clean baseline to commit before writing any Swift.

---

### Step 4.1 — Create the iOS app project

1. Open Xcode → **Create New Project** (or File → New → Project)
2. Choose template: **iOS → App** → Next
3. Fill in the options:
   - **Product Name:** `PadelNote`
   - **Team:** your Personal Team (free Apple ID is fine here)
   - **Organization Identifier:** `com.yourname` *(placeholder — see DECISIONS.md D-02)*
   - **Bundle Identifier:** auto-filled as `com.yourname.PadelNote` — leave it
   - **Interface:** SwiftUI
   - **Language:** Swift
   - **Storage:** None *(SwiftData will be added via PadelCore, not the project template)*
   - Uncheck "Include Tests" — tests will live in the PadelCore package instead
4. Choose a save location — pick the root of this git repo (`E:\UDEMY\PadelNote` or wherever your local clone lives)
5. **Uncheck "Create Git repository"** — the repo already exists

> After this step you have one target: `PadelNote` (iOS). Xcode opens to `ContentView.swift`.

---

### Step 4.2 — Add the watchOS target

1. File → New → **Target**
2. Choose: **watchOS → Watch App** → Next
3. Fill in:
   - **Product Name:** `PadelNoteWatch`
   - **Team:** same as above
   - **Bundle Identifier:** auto-filled as `com.yourname.PadelNote.watchkitapp` — leave it
   - **Interface:** SwiftUI
   - **Language:** Swift
   - Uncheck "Include Notification Scene" — not needed for v1
4. Click **Finish**
5. Xcode asks *"Activate 'PadelNoteWatch' scheme?"* → click **Activate**

> You now have two app targets. In the scheme picker (top bar) you can switch between `PadelNote` (iPhone simulator) and `PadelNoteWatch` (Watch simulator).

---

### Step 4.3 — Create the PadelCore local Swift Package

This package holds all shared logic — the scoring engine, data models, and formatters. Neither UI framework touches it.

1. File → New → **Package**
2. Name it: `PadelCore`
3. Save location: **inside the project folder**, alongside `PadelNote.xcodeproj` — so the path ends up as `PadelNote/PadelCore/`
4. When asked *"Add to:"* select your `PadelNote` project; *"Group:"* select the project root
5. Click **Create**

Xcode creates a default package with a `Sources/PadelCore/` folder and a `Tests/PadelCoreTests/` folder. Now restructure the source folder:

6. In the Project navigator, expand `PadelCore → Sources → PadelCore`
7. Delete the auto-generated `PadelCore.swift` file (move to Trash)
8. Create three folders inside `Sources/PadelCore/`:
   - Right-click `Sources/PadelCore` → New Group → `Model`
   - Repeat → `Engine`
   - Repeat → `Persistence`

Your package layout should now be:

```
PadelCore/
├─ Package.swift
├─ Sources/
│  └─ PadelCore/
│     ├─ Model/          (empty — Team, MatchRules, MatchState go here)
│     ├─ Engine/         (empty — apply() function, undo logic go here)
│     └─ Persistence/    (empty — SwiftData models go here)
└─ Tests/
   └─ PadelCoreTests/    (unit tests go here)
```

---

### Step 4.4 — Add PadelCore as a dependency of both targets

The package is in the project but the two app targets don't use it yet.

**For the iOS target:**
1. Click the `PadelNote` project in the navigator → select the `PadelNote` target → **General** tab
2. Scroll to **Frameworks, Libraries, and Embedded Content**
3. Click **+** → select `PadelCore` from the list → **Add**

**For the watchOS target:**
1. Same Project → select `PadelNoteWatch` target → **General** tab
2. **Frameworks, Libraries, and Embedded Content** → **+** → `PadelCore` → **Add**

**Verify:**
- In the scheme picker, select `PadelNote` → press **⌘B** (Build)
- Switch to `PadelNoteWatch` → press **⌘B**
- Both should build with zero errors

---

### Step 4.5 — Add HealthKit capability to both targets

Do this now — HealthKit entitlements affect the app signature and are easy to forget later.

**For each target (`PadelNote` and `PadelNoteWatch`):**
1. Select the target → **Signing & Capabilities** tab
2. Click **+ Capability** (top-left of that tab)
3. Search for **HealthKit** → double-click to add
4. Leave "Clinical Health Records" **unchecked**

**For `PadelNoteWatch` only:**
5. Click **+ Capability** again → **Background Modes**
6. Check **Workout processing**

---

### Step 4.6 — Add Info.plist usage description keys

Apple requires plain-English justifications for HealthKit access. Missing or vague strings are a top App Review rejection cause.

1. In the Project navigator, select `PadelNote → Info` (the Info.plist for the iOS target)
2. Hover over any row → click **+** to add a key
3. Add:

| Key | Value |
|---|---|
| `NSHealthShareUsageDescription` | `PadelNote reads your heart rate and calories during matches to show accurate workout stats.` |
| `NSHealthUpdateUsageDescription` | `PadelNote saves your padel matches to Apple Health as workouts.` |

4. Repeat for the `PadelNoteWatch` target's Info.plist (same keys, same values)

---

### Step 4.7 — Verify final project structure

In the Xcode Project navigator you should see:

```
PadelNote/
├─ PadelNote/               ← iOS app files
│   ├─ PadelNoteApp.swift
│   └─ ContentView.swift
├─ PadelNoteWatch/          ← watchOS app files
│   ├─ PadelNoteWatchApp.swift
│   └─ ContentView.swift
├─ PadelCore/               ← Swift Package
│   ├─ Package.swift
│   ├─ Sources/PadelCore/
│   │   ├─ Model/
│   │   ├─ Engine/
│   │   └─ Persistence/
│   └─ Tests/PadelCoreTests/
└─ PadelNote.xcodeproj
```

---

### Step 4.8 — First git commit

Open Terminal inside the project folder and run:

```bash
git add .
git commit -m "Project skeleton: iOS + watchOS targets, PadelCore package, HealthKit capabilities"
```

This is your clean baseline. Every future feature builds on top of it.

---

### What to do if something looks wrong

| Problem | Fix |
|---|---|
| Package not visible in navigator | File → Add Package Dependencies → choose "Add Local" → point to the `PadelCore` folder |
| Build error "No such module 'PadelCore'" | Check that PadelCore is listed under Frameworks for that target (Step 4.4) |
| HealthKit capability shows a signing error | Make sure a Team is selected in Signing & Capabilities — even the free Personal Team works |
| Two `ContentView.swift` files exist | That's correct — one per target. They are independent. |

---

## 5. Capabilities & Info.plist Keys (set early, not at submission)

In **Signing & Capabilities** for both iOS and watchOS targets, add:
- **HealthKit** (leave "Clinical Health Records" off)
- **Background Modes**
  - watchOS: "Workout processing"
  - iOS: "Remote notifications" (only if you do CloudKit push)
- **iCloud → CloudKit** (when you turn on sync)
- **App Groups** (e.g. `group.com.yourname.padel`) — optional, useful for sharing files between iPhone & Watch

### Info.plist (both targets where relevant)
| Key | Value |
|---|---|
| `NSHealthShareUsageDescription` | "Padel uses your heart rate and energy during matches to give you accurate workout stats." |
| `NSHealthUpdateUsageDescription` | "Padel saves your matches to Apple Health as tennis/padel workouts." |
| `NSMotionUsageDescription` | (if CoreMotion used) "Padel uses motion to estimate distance and steps during a match." |
| `NSUserTrackingUsageDescription` | (only if analytics SDK added later) |

---

## 6. HealthKit Integration

- **`workoutActivityType`**: use `.tennis` (Apple has no dedicated Padel type as of 2026).
  - Add metadata: `HKMetadataKeyWorkoutBrandName = "Padel"` and custom `"sport" = "padel"` for filtering own history.
  - Fitness app shows it as Tennis — currently the accepted approach.
- **On the Watch**: `HKWorkoutSession` + `HKLiveWorkoutBuilder` to collect HR, active energy, distance, elapsed time. Start when match starts; pause between games if desired; end on match completion.
- **On the iPhone**: read the saved `HKWorkout` for history detail, or rely on SwiftData and write to HealthKit as a side effect.
- Always wrap HealthKit calls in proper `requestAuthorization(toShare:read:)`.

---

## 7. WatchConnectivity (phone ⇄ watch)

- `WCSession.updateApplicationContext` → latest score snapshot (small, last-write-wins).
- `WCSession.transferUserInfo` → full point log, queued reliably if one device is asleep.
- On match end, the Watch sends the final `Match` record; phone persists to SwiftData / CloudKit.
- **Pattern**: Watch is **source of truth** during a live match (it owns the workout session). Phone is mirror + history database.

---

## 8. UI — Screens to Build

### iPhone
1. **Home** — "Start match" button + recent matches
2. **New match setup** — pickers for rules (sets, golden point on/off, super tie-break on/off, player names)
3. **Live match** — large score readouts for Team A / Team B, +1 buttons, undo, end match
4. **Match history** — list grouped by month
5. **Match detail** — final score, sets breakdown, duration, calories, avg HR, point-by-point timeline
6. **Stats / Insights** — win rate, longest match, golden-point conversion %
7. **Settings** — default rules, HealthKit permissions, about

### Apple Watch
1. **Start screen** — last rules used, "Start"
2. **Live score** — two big tappable zones (Team A top, Team B bottom), Digital Crown to undo
3. **End-of-match summary** — final score, duration, HR avg, "Save"

> Use SF Symbols, large Dynamic Type, and full VoiceOver labels. Apple reviewers check basic accessibility.

---

## 9. Build Phases (suggested order)

| Days | Phase |
|---|---|
| 1–2 | Project + `PadelCore` package; scoring engine + unit tests for every rule variant |
| 3–4 | SwiftData models (`Match`, `PointEvent`, `MatchRules`), persistence, iPhone home/history screens |
| 5–6 | iPhone "new match" setup + live scoring screen wired to engine |
| 7–9 | watchOS target: live scoring UI, WatchConnectivity, `HKWorkoutSession` |
| 10–11 | Stats screen, polish, dark mode, accessibility, localization scaffolding (EN + ES) |
| 12 | App icon (1024×1024 single-size asset catalog), launch screen |
| 13–14 | TestFlight internal testing, bug fixes |
| Week 3+ | External TestFlight (up to 10,000 testers), incorporate feedback |
| Week 4 | App Store submission |

---

## 10. Steps to Reach the App Store

1. **Apple Developer Program** — enroll at developer.apple.com ($99/year). Organization enrollment needs a D-U-N-S number (1–2 weeks).
2. **App Store Connect** — create the app record:
   - Bundle ID (must match Xcode), SKU, primary language
   - Primary category **Sports**, secondary **Health & Fitness**
3. **App Privacy** — declare data collected:
   - Health & Fitness data → linked to user → not used for tracking
   - No third-party analytics in v1 = simplest review
4. **Privacy policy URL** — required (HealthKit counts as health data). Host a 1-page policy (GitHub Pages or a Notion-published page is fine).
5. **App icon + screenshots**:
   - 6.7" iPhone screenshots required, 6.5" optional
   - Apple Watch screenshots required when Watch app included
   - Safest: no device frames, no marketing copy inside screenshots
6. **App preview video** — optional but recommended for sports apps.
7. **Build upload** — archive in Xcode → upload via Organizer to App Store Connect.
8. **TestFlight** — at least one internal round. External testers also require a quick review.
9. **App Review submission**:
   - **Notes for reviewer**: briefly explain Padel rules and that workout type is "Tennis" (no Padel type in HealthKit yet). Pre-empts a common rejection.
   - Demo account: not needed (no login).
   - Sign-in required: No.
10. **Common rejection risks**:
    - Missing / weak `NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription` — must say *why* clearly.
    - Crash on first launch when permissions denied — handle gracefully.
    - Watch app non-functional without iPhone nearby — either fully support standalone or document the dependency.
    - Name / icon implying Apple endorsement ("Apple Padel", Apple logo) — never.
    - Padel association / league logos you don't own — never.
11. **Pricing & availability** — free / paid / IAP. Recommended v1: free, with optional "Pro stats" IAP later.
12. **Submit for review** — typical 2026 review time: 24–48 h for a clean first build.
13. **Release** — manual or automatic on approval.

---

## 11. Optional v1.1 / v1.2 Features

- CloudKit sync of match history across devices
- Share match summary as image (`UIActivityViewController`)
- Rivals / partners tracking (head-to-head stats)
- Siri Shortcuts: "Hey Siri, start a Padel match"
- Live Activity on Lock Screen / Dynamic Island for current score
- Court location via CoreLocation (with permission) for "matches near you"

---

## 12. Decisions

All decisions — made and still pending — are tracked and explained in [`DECISIONS.md`](./DECISIONS.md). That file records the *what*, the *why*, and the *trade-offs considered* for each choice. Update it whenever a new decision is made.

---

## 13. Working Conventions for This Project

- The scoring engine in `PadelCore` is **pure Swift, no Apple frameworks**, fully unit-tested before any UI is built.
- All HealthKit / WatchConnectivity / SwiftData code is wrapped behind protocols so the engine and view models stay testable.
- **Watch is source of truth during a live match.** Phone mirrors and stores history.
- Every new feature lands behind one of: a unit test (engine), a preview (SwiftUI), or a TestFlight internal build.
- Localizable strings from day one (no hard-coded user-visible strings).
- Accessibility labels on every interactive element from day one.
