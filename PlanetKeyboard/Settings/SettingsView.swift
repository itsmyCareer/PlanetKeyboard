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

            // MARK: - Keyboard size
            Section {
                KeySizeRow(title: "Korean", scale: $settings.koreanKeyScale)
                KeySizeRow(title: "English & Chinese", scale: $settings.latinKeyScale)
            } header: {
                Text("Key Size")
            } footer: {
                Text("100% is the size of the iPhone keyboard. Bigger keys make the keyboard taller.")
            }

            // MARK: - Feedback
            HapticSettingsSection(settings: $settings)

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
        .onChange(of: settings.hapticMethod) { _ in settings.save() }
        .onChange(of: settings.pairedLanguageMode) { _ in settings.save() }
        .onChange(of: settings.selectedThemeID) { _ in settings.save() }
        .onChange(of: settings.koreanKeyScale) { _ in settings.save() }
        .onChange(of: settings.latinKeyScale) { _ in settings.save() }
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

/// A key size slider in 5% steps (85% – 130%); 100% = the iPhone system keyboard.
private struct KeySizeRow: View {
    let title: String
    @Binding var scale: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(label)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                if abs(scale - 1) > 0.001 {
                    Button("Reset") { scale = 1 }
                        .buttonStyle(.borderless)
                        .font(.subheadline)
                }
            }
            Slider(value: $scale, in: AppConstants.keyScaleRange, step: 0.05) {
                Text(title)
            } minimumValueLabel: {
                Image(systemName: "textformat.size.smaller").foregroundStyle(.secondary)
            } maximumValueLabel: {
                Image(systemName: "textformat.size.larger").foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var label: String {
        let percent = Int((scale * 100).rounded())
        return percent == 100 ? "100% (iPhone)" : "\(percent)%"
    }
}
