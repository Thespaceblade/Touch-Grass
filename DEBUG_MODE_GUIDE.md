# Debug Mode vs Normal Mode Guide

## Important: They Are NOT Separate Apps

**The app is the SAME app** - there is no separate "test mode app" vs "normal app". Instead:

- **Debug Mode** = Features that only appear when you build/run in **Debug configuration**
- **Normal Mode** = What users see in **Release builds** (TestFlight, App Store)

All debug/test features are automatically stripped out in Release builds using `#if DEBUG` preprocessor directives.

---

## How to Run the App

### Normal Mode (What Users See)
1. **Command + R** (Run) in Xcode → This runs in **Debug mode** (you'll see test buttons)
2. **Product → Archive** → Creates a **Release build** (no test buttons)
3. **TestFlight/App Store** → Always **Release builds** (no test buttons)

### Debug Mode (For Testing)
- **Command + R** in Xcode → Automatically runs in Debug mode
- The debug test button (test tube icon) appears in the top-right corner
- All test features are available

---

## What's Different in Debug vs Release?

### Debug Mode (Command + R)
✅ **Shows:**
- Debug test button (test tube icon) in top-right corner of all screens
- Debug test panel (when you tap the test tube icon)
- All test features (add fake players, force game states, etc.)
- Debug logging and console output

❌ **Does NOT show in Release:**
- All debug features are wrapped in `#if DEBUG` blocks
- When you Archive or build for Release, this code is completely removed
- TestFlight and App Store builds have ZERO debug code

---

## How to Access Debug Test Panel

1. **Run the app** (Command + R) - automatically in Debug mode
2. **Look for the test tube icon** (🧪) in the top-right corner of any screen:
   - Game Selection screen
   - Lobby screens (Manhunt, CTF, Zombie Tag)
   - Active game screens
   - Profile screen
3. **Tap the test tube icon** → Opens the Debug Test Panel
4. **Use the test features** to:
   - Add fake players
   - Force game states
   - Test bubble configuration
   - Test Bluetooth
   - Test location services
   - And more...

---

## Debug Test Panel Features

### Game Tests
- Create test sessions (Manhunt, CTF, Zombie Tag)
- Add/remove fake players
- Force game states (Lobby, Active, Ended)
- Configure test bubbles
- Update bubble settings

### Profile Tests
- Set test profile names
- Test profile picture loading
- Test statistics

### Bluetooth Tests
- Start/stop BLE advertising
- Test tag requests
- View nearby players

### Location Tests
- Request location permissions
- Start/stop location updates
- View current coordinates

---

## Important Notes

1. **Debug mode is ONLY for development** - it will NEVER appear in production
2. **All debug code is wrapped in `#if DEBUG`** - automatically removed in Release builds
3. **Command + R = Debug mode** (you'll see test features)
4. **Archive = Release mode** (no test features)
5. **TestFlight/App Store = Release mode** (no test features)

---

## Verification

To verify debug code is properly isolated:

1. **Debug Build**: Run with Command + R → You'll see the test tube icon
2. **Release Build**: 
   - Product → Archive
   - The archive will NOT contain any debug code
   - TestFlight builds will NOT have test features

All test features are completely safe and will never appear in production builds.


