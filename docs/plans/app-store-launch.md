---
title: App Store Launch Plan (TestFlight → live)
status: active
---

# PadelNote — App Store Launch Plan (TestFlight → live)

## Context

The app is on TestFlight (v1.0, build 6, Individual team `8C5FKN2L72`) and needs to go live on the App Store. Enrollment, the ASC app record ("PadelNote Watch", bundle `com.farcasmc.padelnote`), Sign in with Apple, HealthKit, app icons, and English + Spanish strings are already in place. What remains: fold in the latest unshipped code, a few code/config fixes, the App Store Connect metadata + privacy + IAP setup, store assets, and the submission itself.

**Decisions:** ship v1 **with** the PadelNote Watch Pro subscription · support **iPhone + Apple Watch only** (drop iPad).

Lean on the existing docs (don't duplicate): [TESTFLIGHT.md](../TESTFLIGHT.md), [PRO_SUBSCRIPTION.md](../PRO_SUBSCRIPTION.md), [PRIVACY.md](../PRIVACY.md), and README Milestone 9 / section 10.

---

## Phase 0 — Mac build & smoke-test the unshipped delta

The app already builds and ships from a Mac — TestFlight build 6 was Mac-built and verified, so the app as a whole is in good shape (the old "not compile-verified" framing in [mac-build-verification.md](mac-build-verification.md) is stale). The only code not yet on a TestFlight build is the recent cleanup commit (`24eead3`), authored on Windows. Fold it into the next normal Mac build:

- [ ] `cd PadelCore && swift build && swift test` — all green (incl. the `servingSlot` codec assertion added in that commit).
- [ ] Build both schemes in Xcode. The one architectural change to sanity-check is the `ThemeUI.swift` move into PadelCore (themes/serve indicator still render on both targets).
- [ ] Smoke-test the areas it touched: launch (ModelContainer fallback), live-match mirror serving highlight, theme picker, Spanish strings — no full regression needed; build 6 already covered the rest.

## Phase 1 — Code & config fixes before archiving

1. **Account deletion (hard App Review requirement, 5.1.1(v)).** The app enables Sign in with Apple and creates an `AppUser`, but there is **no in-app delete path** — only Sign out (doesn't delete) and per-match swipe-delete. Add a "Delete account & erase data" action in `PadelNote/Views/Settings/SettingsView.swift` that deletes the `AppUser`, clears the Keychain session (`AuthSessionStore`, service `com.farcasmc.padelnote.auth`), unlinks/deletes the owned `Player`, and offers to erase local matches. Start from `CurrentUserStore.signOut` + `UserAccountPersistence`.
2. **Narrow to iPhone.** Set `TARGETED_DEVICE_FAMILY = 1` for the iOS target (both configs) in `PadelNote.xcodeproj/project.pbxproj`; drop the iPad orientation keys. (Watch target stays `4`.)
3. **Advertise Spanish.** Add `es` to `knownRegions` in project.pbxproj — the `.xcstrings` has full `es` but the project only declares `en`/`Base`, so Spanish won't show as a supported App Store language otherwise.
4. **Confirm the iPhone home-screen name.** `INFOPLIST_KEY_CFBundleDisplayName = "PadelNote Watch"` on the iOS target — decide whether the iPhone icon should read "PadelNote" (cleaner) or stay "PadelNote Watch" (matches the ASC listing).
5. **Audit the paywall for subscription compliance (3.1.2).** Verify `PadelNote/Views/Paywall/ProPaywallView.swift` shows, before purchase: title + duration + price of each plan, auto-renew disclosure, a **Restore Purchases** button, and tappable **Privacy Policy** and **Terms of Use (EULA)** links. Add any missing — frequent rejection cause.
6. **Bump the build** to 7 (`CURRENT_PROJECT_VERSION`), re-archive, upload a fresh TestFlight build for final validation.

## Phase 2 — App Store Connect: app info

ASC record already exists (TESTFLIGHT.md §A). Fill the 1.0 version page:
- [ ] Category: **Sports** (primary) + **Health & Fitness** (secondary).
- [ ] Age rating: all questionnaire items "None" → **4+**.
- [ ] Pricing: **Free** (Pro is IAP, Phase 3).
- [ ] Supported languages: English + Spanish (after Phase 1.3).
- [ ] Privacy policy URL (Phase 4).

## Phase 3 — Pro subscription (IAP) in App Store Connect

Follow [PRO_SUBSCRIPTION.md](../PRO_SUBSCRIPTION.md) §"App Store Connect setup". Products: `com.farcasmc.padelnote.pro.monthly` ($2.99) and `.pro.yearly` ($19.99), group **PadelNote Watch Pro**.
- [ ] **Agreements → Paid Apps**: accept + complete **banking + tax** (nothing sells until this clears — start early).
- [ ] Identifiers → `com.farcasmc.padelnote` → **In-App Purchase** enabled.
- [ ] Create the subscription group + both auto-renewable products with exact IDs; localize name + description (EN + ES); set a **Terms of Use (EULA)** — standard Apple EULA is fine.
- [ ] Attach both products **to the 1.0 version** for review (first-time IAP must be submitted with the app).
- [ ] Create a **Sandbox tester** (Users and Access → Sandbox) for purchase/restore testing.

## Phase 4 — Privacy policy + App Privacy label

- [ ] **Host the privacy policy properly.** [PRIVACY.md](../PRIVACY.md) exists but the locked URL is a `raw.githubusercontent.com` link that renders as plain text — publish it as a rendered page (GitHub Pages) and use that URL in ASC + the paywall.
- [ ] **App Privacy questionnaire** (the app is 100% on-device — no servers, no analytics, no third-party SDKs, no tracking). Declare:
  - **Health & Fitness** (heart rate, energy, distance, workouts via HealthKit on Watch) — linked to user, **not** used for tracking.
  - **Contact Info → Name, Email** — optional, only via Sign in with Apple — linked, not tracking.
  - **User Content** (player/team names, reflection notes) — linked, not tracking.
  - **Identifiers** (Sign in with Apple user ID in Keychain; app-functionality only) — linked, not tracking.
  - **Purchases** (StoreKit entitlement status) — not tracking.
  - **Tracking: No** to every "track across apps/sites" question.

## Phase 5 — Store assets & copy

- [ ] **Screenshots** (no device frames, no baked-in marketing text): **6.9" iPhone** (required) + **Apple Watch** (required). Capture the live match screen, history/journal, insights, a theme, and the Watch scoring face.
- [ ] **Description** from the README positioning pillars: the "Note"/journal angle, rule transparency (Golden Point / Advantage / Star Point, tie-breaks), free core scoring, Apple-Watch-first, privacy-first. Tagline: *"Keep score. Keep history. Keep playing."*
- [ ] **Keywords** (100 chars): padel, scoring, score, watch, match, tracker, stats, tennis, sports, journal…
- [ ] **Promotional text** + **What's New** (first release).
- [ ] Localize description + keywords to **Spanish**.
- [ ] Support URL + marketing URL (can reuse the GitHub Pages site).

## Phase 6 — Reviewer notes (App Review Information)

- [ ] **Sign-in**: account is optional — scoring/history work with no account. SIWA is a standard Apple flow (no demo credentials needed); mention the local-profile fallback.
- [ ] **HealthKit "Tennis"**: no padel workout type exists in HealthKit, so matches save as **Tennis** with brand metadata "Padel"; the Fitness app shows "Tennis". Matches under 10 minutes are intentionally not saved to Health.
- [ ] **Apple Watch**: the Watch app is the canonical scoring surface and runs standalone; the iPhone shows a live mirror + history.
- [ ] **Pro / IAP**: core scoring is free; Pro unlocks all themes, the moving-ball serve indicator, and history older than 30 days. To test: use the Sandbox tester; the paywall is in Settings and on locked features.
- [ ] One-line padel rules primer.

## Phase 7 — Submit & release

- [ ] Select build 7 for the 1.0 version, with both IAP products attached.
- [ ] Submit for review (typically 24–48 h). Choose **manual release** to control go-live.
- [ ] On approval: release.

---

## Verification

- **Pre-archive:** Phase 0 green (swift build/test + both schemes + smoke test).
- **IAP end-to-end:** on a TestFlight build with ASC products live, the paywall lists both plans with prices (not "0 products") → Sandbox purchase unlocks themes/full history → Restore works → Delete-account path removes the account and data.
- **Localization:** device in Spanish → app + store listing read Spanish.
- **Privacy/links:** privacy policy URL and EULA open from the paywall and ASC.
- **Submission readiness:** no unchecked blocker in Phases 1–6; reviewer notes cover Tennis workout type, Watch standalone, optional account, and how to test Pro.

## Risks / watch-items

- **Paid Apps Agreement + banking/tax** can take time to clear — start Phase 3 early; IAP won't load until active.
- **Subscription paywall compliance (3.1.2)** and **account deletion (5.1.1(v))** are the two most likely rejection causes — Phase 1.1 and 1.5 address both.
- The app is already Mac-built/TestFlight-proven; only the `24eead3` cleanup delta is unshipped (Phase 0 covers it). Not a release-level risk.
- CloudKit is intentionally **not** in v1 (local-only); don't let the App Privacy label imply any off-device sync.
