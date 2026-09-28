# PadelNote Pro subscription

Pro unlocks Appearance extras and match history older than 30 days. Scoring, HealthKit, live mirror, and the last 30 days of journal stay free.

## Products

| Product ID | Period | Default price |
|---|---|---|
| `com.farcasmc.padelnote.pro.monthly` | 1 month | $2.99 |
| `com.farcasmc.padelnote.pro.yearly` | 1 year | $19.99 (~44% off) |

Subscription group display name: **PadelNote Pro**

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
2. Create subscription group **PadelNote Pro**.
3. Add auto-renewable subscriptions with the product IDs above (localize display names / descriptions).
4. Attach both products to the app version for review.
5. Review notes: “Core scoring is free. Pro is optional: all themes, moving-ball serve indicator, and full match history beyond 30 days.”

## Xcode / local testing

- StoreKit config file: [`PadelNote/StoreKit/PadelNote.storekit`](../PadelNote/StoreKit/PadelNote.storekit)
- In the **PadelNote** scheme → **Run** → **Options** → **StoreKit Configuration** → select `PadelNote.storekit`
- Enable **In-App Purchase** capability on the iOS App ID in the Developer portal if not already (StoreKit 2 needs no extra entitlements plist key)
- Sandbox: Settings → App Store → Sandbox Account on device for TestFlight / device testing

## Code map

- Policy: `PadelCore/.../ProAccessPolicy.swift`
- Entitlements: `PadelNote/Services/ProEntitlementStore.swift`
- Product IDs: `PadelNote/Services/ProProductIDs.swift`
- Paywall: `PadelNote/Views/Paywall/ProPaywallView.swift`
