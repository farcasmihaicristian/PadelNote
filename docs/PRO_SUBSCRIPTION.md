# PadelNote Watch Pro subscription

Pro unlocks Appearance extras and match history older than 30 days. Scoring, HealthKit, live mirror, and the last 30 days of journal stay free.

## Products

| Product ID | Period | Default price |
|---|---|---|
| `com.farcasmc.padelnote.pro.monthly` | 1 month | $2.99 |
| `com.farcasmc.padelnote.pro.yearly` | 1 year | $19.99 (~44% off) |

Subscription group display name: **PadelNote Watch Pro**

## Free vs Pro

| Feature | Free | Pro |
|---|---|---|
| Watch / phone scoring, HealthKit, live mirror | Yes | Yes |
| Default theme (`midnightEmerald`) | Yes | Yes |
| Other themes | Locked | Yes |
| L/R serve labels | Yes | Yes |
| Moving-ball serve indicator | Locked | Yes |
| History & insights ≤ 30 days | Yes | Yes |
| History & insights older than 30 days | Locked (data kept) | Yes |

## App Store Connect setup

1. Open [App Store Connect](https://appstoreconnect.apple.com) → **PadelNote Watch** → **Subscriptions**.
2. Create subscription group **PadelNote Watch Pro**.
3. Add auto-renewable subscriptions with the product IDs above (localize display names / descriptions).
4. Attach both products to the app version for review.
5. Review notes: “Core scoring is free. Pro is optional: all themes, moving-ball serve indicator, and full match history beyond 30 days.”

## Privacy

In-app and App Store Connect privacy URL: [PRIVACY.md](PRIVACY.md)  
`https://raw.githubusercontent.com/farcasmihaicristian/PadelNote/main/docs/PRIVACY.md`

## TestFlight / device testing (real App Store sandbox)

TestFlight **does not** use `PadelNote.storekit`. Products must exist in App Store Connect.

If the paywall says **0 products / subscriptions unavailable**:

1. **Agreements** — Business → Paid Apps accepted; banking + tax complete.
2. **App ID** — Identifiers → `com.farcasmc.padelnote` → **In-App Purchase** enabled.
3. **Products** — App → Subscriptions → group **PadelNote Watch Pro** with exact IDs:
   - `com.farcasmc.padelnote.pro.monthly`
   - `com.farcasmc.padelnote.pro.yearly`
4. Each product needs localization (name + description) and status at least **Ready to Submit**.
5. Wait a few minutes after creating products, then kill/reopen the TestFlight app and open the paywall again.
6. Purchase uses **Sandbox** (no real charge). Create a Sandbox tester under Users and Access → Sandbox if prompted.

## Xcode / Simulator testing (local StoreKit file)

- StoreKit config file: [`PadelNote/StoreKit/PadelNote.storekit`](../PadelNote/StoreKit/PadelNote.storekit)
- **PadelNote** scheme → **Run** → **Options** → **StoreKit Configuration** → `PadelNote.storekit`
- DEBUG builds also have **Settings → Developer → Unlock Pro (Simulator)** as a bypass

## Code map

- Policy: `PadelCore/.../ProAccessPolicy.swift`
- Entitlements: `PadelNote/Services/ProEntitlementStore.swift`
- Product IDs: `PadelNote/Services/ProProductIDs.swift`
- Paywall: `PadelNote/Views/Paywall/ProPaywallView.swift`
