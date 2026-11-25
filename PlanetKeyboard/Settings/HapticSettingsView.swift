import AudioToolbox
import SwiftUI
import UIKit

/// Haptic settings: on/off, the vibration method, an in-app test, and what the keyboard
/// last reported (Full Access, whether a haptic was played).
struct HapticSettingsSection: View {
    @Binding var settings: KeyboardSettings
    @Environment(\.scenePhase) private var scenePhase
    @State private var status = KeyboardStatus.load()

    var body: some View {
        Section {
            Toggle("Haptic Feedback", isOn: $settings.hapticFeedbackEnabled)
            if settings.hapticFeedbackEnabled {
                Picker("Vibration Method", selection: $settings.hapticMethod) {
                    Text("Standard").tag(HapticMethod.standard)
                    Text("System").tag(HapticMethod.system)
                }
                Button("Test Vibration") { play(settings.hapticMethod) }
            }
            Toggle("Key Sound", isOn: $settings.soundEnabled)
            statusRow
        } header: {
            Text("Feedback")
        } footer: {
            Text(footer)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active { status = KeyboardStatus.load() }
        }
    }

    // MARK: - Keyboard status

    @ViewBuilder private var statusRow: some View {
        HStack {
            Text("Keyboard Full Access")
            Spacer()
            Text(fullAccessLabel)
                .foregroundStyle(status?.fullAccess == true ? Color.secondary : Color.red)
        }
        if let status, status.fullAccess {
            HStack {
                Text("Last Keyboard Vibration")
                Spacer()
                Text(status.lastHapticAt.map { $0.formatted(date: .omitted, time: .shortened) } ?? "None")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var fullAccessLabel: String {
        guard let status else { return "Not Seen" }
        return status.fullAccess ? "On" : "Off"
    }

    private var footer: String {
        guard let status else {
            return "Open the keyboard once in any app. If this still says Not Seen, turn on Allow Full Access: Settings > General > Keyboard > Keyboards > PlanetKeyboard."
        }
        if !status.fullAccess {
            return "iOS only lets a keyboard vibrate with Allow Full Access: Settings > General > Keyboard > Keyboards > PlanetKeyboard."
        }
        return "If the test vibrates here but typing does not, try the other vibration method. If the test does not vibrate either, check Settings > Sounds & Haptics > System Haptics."
    }

    private func play(_ method: HapticMethod) {
        switch method {
        case .standard:
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        case .system:
            AudioServicesPlaySystemSound(HapticMethod.popSound)
        }
    }
}
