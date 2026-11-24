import SwiftUI

struct SettingsView: View {
    @Binding var settings: KeyboardSettings
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true

    var body: some View {
        Form {
            // MARK: - Language
            Section {
                Picker("Preferred Language", selection: $settings.preferredLanguage) {
                    ForEach(Language.allCases) { language in
                        Text(displayName(for: language)).tag(language)
                    }
                }
                Toggle("Globe Key: 한 ↔ EN Only", isOn: $settings.pairedLanguageMode)
            } header: {
                Text("Language")
            } footer: {
                Text(settings.pairedLanguageMode
                     ? "The globe key switches between Korean and English. Use the 한 中 / EN 中 button at the left of the suggestion bar to switch to Chinese."
                     : "The globe key cycles English, Chinese and Korean.")
            }

            // MARK: - Feedback
            Section("Feedback") {
                Toggle("Haptic Feedback", isOn: $settings.hapticFeedbackEnabled)
                Toggle("Key Sound", isOn: $settings.soundEnabled)
            }

            // MARK: - Theme
            Section("Theme") {
                NavigationLink {
                    ThemeSettingsView(selectedThemeID: $settings.selectedThemeID)
                } label: {
                    HStack {
                        Text("Theme")
                        Spacer()
                        Text(currentThemeName)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // MARK: - About
            Section("About") {
                NavigationLink {
                    OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                } label: {
                    Label("How to Enable Keyboard", systemImage: "questionmark.circle")
                }

                NavigationLink {
                    LicensesView()
                } label: {
                    Label("Open Source Licenses", systemImage: "doc.text")
                }

                HStack {
                    Text("Version")
                    Spacer()
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .onChange(of: settings.preferredLanguage) { _ in settings.save() }
        .onChange(of: settings.hapticFeedbackEnabled) { _ in settings.save() }
        .onChange(of: settings.soundEnabled) { _ in settings.save() }
        .onChange(of: settings.pairedLanguageMode) { _ in settings.save() }
        .onChange(of: settings.selectedThemeID) { _ in settings.save() }
    }

    private var currentThemeName: String {
        KeyboardTheme.allBuiltIn.first { $0.id == settings.selectedThemeID }?.name ?? "Default"
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private func displayName(for language: Language) -> String {
        switch language {
        case .english: return "English"
        case .chinese: return "Chinese (Pinyin)"
        case .korean: return "Korean (Danmoeum)"
        }
    }
}
