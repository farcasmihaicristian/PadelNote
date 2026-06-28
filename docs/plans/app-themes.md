# Plan — App Themes (iPhone + Apple Watch)

> Add the color-theme system from [`gemini-code-1782150523359.html`](gemini-code-1782150523359.html) ("Padel Ultra — Cross Platform Theme Studio") to both PadelNote apps: a shared catalog of 20 named color palettes, a user-selectable active theme, and the theme's color treatments applied to the live-match surfaces on iPhone and Apple Watch.

**Status:** Proposed — not started. Sits alongside / just after M7 Branding (see [README roadmap](../../README.md#7-roadmap--whats-done--whats-next)). This is a new, optional polish feature; it does not change scoring, persistence, or sync semantics.

---

## 1. What the source HTML gives us

The HTML is a **design-token source and visual reference**, not a screen to clone pixel-for-pixel. Two things to extract:

### 1.1 The 20 themes (token library)

Each theme = an `id`, a display `name`, and **5 colors**: a Side-A (team 1) top→bottom gradient, a Side-B (team 2) top→bottom gradient, and one serve-accent color. Ported verbatim from the `themes` array (HTML lines 505–526):

| id | name | t1Top | t1Bot | t2Top | t2Bot | serve |
|---|---|---|---|---|---|---|
| midnightEmerald | Midnight Emerald | `#5E56D6` | `#302EA3` | `#30D158` | `#158A30` | `#FF9F0A` |
| cupertinoSunset | Cupertino Sunset | `#FF2D55` | `#B30E31` | `#FF9500` | `#B36400` | `#FFD60A` |
| oceanBreeze | Ocean Breeze | `#5AC8FA` | `#1D749B` | `#A2E6C8` | `#4A9E7A` | `#FFCC00` |
| berryFrost | Berry Frost | `#AF52DE` | `#641E96` | `#0A84FF` | `#0050B4` | `#30D158` |
| graphiteTitanium | Graphite Titanium | `#8E8E93` | `#48484A` | `#46464B` | `#1C1C1E` | `#FF9F0A` |
| lavenderDawn | Lavender Dawn | `#C8B4FA` | `#785AC8` | `#FFCC99` | `#C8783C` | `#FF3B30` |
| candyApple | Candy Apple | `#FF3B30` | `#B4140A` | `#0A84FF` | `#0046A0` | `#FFD60A` |
| neonCyber | Neon Cyber | `#FF00FF` | `#960096` | `#00FFFF` | `#009696` | `#39FF14` |
| aquaMarine | Aqua Marine | `#009688` | `#00645A` | `#40E0D0` | `#1EA096` | `#FFCC00` |
| solarFlare | Solar Flare | `#FFCC00` | `#C89600` | `#FF3B30` | `#B4140A` | `#FFFFFF` |
| ultraAction | Ultra Action | `#0A0A32` | `#05051E` | `#FF6900` | `#C84B00` | `#FFFFFF` |
| deepSpace | Deep Space | `#1E003C` | `#0F001E` | `#00143C` | `#000A1E` | `#00FFFF` |
| cherryBlossom | Cherry Blossom | `#FFB7C5` | `#C87385` | `#C8DCD7` | `#829691` | `#FF6B81` |
| arcticIce | Arctic Ice | `#B4F0FF` | `#5BB4C8` | `#C8D2DC` | `#78828C` | `#007AFF` |
| sunsetBoulevard | Sunset Boulevard | `#641478` | `#460A5A` | `#FF5000` | `#C83200` | `#FFCC00` |
| monochromeOled | Monochrome OLED | `#646464` | `#3C3C3C` | `#B4B4B4` | `#787878` | `#FFFFFF` |
| goldenHour | Golden Hour | `#FFD700` | `#A58200` | `#FF7F50` | `#DC4614` | `#FFFFFF` |
| forestCanopy | Forest Canopy | `#0A5A28` | `#053C19` | `#96E632` | `#5A960A` | `#FFFFFF` |
| cobaltStrike | Cobalt Strike | `#0047AB` | `#002878` | `#DC143C` | `#A00A28` | `#FFD700` |
| peachFuzz | Peach Fuzz | `#FFCCBC` | `#D28068` | `#FFF5B4` | `#DCC878` | `#FF8C00` |

Default = **`midnightEmerald`** (first in the list, marked `active` in the HTML).

> An alternate token file exists at [`padel_app_themes_v2.html`](padel_app_themes_v2.html). This plan uses the gemini-code file as requested; the catalog is data-driven, so swapping/merging palettes later is a one-array edit.

### 1.2 The visual treatments (how the tokens are used)

From the two mock devices in the HTML:

- **Watch** (`.zone-top` / `.zone-bottom`, `.w-scoreboard`, serve markers):
  - Each team's half of the screen is a vertical **gradient** (`top → bottom`) in that team's two colors.
  - A frosted-glass scoreboard floats centered (`backdrop-filter: blur` → SwiftUI `.ultraThinMaterial`, which the watch live view already uses).
  - The **serving** player's name is underlined in the **serve color**; a serve field-indicator chip is bordered/tinted in the serve color.
- **iPhone** (`.iphone-ambient-glow`, `.phone-team-bar`, `.ph-point`, `.phone-service-dot`, `.phone-action-btn`):
  - A large blurred **ambient glow** behind content, tinted with the Side-A top color.
  - Thin **team identifier bars** colored per team (`bar-t1` = team1Top, `bar-t2` = team2Top).
  - **Score points** rendered in the team's color; a small **service dot** in the serve color.
  - The primary **CTA button** is a team1 `top → bottom` gradient.

**Team ↔ color mapping (lock this in):** `team1` ⇒ **Side A** (`Team.a`), `team2` ⇒ **Side B** (`Team.b`), `serve` ⇒ serve/possession accent. Note the HTML draws team1 on top, but in this app **Side A is the bottom zone and Side B is the top zone** (see `MeSlotSettingsSection` in [SettingsView.swift](../../PadelNote/Views/SettingsView.swift) and the watch layout below). We map by **team**, not by screen position — so the bottom (Side A) zone gets the team1 gradient and the top (Side B) zone gets the team2 gradient. Consistency across both apps matters more than matching the HTML's top/bottom.

---

## 2. Current state — where colors live today

There is **no theme system today**; colors are hardcoded and the apps otherwise ride the system accent.

- **Watch live zones** — [WatchLiveMatchView.swift:304–311](../../PadelNoteWatch/Views/WatchLiveMatchView.swift#L304-L311) `teamBackground(for:)` returns flat `Color(red:…)` (blue for A, green for B). **This is the primary swap target → gradients.**
- **Watch serve markers** — hardcoded `.orange`: the serving-player capsule [WatchLiveMatchView.swift:251](../../PadelNoteWatch/Views/WatchLiveMatchView.swift#L251) and the serve triangle [:263–266](../../PadelNoteWatch/Views/WatchLiveMatchView.swift#L263-L266). → serve color.
- **Watch score overlay** — already `.ultraThinMaterial` ([:162](../../PadelNoteWatch/Views/WatchLiveMatchView.swift#L162)); matches the HTML glass scoreboard, keep as-is.
- **Phone live match** — point buttons use `.buttonStyle(.borderedProminent)` (system tint) [LiveMatchView.swift:238](../../PadelNote/Views/LiveMatchView.swift#L238); serve markers hardcoded `.orange` [:172](../../PadelNote/Views/LiveMatchView.swift#L172) and [:227](../../PadelNote/Views/LiveMatchView.swift#L227).
- **Phone watch-mirror** — serve label `.orange` [WatchLiveMirrorView.swift:30](../../PadelNote/Views/WatchLiveMirrorView.swift#L30).
- **App roots** — no global `.tint(...)`: [PadelNoteApp.swift](../../PadelNote/PadelNoteApp.swift) (root `HomeView`) and [PadelNoteWatchApp.swift](../../PadelNoteWatch/PadelNoteWatchApp.swift) (root `WatchStartView`).

### Preferences & sync patterns to reuse

- **Preference storage:** the established pattern is a `public enum …Preferences` in `PadelCore/Sources/PadelCore/Preferences/` backed by `UserDefaults.standard` with `load()`/`save()` — e.g. [WorkoutActivityPreferences.swift](../../PadelCore/Sources/PadelCore/Preferences/WorkoutActivityPreferences.swift). PadelCore is linked into **both** targets.
- **⚠️ `UserDefaults.standard` is NOT shared between iOS and watchOS.** A theme picked on the phone must be **pushed to the watch** over the existing context channel — it does not arrive for free.
- **Phone → Watch channel:** [`PhoneWatchSyncPayload`](../../PadelCore/Sources/PadelCore/Sync/PhoneWatchSyncPayload.swift) (Codable struct) carries `rules`, `knownPlayerNames`, `meProfile`, and `workoutActivity` (the last is **optional for back-compat**). It is built and sent by `PhoneSyncCoordinator.syncPhoneContextToWatch()` ([PhoneSyncCoordinator.swift:39–51](../../PadelNote/Services/PhoneSyncCoordinator.swift#L39-L51)) and applied on the watch by `WatchMatchCoordinator.applyPhoneContext(_:)` ([WatchMatchCoordinator.swift:71–85](../../PadelNoteWatch/WatchMatchCoordinator.swift#L71-L85)). **`workoutActivity` is the exact precedent for adding an optional `themeID`.**

---

## 3. Architecture & decisions

1. **Tokens live in PadelCore as data, not SwiftUI `Color`.** PadelCore is a pure package (no Apple UI frameworks — working convention #1). Store colors as **hex strings**; convert to `Color` in each app target. This keeps the catalog testable on Mac and shared by both apps.
2. **One source array, 20 themes**, ported verbatim. Data-driven so adding/removing palettes is a one-array change.
3. **Active theme = a stored `id` string**, with `.default` fallback when missing/unknown — same shape as `WorkoutActivityPreferences`.
4. **Phone is the sole source of truth for selection; the watch receives it via sync and persists its last value** so it themes correctly offline (the watch is a standalone surface, README §2.4). No watch-side picker in v1 (decided — §7).
5. **The HTML is a design language, not a layout spec.** We apply its *token system* + *treatments* (gradient zones, serve accents, gradient CTA, colored team bars/scores, ambient glow) to the **existing** screens. We do not rebuild the live screens to match the mock's analytics card.

---

## 4. Implementation phases

### Phase 1 — Shared theme model & storage (PadelCore)

New folder `PadelCore/Sources/PadelCore/Theming/`:

- **`AppTheme.swift`** — `public struct AppTheme: Codable, Sendable, Hashable, Identifiable`:
  ```swift
  public let id: String          // e.g. "midnightEmerald"
  public let name: String        // English display name; localized at the view layer
  public let team1Top, team1Bottom: String   // hex "#RRGGBB", Side A
  public let team2Top, team2Bottom: String   // hex, Side B
  public let serve: String                    // hex, serve accent
  ```
- **`AppThemeCatalog.swift`** — `public enum AppThemeCatalog` with `public static let all: [AppTheme]` (the 20 rows from §1.1), `public static let `default`` (= `midnightEmerald`), and `public static func theme(withID:) -> AppTheme` (falls back to `.default`).
- **`AppThemePreferences.swift`** — `public enum AppThemePreferences` with `load() -> AppTheme` / `save(_ AppTheme)` / `loadID()`/`saveID(_:)` over `UserDefaults.standard` key `"selectedAppThemeID"`, mirroring `WorkoutActivityPreferences`.

**Tests** (`PadelCore/Tests/PadelCoreTests/AppThemeTests.swift`): 20 themes present; ids unique; every hex matches `#[0-9A-Fa-f]{6}`; `theme(withID:)` returns the match and falls back to default for unknown ids; `AppThemePreferences` round-trips and defaults correctly.

### Phase 2 — Color conversion + theme palette (each app target)

PadelCore stays UI-free, so add a tiny SwiftUI bridge in **both** targets (shared file content, one copy per target — keep them identical):

- `Color(hex:)` initializer (parse `#RRGGBB`).
- A `ThemePalette` view-helper built from an `AppTheme`, exposing: `sideAGradient` / `sideBGradient` (`LinearGradient` top→bottom), `gradient(for: Team)`, `serveColor: Color`, `sideAColor` / `sideBColor` (the top stops, for bars/scores), and `accent: Color` (recommend `serve`, used for global tint).
- An **`@Observable ThemeStore`** (`@MainActor`) holding the active `AppTheme`, injected via `.environment(...)` at each app root so any view can read the live theme and re-render on change.
  - **Phone:** `ThemeStore` loads from `AppThemePreferences`; Settings mutates it.
  - **Watch:** `ThemeStore` loads from `AppThemePreferences` (last synced value) and is updated by `applyPhoneContext` (Phase 4).

### Phase 3 — Apply theme to the Watch live match

In [WatchLiveMatchView.swift](../../PadelNoteWatch/Views/WatchLiveMatchView.swift), read the `ThemeStore` from the environment, then:

- Replace `teamBackground(for:)` ([:304–311](../../PadelNoteWatch/Views/WatchLiveMatchView.swift#L304-L311)) with `palette.gradient(for: team)` (`LinearGradient`). Team `.a` (bottom zone) → Side-A gradient; Team `.b` (top zone) → Side-B gradient.
- Serve markers → `palette.serveColor`: serving-player capsule fill ([:251](../../PadelNoteWatch/Views/WatchLiveMatchView.swift#L251)) and serve triangle ([:263–266](../../PadelNoteWatch/Views/WatchLiveMatchView.swift#L263-L266)).
- Keep `.ultraThinMaterial` scoreboard; verify white text + serve underline stay legible over the lightest palettes (Arctic Ice, Peach Fuzz, Cherry Blossom) — see §6.

### Phase 4 — Sync the selection phone → watch

- Add `public var themeID: String?` to [`PhoneWatchSyncPayload`](../../PadelCore/Sources/PadelCore/Sync/PhoneWatchSyncPayload.swift) — **optional, defaulted `nil`** in `init`, exactly like `workoutActivity`, so older payloads still decode.
- `PhoneSyncCoordinator.syncPhoneContextToWatch()` ([:44–49](../../PadelNote/Services/PhoneSyncCoordinator.swift#L44-L49)) includes `themeID: AppThemePreferences.loadID()`.
- `WatchMatchCoordinator.applyPhoneContext(_:)` ([:71–85](../../PadelNoteWatch/WatchMatchCoordinator.swift#L71-L85)): if `payload.themeID` is non-nil, `AppThemePreferences.saveID(...)` and update the watch `ThemeStore`.

### Phase 5 — Phone theming + theme picker

- **Settings picker** — add a "Appearance / Theme" `Section` to [SettingsView.swift](../../PadelNote/Views/SettingsView.swift) with `@State private var selectedTheme = AppThemePreferences.load()` and an `onChange` that does `AppThemePreferences.save(...)` → update `ThemeStore` → `syncCoordinator.syncPhoneContextToWatch()` (same wiring as `workoutActivity` at [:87–90](../../PadelNote/Views/SettingsView.swift#L87-L90)). Render each row with a **two-color swatch** (Side-A top / Side-B top split circle) like the HTML's `.theme-preview`, plus the localized name.
- **Live match treatments** in [LiveMatchView.swift](../../PadelNote/Views/LiveMatchView.swift) — **full/stretch scope** (decided, §7):
  - Point buttons → tint per team: Side A `palette.sideAColor`, Side B `palette.sideBColor` (via `.tint(...)` on the `.borderedProminent` buttons, or a custom gradient background mirroring the HTML CTA).
  - Serve markers ([:172](../../PadelNote/Views/LiveMatchView.swift#L172), [:227](../../PadelNote/Views/LiveMatchView.swift#L227)) → `palette.serveColor`.
  - Ambient glow — a blurred radial gradient in `palette.sideAColor` behind the scoring view, mirroring `.iphone-ambient-glow`.
  - Team-colored score text — the current game-score / set readouts tinted with the leading/relevant team color, mirroring `.ph-point.t1/.t2`.
- **Global tint** — apply `.tint(palette.serveColor)` at the phone root ([PadelNoteApp.swift](../../PadelNote/PadelNoteApp.swift)) so nav/controls pick up the theme accent (decided: serve color, §7). Also update the phone watch-mirror serve color ([WatchLiveMirrorView.swift:30](../../PadelNote/Views/WatchLiveMirrorView.swift#L30)).

### Phase 6 — Localization, accessibility, polish

- Route the 20 display names through `String(localized:)` per convention #5, but keep them as **English proper nouns** in both languages (decided, §7) — the ES values equal the EN values.
- Accessibility: theme colors are decorative; confirm VoiceOver labels and Dynamic Type are unaffected. Add an accessibility label to each picker swatch row (the theme name).
- SwiftUI previews for: the Settings picker, the watch live view under 2–3 representative themes (a dark and a light one), the phone live view.

---

## 5. Files touched (summary)

**New (PadelCore):** `Theming/AppTheme.swift`, `Theming/AppThemeCatalog.swift`, `Theming/AppThemePreferences.swift`, `Tests/PadelCoreTests/AppThemeTests.swift`.
**New (each target):** a `Theming/` helper file (`Color(hex:)`, `ThemePalette`, `ThemeStore`) — one copy in `PadelNote/`, one in `PadelNoteWatch/`.
**Edited (PadelCore):** `Sync/PhoneWatchSyncPayload.swift` (+`themeID`).
**Edited (iOS):** `PadelNoteApp.swift` (inject `ThemeStore` + `.tint`), `Views/SettingsView.swift` (picker), `Views/LiveMatchView.swift`, `Views/WatchLiveMirrorView.swift`, `Services/PhoneSyncCoordinator.swift`.
**Edited (watchOS):** `PadelNoteWatchApp.swift` (inject `ThemeStore`), `Views/WatchLiveMatchView.swift`, `WatchMatchCoordinator.swift`.

---

## 6. Accessibility & contrast notes

- All score/name text on the watch zones is **white**; the lightest palettes (`arcticIce`, `peachFuzz`, `cherryBlossom`, `lavenderDawn`, `goldenHour`, `solarFlare`) have pale top stops. Verify legibility — the existing text shadow ([WatchLiveMatchView.swift:196](../../PadelNoteWatch/Views/WatchLiveMatchView.swift#L196)) helps; consider darkening text or strengthening the shadow only if a palette fails. Don't special-case per theme unless a real contrast failure is found.
- Serve accents that are white (`solarFlare`, `ultraAction`, `monochromeOled`, `goldenHour`, `forestCanopy`) must still read as "serve" against white text — the underline/triangle shape carries meaning, not just color, so this is acceptable.
- Themes are purely cosmetic: scoring, sync, and VoiceOver semantics are unchanged.

---

## 7. Decisions (resolved)

1. **Theme picker location:** ✅ **Phone-only, synced to watch.** Selection happens in iPhone Settings; the watch persists and renders the last synced value (themes correctly offline). No standalone watch picker in v1.
2. **Global phone accent:** ✅ **Serve accent color** — `.tint(palette.serveColor)` app-wide on iPhone.
3. **Phone live-match scope:** ✅ **Full / stretch** — serve color + team-tinted point buttons **and** ambient glow + team-colored score text.
4. **Theme names in Spanish:** ✅ **Keep English proper nouns** in both languages, still routed through `String(localized:)` (ES value = EN value).
5. **Decision log:** record **D-13 — App color themes** in the [README decision log](../../README.md#8-decision-log) when implementation lands.

---

## 8. Out of scope

- A standalone theme picker on the watch (phone-only selection in v1 — §7).
- Per-match theme overrides (theme is a global app preference).
- Theming history/stats/detail screens beyond the global tint (focus is the live surfaces).
- Custom user-authored themes / color pickers.
- Rebuilding the live screens to match the HTML mock's exact layout (we apply tokens to existing screens).
- Light/dark auto-switching of palettes (palettes are fixed; the apps already run dark).
