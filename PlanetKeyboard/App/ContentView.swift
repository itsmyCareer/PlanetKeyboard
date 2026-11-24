import SwiftUI

struct ContentView: View {
    @State private var settings = KeyboardSettings.load()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    keyboardStatusView
                }

                Section {
                    NavigationLink {
                        SettingsView(settings: $settings)
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }

                    NavigationLink {
                        OnboardingView(hasCompletedOnboarding: .constant(true))
                    } label: {
                        Label("Setup Guide", systemImage: "keyboard")
                    }
                }
            }
            .navigationTitle("PlanetKeyboard")
            .onAppear {
                settings = KeyboardSettings.load()
            }
        }
    }

    private var keyboardStatusView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "globe")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("PlanetKeyboard")
                        .font(.headline)
                    Text(languageLabel(settings.preferredLanguage))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func languageLabel(_ language: Language) -> String {
        switch language {
        case .english: return "English"
        case .chinese: return "Chinese (Pinyin)"
        case .korean: return "Korean (Danmoeum)"
        }
    }
}
