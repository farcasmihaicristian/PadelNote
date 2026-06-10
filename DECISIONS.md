# PadelNote — Decision Log

> Every decision made for this project is recorded here with its rationale, alternatives considered, and trade-offs. This file exists because PadelNote is both a real app and a **learning project** — understanding *why* a decision was made is as important as the decision itself.
>
> Update this file whenever a new decision is locked in. Mark pending decisions clearly.

---

## How to read this file

Each entry follows this structure:

- **Decision** — what was chosen
- **Why** — the reasoning
- **Alternatives considered** — what else was evaluated and why it was rejected
- **Trade-offs** — what you give up with this choice
- **Status** — `✅ Locked` | `⏳ Pending` | `🔄 Revisable`

---

## D-00 — App name: PadelNote

**Decision:** The app is named **PadelNote**.

**Why:** The word "Note" positions the app as a journaling / history tool, not just another scorekeeper. It signals that every match is a record worth keeping — which is the core differentiator in a crowded market. It's short, memorable, and works well as an App Store search term alongside "Padel".

**Alternatives considered:**
- Generic score-focused names (Padel Score, Padel Tally) — too similar to existing apps, no hook.
- Team/player-focused names — narrows the audience unnecessarily.

**Trade-offs:** "Note" might imply text notes to some users. Onboarding copy should clarify the journaling angle early.

**Status:** ✅ Locked

---

## D-01 — Minimum OS targets: iOS 17 / watchOS 10

**Decision:** Require **iOS 17** and **watchOS 10** as the minimum.

**Why:**
- SwiftUI in iOS 17 / watchOS 10 is significantly more capable than earlier versions (`.navigationStack`, improved animations, `@Observable`, etc.).
- SwiftData — our persistence layer — requires iOS 17.
- As of 2026, iOS 17+ penetration among active iPhone users is above 90%. Dropping older versions loses very few users while gaining a much cleaner codebase.
- watchOS 10 introduced a redesigned app layout (vertically scrollable, navigation stack) that the Watch UI depends on.

**Alternatives considered:**
- iOS 16 / watchOS 9 — would require using `@StateObject` / `ObservableObject` instead of `@Observable`, and CoreData instead of SwiftData. More boilerplate, no meaningful user gain.

**Trade-offs:** Users on older hardware (iPhone X era running iOS 16) cannot install the app.

**Status:** ✅ Locked

---

## D-02 — Bundle identifier

**Decision:** `com.yourname.padelnote` — placeholder until Apple Developer account is created.

**Why:** The bundle ID must be registered in App Store Connect and must match Xcode exactly. It cannot be changed after the first TestFlight upload, so it should be chosen carefully before any build is submitted.

**What to do:** Replace `yourname` with your Apple Developer Team prefix or a domain you own (e.g., `com.farca.padelnote`). Use lowercase, reverse-DNS format.

**Trade-offs:** Delaying this decision is fine during local development, but it must be locked in before the first archive build.

**Status:** ⏳ Pending — set before first TestFlight build

---

## D-03 — Default rule preset

**Decision:** Best-of-3 sets, 6 games per set, classic tie-break at 6-6, super tie-break (10 points) for the deciding set, **Golden Point ON** by default.

**Why:**
- This is the standard ruleset used in recreational and amateur padel across Europe and Latin America.
- Golden Point (sudden death at deuce) is now the official World Padel Tour rule and is familiar to most players. Making it the default reflects modern padel, not legacy tennis rules.
- Super tie-break in the deciding set (instead of a full third set) is common in club play because it limits match duration.

**Alternatives considered:**
- Advantage (classic) as default — more familiar to tennis players but increasingly uncommon in padel specifically.
- Full third set — less common in recreational play, longer matches.

**Trade-offs:** Players who only know advantage rules might be confused. The UI should explain Golden Point clearly the first time it appears.

**Status:** ✅ Locked

---

## D-04 — Languages at launch

**Decision:** Launch with **English** as the primary language. **Spanish (ES)** is strongly recommended as a simultaneous launch language.

**Why:**
- Padel originated in Spain and is overwhelmingly popular in Spanish-speaking countries. A significant share of the App Store's padel audience speaks Spanish as their first language.
- SwiftUI's `LocalizedStringKey` / `String(localized:)` and `.xcstrings` (Xcode 15+) make adding a second language low-cost if localizable strings are used from day one (which is a project convention).
- Launching with Spanish expands the addressable market significantly with minimal extra work.

**Alternatives considered:**
- English only — simpler, but misses the largest padel-playing demographic.
- Italian / Swedish at launch — padel is also popular in Italy and Scandinavia, but Spanish covers more users per effort.

**Trade-offs:** All user-visible strings must be wrapped in `String(localized:)` from the start (no hard-coded text). This adds a small discipline tax during development but pays off immediately.

**Status:** 🔄 Revisable — English is the fallback; add ES before submission if time allows

---

## D-05 — CloudKit sync in v1?

**Decision:** **Defer CloudKit to v1.1.** Local SwiftData only in v1.

**Why:**
- CloudKit sync via SwiftData requires enabling iCloud entitlements, a CloudKit container, and careful schema migration testing. It adds scope and potential review risk for v1.
- Most users will use the app on one device initially. Local sync is sufficient for MVP.
- SwiftData is designed so that adding CloudKit later is a single configuration change (`ModelConfiguration(cloudKitDatabase: .automatic)`), making the deferral low-risk.
- Watch → Phone sync during a live match is handled by WatchConnectivity (separate from CloudKit), so cross-device live scoring still works in v1.

**Alternatives considered:**
- CloudKit from day one — cleaner long-term, but increases v1 scope and testing surface.
- Third-party sync (Firebase, etc.) — violates the privacy-first and no-backend pillars.

**Trade-offs:** A user with two iPhones (or who switches devices) won't see their history on the new device until v1.1. Acceptable for MVP.

**Status:** ✅ Locked for v1 — planned for v1.1

---

## D-06 — Scoring engine as a separate Swift Package (`PadelCore`)

**Decision:** All scoring logic, SwiftData models, and shared formatters live in a local Swift Package named `PadelCore`, not directly in the app target.

**Why:**
- **Testability:** The package can be unit-tested on Mac (without a simulator) because it has no dependency on UIKit, SwiftUI, or HealthKit.
- **Sharing:** Both the iOS app target and the watchOS app target import `PadelCore`. No code duplication.
- **Separation of concerns:** UI code cannot accidentally call engine code in ways that bypass the state machine. The package boundary enforces discipline.
- **Learning value:** This is the standard modern Apple platform architecture pattern. Understanding local Swift Packages is an essential skill.

**Alternatives considered:**
- Putting all code in the iOS target and sharing via file references — messy, hard to test, not idiomatic.
- Using a framework target instead of a package — packages are simpler and don't require device/simulator considerations.

**Trade-offs:** Slightly more Xcode setup upfront (adding the package, adding it as a dependency to both targets).

**Status:** ✅ Locked

---

## D-07 — Apple Watch is source of truth during a live match

**Decision:** During a live match, the **Watch app owns the score state** and the workout session. The iPhone mirrors the score but does not drive it.

**Why:**
- Players hold the racket with their iPhone hand — operating the phone mid-game is awkward. The Watch is always on the wrist and accessible.
- `HKWorkoutSession` must run on the Watch to collect accurate heart rate data from the wrist sensor.
- WatchConnectivity flows naturally from Watch → Phone for live updates.

**Alternatives considered:**
- iPhone as source of truth, Watch as display — worse UX (phone must be in hand), worse HealthKit data, reversed data flow.
- Peer-to-peer (both devices hold state) — significantly more complex conflict resolution.

**Trade-offs:** If the Watch app crashes mid-match, the iPhone has only a mirror snapshot, not a full point log. Mitigated by persisting each point event as it occurs.

**Status:** ✅ Locked

---

## D-08 — HealthKit workout type: `.tennis` (not a custom type)

**Decision:** Record padel workouts using `HKWorkoutActivityType.tennis`, not a custom or unsupported type.

**Why:**
- Apple HealthKit does not have a dedicated `.padel` activity type as of 2026. The closest official type is `.tennis`.
- Using an unsupported or undocumented activity type risks App Review rejection.
- The workaround is to add HKMetadata: `HKMetadataKeyWorkoutBrandName = "Padel"` and a custom key `"sport" = "padel"` so that the app's own history queries can filter specifically for padel workouts.
- The Fitness app will show these workouts as "Tennis" — this is the accepted norm for padel apps and should be disclosed in the App Review notes.

**Alternatives considered:**
- `.other` activity type — less informative, worse display in Fitness app.
- Filing a Feedback (FB) to Apple for a `.padel` type — good to do, but cannot block shipping.

**Trade-offs:** The Fitness app labels the workout "Tennis". Users who care about this label will need to understand the limitation. Document it in the app's FAQ / App Store description.

**Status:** ✅ Locked

---

## D-09 — No analytics SDK in v1

**Decision:** Ship v1 with **zero third-party analytics or tracking SDKs**.

**Why:**
- Simplifies App Privacy nutrition label (no data linked to user, no tracking).
- Eliminates a category of App Review risk.
- Aligns with the privacy-first differentiation pillar.
- First-party analytics (crash logs via Xcode Organizer, TestFlight feedback) are sufficient for v1.

**Alternatives considered:**
- Firebase Analytics / Crashlytics — useful data, but requires adding a privacy manifest, declaring data collection, and adding SDK weight.
- TelemetryDeck (privacy-respecting analytics) — worth reconsidering for v1.1 if behavioral data is needed.

**Trade-offs:** No funnel data for v1. Decisions about v1.1 features must rely on TestFlight feedback and App Store Connect metrics (downloads, retention, crashes).

**Status:** ✅ Locked for v1

---

## D-10 — Free app with optional one-time IAP later (no subscription)

**Decision:** v1 ships **free**. Core features (scoring, history, HealthKit) are never paywalled. A future one-time IAP for advanced stats is planned for v1.2+.

**Why:**
- Removes friction for first-time users discovering the app.
- Differentiates from competitors that put history or Watch sync behind subscriptions.
- One-time IAP is less contentious with users than recurring subscriptions for a sports utility app.
- Free + IAP requires the simplest App Store setup (no StoreKit subscription groups needed in v1).

**Alternatives considered:**
- Paid upfront ($0.99–$2.99) — simpler revenue model but significantly lower conversion in a crowded category.
- Freemium with subscription — maximises revenue potential but conflicts with the no-subscription pillar.

**Trade-offs:** Revenue is deferred. Free users may never convert. Acceptable for v1 where the goal is user acquisition and feedback.

**Status:** ✅ Locked for v1

---

## D-11 — Star Point: a third game-point style

**Decision:** Add a third `GamePointStyle` case, **`.starPoint`** — the game is played with classic advantage rules, but after **two deuces** in the same game it switches to sudden death (golden point).

**Why:**
- It's a middle ground between the two standard styles: advantage games can drag on indefinitely, while pure golden point can feel too abrupt to tennis-trained players.
- Capping a game at two deuces keeps match duration predictable (a key reason clubs adopted golden point) while still rewarding teams that win a first or second deuce exchange.
- It strengthens the rule-transparency differentiation pillar: PadelNote offers a rule variant most competitor apps don't model.
- Engine-wise it's cheap: the state machine already tracks deuce; it only needs a per-game deuce counter.

**Alternatives considered:**
- Only advantage + golden point — simpler, but misses a real-world house-rule variant some clubs play.
- Configurable deuce count (switch after N deuces) — more flexible but adds a numeric setting to the UI for marginal benefit. Can be revisited later if users ask.

**Trade-offs:**
- "Star Point" is not an officially standardized name/rule — the UI must explain it clearly the first time it's selected (same treatment as Golden Point, see D-03).
- Slightly larger test surface: the engine needs dedicated tests for deuce #1 (advantage), deuce #2 (advantage), and deuce #3 onward (sudden death).
- Default remains per D-03 (Golden Point ON); Star Point is opt-in.

**Status:** ✅ Locked

---

*Last updated: June 2026*
