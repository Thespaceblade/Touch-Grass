# Touch Grass

An in-person, location-based party game for iPhone. Players draw a play zone (“bubble”) on the map, join with a code, and use GPS + Bluetooth proximity so the phones handle tagging while everyone runs.

**Site:** [thespaceblade.github.io/Touch-Grass](https://thespaceblade.github.io/Touch-Grass/)  
**Repo:** [github.com/Thespaceblade/Touch-Grass](https://github.com/Thespaceblade/Touch-Grass)

## Game modes

| Mode | Idea | Min players |
|------|------|-------------|
| **Manhunt** | Hunters vs hiders — location hide-and-seek | 3 |
| **Zombie Tag** | Infection tag — survivors vs zombies | 3 |
| **Capture The Flag** | Two teams, flags, safe zones | 4 |

Release builds currently ship **Manhunt** only (`AppReleaseConfiguration`). Debug builds unlock all three modes for local QA.

## How a session works

1. Host picks a mode and creates a lobby (6-digit join code).
2. Players join from their phones, set a display name, and grant location (Always while playing).
3. Host draws the bubble and starts the game.
4. GPS tracks who’s in/out of the zone; Bluetooth confirms close-range tags.
5. HUD chips show role, time, zone, and live counts without living in the phone UI.

Identity is **guest-first**: Firebase Anonymous Auth satisfies Firestore rules (`auth.uid`), while the roster uses a per-device guest id (`GuestDeviceIdentity`).

## Stack

- **App:** SwiftUI, MapKit, Core Location, Core Bluetooth
- **Backend:** Firebase Auth (anonymous) + Cloud Firestore
- **Project:** `touch-grass-67` (see `.firebaserc`)
- **SPM:** [firebase-ios-sdk](https://github.com/firebase/firebase-ios-sdk) (≥ 12.7)
- **Targets:** `Touch-Grass`, `Touch-GrassTests`, `Touch-GrassUITests`
- **Deployment:** iOS (see Xcode project deployment target)

## Repo layout

```text
Touch-Grass/           # iOS app (Views, Services, Models, Components)
Touch-GrassTests/      # Unit tests
Touch-GrassUITests/    # UI + marketing screenshot tests
firestore.rules        # Firestore security rules
rules-tests/           # Node rules unit tests (@firebase/rules-unit-testing)
docs/                  # Public marketing site (GitHub Pages)
Scripts/               # Screenshots, docs sync, lobby checks
DesignSystem/          # Local design prototypes (gitignored)
internal-docs/         # Local engineering notes (gitignored)
```

## Prerequisites

- macOS with a recent **Xcode** that can open this project
- An Apple Developer account (device / TestFlight / App Store)
- A Firebase project with **Anonymous Auth** and **Firestore** enabled
- Optional: Node.js (for `rules-tests`), Firebase CLI (rules deploy / emulator)

## Setup

1. Clone the repo and open `Touch-Grass.xcodeproj` in Xcode.
2. Copy Firebase config (real plist is gitignored):

   ```bash
   cp Touch-Grass/GoogleService-Info.plist.example Touch-Grass/GoogleService-Info.plist
   ```

   Replace placeholders with values from the Firebase console (iOS app), or drop in the downloaded `GoogleService-Info.plist`.
3. Let Xcode resolve the Firebase Swift packages.
4. Select the **Touch-Grass** scheme and run on a physical iPhone when possible — Bluetooth tagging and Always location are unreliable or limited in Simulator.

### Permissions

The app requests location (including background during play), Bluetooth, camera, and photo library (profile pictures). See `Touch-Grass/Info.plist`.

## Development notes

- **Lobbies / sessions** live in Firestore; join codes map via `joinCodes/{code}` → session.
- Security rules are in `firestore.rules` (host/member transitions, catch/presence paths, compass pulse, etc.).
- Core services: `GameService`, `FirestoreService`, `LocationService`, `BluetoothTagService`, `ZoneService`, `AuthService`, `ProfileService`.
- UI is organized by mode under `Views/Manhunt`, `Views/ZombieTag`, `Views/CaptureTheFlag`, plus shared screens and cartoon-style components.

## Tests

**Xcode**

- Unit: `Touch-GrassTests` (game flow, bubbles, zones, guest identity, compass, etc.)
- UI: `Touch-GrassUITests` (launch + marketing screenshot scenarios)

**Firestore rules**

```bash
cd rules-tests
npm install
npm test
```

Uses the Firestore rules emulator against `../firestore.rules`.

**Deploy rules** (when ready):

```bash
firebase deploy --only firestore:rules
```

## Marketing site & screenshots

Public landing page source for GitHub Pages lives in `docs/`. See [docs/README.md](docs/README.md).

- Capture App Store–style shots: `Scripts/capture_marketing_screenshots.sh`
- Sync local `DesignSystem` marketing assets into `docs/`: `Scripts/sync_docs_site.sh`

## License / status

Personal project in active development toward App Store release. Manhunt is the first shipping mode; CTF and Zombie Tag are implemented in-app and gated behind Debug / “coming soon” in Release.
