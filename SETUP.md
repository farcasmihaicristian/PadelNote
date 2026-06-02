# PadelNote — Mac Setup Guide

> Follow this guide the day your friend brings the Mac to your place. Complete every phase **before the laptop leaves**. After that, you work exclusively via AnyDesk.

---

## Quick checklist (print this)

```
□ macOS up to date
□ Your user account created on Mac
□ Apple ID signed in on Mac
□ AnyDesk installed + unattended access configured
□ Xcode installed from Mac App Store
□ Xcode Command Line Tools installed
□ Apple ID added in Xcode Settings → Accounts
□ iPhone trusted via USB (tap Trust on phone)
□ iPhone WiFi pairing enabled in Xcode Devices window
□ Test app ran successfully on physical iPhone
□ AnyDesk connection tested from Windows PC
□ Mac leaves — remote-only workflow begins
```

---

## Phase 1 — Mac basics (~30 min)

### 1.1 — Check macOS version
- Apple menu (top-left) → **About This Mac**
- You need **macOS Sequoia 15+**. If older: **System Settings → General → Software Update** and update first (can take 30–60 min).

### 1.2 — Create your user account
- **System Settings → Users & Groups → Add Account**
- Create an **Administrator** account with your own name and password
- Your account stays separate from your friend's files

### 1.3 — Sign in with your Apple ID
- **System Settings → Sign in with your Apple ID**
- Use the same Apple ID as your iPhone
- This links iCloud, Mac App Store, and Xcode signing to one account

### 1.4 — Install and configure AnyDesk
- Download and install AnyDesk on the Mac: [anydesk.com](https://anydesk.com)
- Open AnyDesk → note the **9-digit address**
- AnyDesk **Settings → Security → Allow unattended access** → set a password
- **Test the connection from your Windows PC before your friend takes the Mac back**

---

## Phase 2 — Xcode setup (~1 hr, mostly waiting)

> Do this while you physically have the laptop — the 15 GB download is much faster on local WiFi than over AnyDesk.

### 2.1 — Install Xcode
- Open **Mac App Store** → search **Xcode** → Install (~15 GB)

### 2.2 — First launch
- Open Xcode → let it install additional components (~5 min)
- Agree to the license when prompted

### 2.3 — Install Command Line Tools
- Open **Terminal** (Spotlight search → type `Terminal`)
- Run:
  ```bash
  xcode-select --install
  ```
- A popup appears → click **Install**

### 2.4 — Accept the Xcode license
- In Terminal, run:
  ```bash
  sudo xcodebuild -license accept
  ```

### 2.5 — Sign in to Xcode with your Apple ID
- Xcode → **Settings (⌘,) → Accounts → + → Apple ID**
- Sign in — this gives you a free "Personal Team" for device testing without the $99/year developer account

---

## Phase 3 — Pair iPhone and Apple Watch (must be done while laptop is physically here)

### 3.1 — Connect iPhone via USB
- Plug your **iPhone 14 Pro Max** into the Mac with a cable
- Popup appears on iPhone: **"Trust This Computer?"** → tap **Trust** → enter your iPhone passcode

### 3.2 — Open Xcode Devices window
- Xcode → **Window → Devices and Simulators**
- Your iPhone appears in the left list
- Wait for it to finish "processing symbol files" — first time takes 5–10 min

### 3.3 — Enable WiFi pairing
> This is the critical step that lets you develop remotely later.

- In the Devices window, select your iPhone
- Check the box: **"Connect via network"**
- A WiFi icon appears next to your iPhone name — pairing is active
- You can now unplug the cable. Xcode will find your iPhone over WiFi automatically whenever both devices are on the same network.

### 3.4 — Apple Watch
- No separate USB connection needed. The Watch is paired through the iPhone. Once the iPhone is trusted, Xcode can deploy to the Watch automatically.

---

## Phase 4 — Verify everything works before the Mac leaves

### 4.1 — Run a test app on your iPhone
- Xcode → **Create New Project → iOS → App**
- Name: `Test`, any bundle ID, SwiftUI, no SwiftData
- In the top bar, select **iPhone 14 Pro Max** as the run destination
- Press **▶ Run (⌘R)**
- The app launches on your physical iPhone → everything is wired up correctly

### 4.2 — Delete the test project
It was only a connectivity check.

### 4.3 — Test AnyDesk from your Windows PC
- Connect to the Mac remotely from your Windows PC via AnyDesk
- Open Xcode remotely — confirm the UI is usable at your connection speed
- Confirm your iPhone still appears in Xcode **Devices** window over WiFi

---

## Phase 5 — Remote-only workflow (after Mac leaves)

### Requirements
- Your iPhone and the remote Mac must be on the **same WiFi network** for physical device testing via Xcode
- If the Mac is at a different location on a different network, use the **iOS Simulator** for day-to-day development and save physical device tests for HealthKit / WatchConnectivity work

### Starting the PadelNote project
1. Connect via AnyDesk
2. Follow **Section 4** of `PROJECT_GUIDE.md` to create the Xcode project
3. Create the watchOS target and `PadelCore` Swift Package
4. Make the first git commit as a clean baseline

### Optional: install Cursor on the Mac
- You can write Swift code in Xcode on the remote Mac
- Or install [Cursor](https://cursor.com) on the Mac for AI-assisted editing — the same tool you use on Windows

---

## Notes on the $99/year Apple Developer account

You do **not** need this to start developing. A free Apple ID gives you:
- Run apps on your own iPhone and Watch
- Use all Xcode features
- Test HealthKit, WatchConnectivity, SwiftData locally

You **do** need it when you're ready for:
- TestFlight distribution
- App Store submission
- Push notifications in production

See `DECISIONS.md` → D-02 for bundle identifier guidance (you pick the ID before paying — you just register it in App Store Connect later).
