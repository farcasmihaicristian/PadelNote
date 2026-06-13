# PadelNote — Mac Setup & Day-1 Guide

> You have **2 days with the Mac physically at your place**. Use them well: Day 1 is environment setup + device pairing. Day 2 is the actual project skeleton (Milestone 1 in `PLAN.md`). AnyDesk is configured during Day 1 so you can keep working after the Mac leaves.

---

## Quick checklist

```
DAY 1 — Environment
□ macOS up to date
□ Your user account created on Mac
□ Apple ID signed in on Mac
□ Xcode 16+ installed from Mac App Store
□ Xcode Command Line Tools installed
□ Apple ID added in Xcode Settings → Accounts
□ iPhone trusted via USB (tap Trust on phone)
□ iPhone WiFi pairing enabled in Xcode Devices window
□ Test app ran successfully on physical iPhone
□ AnyDesk installed + unattended access configured + tested from Windows PC

DAY 2 — Project skeleton (Milestone 1 of PLAN.md)
□ PadelNote Xcode project created (iOS App target)
□ watchOS target added (PadelNoteWatch)
□ PadelCore Swift Package created with Model/ Engine/ Persistence/ folders
□ PadelCore linked as dependency of both targets
□ Both targets build with ⌘B, zero errors
□ HealthKit capability added to both targets
□ Background Modes → Workout processing added to Watch target
□ Info.plist HealthKit usage strings added to both targets
□ First git commit pushed

BEFORE MAC LEAVES
□ AnyDesk tested: Xcode opens and is usable over remote connection
□ iPhone still visible in Xcode Devices window over WiFi (cable unplugged)
```

---

## Day 1 — Environment setup

### 1.1 — Check and update macOS
- Apple menu (top-left) → **About This Mac**
- You need **macOS Sequoia 15+**
- If older: **System Settings → General → Software Update** → update (30–60 min, do first)

### 1.2 — Create your user account
- **System Settings → Users & Groups → Add Account**
- Type: **Administrator**, your name, strong password
- Your files stay separate from your friend's account

### 1.3 — Sign in with your Apple ID
- **System Settings → Sign in with your Apple ID**
- Use the **same Apple ID as your iPhone**
- This links iCloud, Mac App Store, and Xcode signing to one identity

### 1.4 — Install Xcode
- Open **Mac App Store** → search **Xcode** → Install
- It is ~15 GB — start this immediately and let it download in the background while you do other steps
- When the download finishes: open Xcode → agree to the license → it installs additional components (~5 min)

### 1.5 — Install Command Line Tools
- Open **Terminal** (press ⌘Space → type `Terminal` → Enter)
- Run:
  ```bash
  xcode-select --install
  ```
- A popup appears → click **Install** → wait for it to finish

### 1.6 — Accept the Xcode license
```bash
sudo xcodebuild -license accept
```
Enter your Mac password when prompted.

### 1.7 — Add your Apple ID to Xcode
- Xcode → **Settings (⌘,) → Accounts → + → Apple ID**
- Sign in with your Apple ID
- You get a free **Personal Team** — enough to run apps on your own devices without the $99/year account

### 1.8 — Pair your iPhone via USB
- Plug your **iPhone 14 Pro Max** into the Mac with a cable
- Popup on the iPhone: **"Trust This Computer?"** → tap **Trust** → enter your iPhone passcode
- In Xcode: **Window → Devices and Simulators** — your iPhone appears in the left list
- Wait for **"processing symbol files"** to finish (first time: 5–10 min)

### 1.9 — Enable WiFi pairing (critical for remote work later)
- In the Devices window, select your iPhone
- Check the box: **"Connect via network"**
- A WiFi icon appears next to the iPhone name
- Unplug the cable — Xcode will find the iPhone over WiFi automatically from now on

### 1.10 — Apple Watch
- No cable needed. The Watch is discovered through the paired iPhone. Once the iPhone is trusted, Xcode can deploy Watch builds automatically.

### 1.11 — Run a test app on your iPhone (smoke test)
- Xcode → **Create New Project → iOS → App**
- Name: `Test`, any bundle ID, SwiftUI, no Storage
- Top bar: select **iPhone 14 Pro Max** as the run destination
- Press **▶ Run (⌘R)**
- The app launches on your physical iPhone — everything is wired up correctly
- Delete the test project (File → delete from disk)

### 1.12 — Install and configure AnyDesk
- Download AnyDesk on the Mac: [anydesk.com](https://anydesk.com)
- Open AnyDesk → note the **9-digit address** — write it down
- AnyDesk **Settings → Security → Allow unattended access** → set a password
- On your Windows PC: open AnyDesk → connect using the 9-digit address → confirm it works
- Open Xcode over AnyDesk and confirm the UI is usable at your connection speed

**Day 1 is done.** Environment is fully configured. The Mac can already be used remotely.

---

## Day 2 — Build the project skeleton

Follow **Section 4** of `PROJECT_GUIDE.md` step by step. It is fully detailed. Summary of what you will do:

### 2.1 — Create the Xcode project
- iOS App, name `PadelNote`, SwiftUI, no Storage template
- Save into your git repo folder
- Uncheck "Create Git repository" (it already exists)

### 2.2 — Add the watchOS target
- File → New → Target → **watchOS → Watch App**
- Name: `PadelNoteWatch`
- SwiftUI, no Notification Scene

### 2.3 — Create the PadelCore Swift Package
- File → New → Package → name `PadelCore`
- Save it inside the project folder
- Delete the auto-generated source file
- Create three groups inside `Sources/PadelCore/`: `Model/`, `Engine/`, `Persistence/`

### 2.4 — Link PadelCore to both targets
- Each target → General → Frameworks → + → PadelCore
- Build both targets with ⌘B — zero errors

### 2.5 — Add capabilities
- HealthKit on both targets
- Background Modes → Workout processing on the Watch target

### 2.6 — Add Info.plist keys
- `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription` on both targets

### 2.7 — First commit
```bash
git add .
git commit -m "Project skeleton: iOS + watchOS targets, PadelCore package, HealthKit capabilities"
git push
```

**Day 2 is done.** Milestone 1 of `PLAN.md` is complete. From this point the Mac can leave and you continue via AnyDesk.

---

## After the Mac leaves — remote workflow

- Connect via AnyDesk using the 9-digit address and your unattended-access password
- Your iPhone must be on the **same WiFi network as the Mac** for physical device testing
- If they are on different networks: use the **iOS Simulator** for daily development; save real-device testing (HealthKit, WatchConnectivity) for sessions where they are on the same network
- Continue from Milestone 2 (`PLAN.md`): the scoring engine — pure Swift, runs on the Mac, no simulator needed

---

## Notes on the $99/year Apple Developer account

You do **not** need it yet. A free Apple ID gives you:
- Run apps on your own iPhone and Watch
- All Xcode features and simulators
- Local HealthKit and WatchConnectivity testing

You **do** need it at Milestone 8:
- TestFlight distribution
- App Store submission

See `DECISIONS.md → D-02` for bundle identifier guidance.
