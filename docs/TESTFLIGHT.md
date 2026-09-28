# TestFlight handoff checklist

Project prep in the repo is done. Complete these Apple-side steps once (UI only).

## A. Create the App Store Connect record

Upload failed with `missingApp(bundleId: "com.farcasmc.padelnote")` until this exists.

1. Open [App Store Connect → My Apps](https://appstoreconnect.apple.com/apps).
2. Click **+** → **New App**.
3. Fill in:
   - Platforms: **iOS**
   - Name: **PadelNote Watch** (ASC listing name; exact `PadelNote` was taken — home-screen name can still be PadelNote)
   - Primary Language: **English (U.S.)**
   - Bundle ID: **com.farcasmc.padelnote** (must already appear — Xcode registered it)
   - SKU: **padelnote-ios**
   - User Access: **Full Access**
4. Create the app.
5. (Optional) TestFlight → Internal Testing → ensure your Apple ID is a tester.

## B. Enable Sign in with Apple on the App ID (if not already)

1. Open [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list).
2. Select **com.farcasmc.padelnote**.
3. Enable **Sign In with Apple** → Save (and regenerate profiles if prompted).
4. Watch App ID **com.farcasmc.padelnote.watchkitapp** needs HealthKit only (no SIWA).

## C. Upload the archive

Either:

```bash
chmod +x scripts/upload-testflight.sh
./scripts/upload-testflight.sh
```

Or in Xcode: **Window → Organizer** → select **PadelNote** archive → **Distribute App** → App Store Connect → Upload.

## D. Internal TestFlight device validation

Install from TestFlight on a **paired real iPhone + Watch** (Simulator cannot deliver `transferUserInfo` saves).

| Area | Pass? |
|---|---|
| SIWA — Settings → Account → Sign in / relaunch restores | |
| Local profile still works if SIWA skipped | |
| Watch start → score → undo → end → Save | |
| Phone live mirror updates during match | |
| Saved match appears in phone History | |
| HealthKit auth; ≥10 min workout saves | |
| Short match shows under-10-min Health warning | |
| Theme + serve indicator sync phone → watch | |
| Insights / ME / reflection survey | |
| Deny Health — scoring still works | |

## E. PadelNote Pro (StoreKit)

See [PRO_SUBSCRIPTION.md](PRO_SUBSCRIPTION.md) for product IDs, free/Pro matrix, and ASC subscription setup.

## Locked project values

| Item | Value |
|---|---|
| ASC listing name | `PadelNote Watch` (home-screen can remain PadelNote) |
| iOS bundle ID | `com.farcasmc.padelnote` |
| Watch bundle ID | `com.farcasmc.padelnote.watchkitapp` |
| Team | `8C5FKN2L72` (Mihai Farcas) |
| Version / build | `1.0` / `1` |
| Archive | `build/PadelNote.xcarchive` |
| Upload | Build **1.0 (1)** uploaded to App Store Connect — wait for processing, then install via TestFlight |

