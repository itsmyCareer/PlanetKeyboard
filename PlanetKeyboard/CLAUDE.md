[Root](../CLAUDE.md) > **PlanetKeyboard (Main App)**

# PlanetKeyboard -- Main App Target

> Module-level AI context. Generated 2026-04-17T10:36:45.

## Module Purpose

The main app target serves as the container application for the PlanetKeyboard keyboard extension. It provides:

- Onboarding flow guiding users to enable the keyboard in iOS Settings.
- A settings interface for theme customization, language preferences, and haptic feedback toggles.
- A live preview of the keyboard with the selected theme.
- Persistence of user settings via App Groups so the keyboard extension can read them.

## Entry Point and Startup

| File | Role |
|---|---|
| `App/PlanetKeyboardApp.swift` | `@main` App entry point; sets up the SwiftUI app lifecycle. |
| `App/ContentView.swift` | Root view; likely a `NavigationStack` hosting settings and preview. |

## Directory Structure

```
PlanetKeyboard/
  App/
    PlanetKeyboardApp.swift      # @main entry
    ContentView.swift             # Root navigation view
  Settings/
    SettingsView.swift            # Main settings screen
    ThemeSettingsView.swift       # Theme color/style picker
  Models/
    Theme.swift                   # Theme model (Codable, App Group serializable)
    KeyboardSettings.swift        # User preferences model
  Resources/
    Assets.xcassets/              # App icons, color sets
    Info.plist                    # App target plist
```

## External Interfaces

This target has no public API. It communicates with the KeyboardExtension exclusively through:

- **App Group UserDefaults** -- for lightweight settings (selected theme ID, language preference, haptic on/off).
- **App Group shared container** -- for larger assets if needed (custom theme files).

## Key Dependencies and Configuration

| Dependency | Type | Notes |
|---|---|---|
| SwiftUI | System framework | Primary UI framework |
| Shared module | Internal | `Constants.swift`, `AppGroup.swift` |

No third-party dependencies.

### Info.plist Noteworthy Keys

- `NSAppTransportSecurity` -- not required unless network features are added.
- App Group entitlement must match the KeyboardExtension target.

## Data Models

### Theme

```swift
struct Theme: Codable, Identifiable {
    let id: String
    var name: String
    var keyBackgroundColor: Color   // serialized as hex
    var keyTextColor: Color
    var backgroundColor: Color
    var accentColor: Color
}
```

### KeyboardSettings

```swift
struct KeyboardSettings: Codable {
    var selectedThemeID: String
    var hapticFeedbackEnabled: Bool
    var preferredLanguage: Language  // enum: .english, .chinese, .korean
    var soundEnabled: Bool
}
```

## Testing and Quality

| Scope | Approach |
|---|---|
| Models | Unit tests for `Codable` round-trip, defaults, App Group read/write. |
| Settings UI | Manual / snapshot tests. |
| Theme persistence | Integration test writing to App Group suite and reading back. |

## FAQ

**Q: Why is the main app so minimal?**
A: Apple requires a container app, but all keyboard logic lives in the extension. The app exists for settings and onboarding.

**Q: How do I add a new setting?**
A: Add the property to `KeyboardSettings`, update `SettingsView`, and ensure the key is read in the extension via `AppGroup.userDefaults`.

## Related Files

- `../Shared/AppGroup.swift` -- App Group helper used for persistence.
- `../Shared/Constants.swift` -- Shared keys and identifiers.
- `../KeyboardExtension/Theme/ThemeManager.swift` -- Reads theme set by this app.

## Changelog

| Date | Action | Details |
|---|---|---|
| 2026-04-17 | Created | Initial module documentation from planned architecture. |
| 2026-11-25 | Settings | "Globe Key: 한 ↔ EN Only" toggle (`KeyboardSettings.pairedLanguageMode`, App Group key `pairedLanguageMode`). |
