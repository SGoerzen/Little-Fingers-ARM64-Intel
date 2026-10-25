# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Little Fingers is a macOS menu-bar app (no Dock icon) that locks the keyboard and mouse so kids can't mess with the Mac. Press ⌃⌥⇧⌘L to toggle the lock. The original author is Shaun Inman (2017). It's Swift 5 plus Objective-C, has no dependencies or tests, and targets macOS 12.

## Commands

```bash
make              # Release build → build/DerivedData/Build/Products/Release/Little Fingers.app
make debug        # Debug build
make run          # build + open the app
make install      # copy to /Applications (INSTALL_DIR=… to override)
make zip          # build/Little-Fingers.zip via ditto
make dmg          # build/Little-Fingers.dmg via hdiutil (app + Applications symlink)
make clean        # rm -rf build/
```

Every target wraps `xcodebuild` with the `Little Fingers` scheme. `xcodebuild` prints long DVTCoreDeviceCore / CoreSimulator errors at startup; they come from the local Xcode install and don't affect the macOS build. To see real problems, grep the output for `error:` lines that point at source files.

To see runtime output, run the executable directly instead of using `open`:
`"build/DerivedData/Build/Products/Debug/Little Fingers.app/Contents/MacOS/Little Fingers"`

## Architecture

- **`TapController.m` (Objective-C)** holds all of the input-blocking logic, in C globals and a C callback. It creates two `CGEventTap`s:
  - The *listen* tap watches key and modifier events for the ⌃⌥⇧⌘L chord.
  - The *ignore* tap (`kCGEventMaskForAllEvents`) swallows everything while the Mac is locked by returning `NULL`.

  `+listen` and `+ignore` swap which tap's run-loop source is active. A change in lock state posts the `SINotificationLockChanged` notification, which `StatusItemController` observes to swap the `on`/`off` template icon. The lock is paused automatically on screensaver, shutdown and logout through distributed notifications. The `L` key is a hard-coded key code (37), so the chord depends on the keyboard layout.
- **Accessibility permission gates everything.** `CGEventTapCreate` returns NULL without it, and `TapController.init` then calls `exit(1)`. For that reason `AppDelegate` creates the `TapController` only when `TapController.isAccessibilityEnabled()` is true. Otherwise `StatusItemController` shows the system permission prompt, checks every 0.5 s, and relaunches the app (`restartApp`) once permission is granted.
- **`StatusItemController.swift`** owns the menu-bar item, its menu, and the About window. **`AboutWindowController`** handles the "launch at login" checkbox and keeps it in sync with the `autoLaunch` user default.
- **`LoginItems.m`** uses `SMAppService.mainAppService` on macOS 13+. On macOS 12 it falls back to the deprecated `LSSharedFileList` API (warnings suppressed), which no longer works on current macOS. Swift reaches the Objective-C classes through `Little Fingers-Bridging-Header.h`.
- `AppDelegate` sets the `.accessory` activation policy and hides any visible `NSPanel` windows when the app resigns active or the status menu opens.

## Gotchas

- Methods used as `#selector` targets (timers, notifications, menu items) must be marked `@objc`. The code was migrated from Swift 3, which exposed them to Objective-C automatically.
- Store `NSControl.StateValue` in UserDefaults as `.rawValue`. Storing the struct itself crashes.
- Local builds are signed ad hoc (`CODE_SIGN_IDENTITY = "-"`), so each rebuild gets a new code identity. macOS then stops matching the existing Accessibility entry. Remove the app from System Settings → Privacy & Security → Accessibility and grant permission again.
- The bundle ID (`com.shauninman.Little-Fingers`) and `DEVELOPMENT_TEAM` (`V24C7FVP32`) still belong to the original author. Change them before signing for distribution. The App Store isn't an option, because sandboxed apps can't create a blocking event tap. Distribution needs Developer ID signing plus notarization.
- `privacy.scpt` (an AppleScript that opens System Preferences) is legacy and no longer called.
