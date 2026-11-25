[Root](../CLAUDE.md) > **Shared**

# Shared -- Common Code Module

> Module-level AI context. Generated 2026-04-17T10:36:45.

## Module Purpose

The Shared module contains code that is compiled into both the main app target (`PlanetKeyboard`) and the keyboard extension target (`KeyboardExtension`). It provides:

- A single source of truth for constants (App Group identifiers, UserDefaults keys, the `Language` enum).
- A helper for App Group data sharing so both targets use the same read/write logic.

This module must remain **minimal and dependency-free**. Every byte compiled here is duplicated in both targets.

## Entry Point and Startup

No entry point. This module is a static library / source files included in both targets. There is no initialization; all types are used on demand.

## Directory Structure

```
Shared/
  Constants.swift      # App Group ID, UserDefaults keys, Language enum
  AppGroup.swift       # UserDefaults(suiteName:) helper, shared container URL
  KeyboardStatus.swift # HapticMethod; what the keyboard last saw (Full Access, last haptic) for the app
```

## External Interfaces

### Constants.swift

```swift
enum Language: String, Codable, CaseIterable {
    case english = "en"
    case chinese = "zh"
    case korean  = "ko"
}

enum AppConstants {
    static let appGroupID = "group.com.planetkeyboard.shared"

    enum UserDefaultsKey {
        static let selectedTheme = "selectedThemeID"
        static let hapticFeedback = "hapticFeedbackEnabled"
        static let preferredLanguage = "preferredLanguage"
        static let soundEnabled = "soundEnabled"
    }
}
```

### AppGroup.swift

```swift
struct AppGroup {
    /// Shared UserDefaults suite for App Group communication.
    static var userDefaults: UserDefaults {
        UserDefaults(suiteName: AppConstants.appGroupID)!
    }

    /// URL of the shared container directory for file-based sharing.
    static var containerURL: URL {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppConstants.appGroupID
        )!
    }
}
```

## Key Dependencies and Configuration

| Dependency | Type | Notes |
|---|---|---|
| Foundation | System | `UserDefaults`, `FileManager`, `URL` |

No other dependencies. No UIKit, no SwiftUI.

### Build Configuration

Both targets must:
1. Include the Shared source files in their "Compile Sources" build phase.
2. Have the same App Group entitlement (`group.com.planetkeyboard.shared`) in their `.entitlements` files.

## Data Models

No complex data models. The `Language` enum and `AppConstants` namespace are the primary types.

## Testing and Quality

| Scope | Approach |
|---|---|
| AppGroup read/write | Integration test: write a value from one suite instance, read from another. |
| Constants | Static analysis; ensure keys are unique and match between targets. |
| Language enum | Unit test `CaseIterable` count, `rawValue` round-trip, `Codable` encode/decode. |

## FAQ

**Q: Why not use an SPM package for Shared?**
A: For a two-target Xcode project of this size, including source files directly is simpler and avoids SPM resolution overhead. If the project grows to many targets, migrating to a local SPM package is reasonable.

**Q: Can I add UIKit or SwiftUI imports here?**
A: No. Shared must remain Foundation-only so it compiles cleanly for both the app and the extension without pulling in UI frameworks unnecessarily.

**Q: What if I need to share a complex model?**
A: Add it here only if both targets truly need the same type. Otherwise keep models in their respective target.

## Related Files

- `../PlanetKeyboard/Models/KeyboardSettings.swift` -- consumes `AppConstants.UserDefaultsKey` values.
- `../KeyboardExtension/Theme/ThemeManager.swift` -- reads from `AppGroup.userDefaults`.
- `../KeyboardExtension/KeyboardViewController.swift` -- reads `Language` preference on launch.

## Changelog

| Date | Action | Details |
|---|---|---|
| 2026-04-17 | Created | Initial module documentation from planned architecture. |
| 2026-11-25 | Haptics | KeyboardStatus.swift (HapticMethod, keyboard diagnostics in the App Group). |
