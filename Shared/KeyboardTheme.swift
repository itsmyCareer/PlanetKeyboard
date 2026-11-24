import SwiftUI

struct KeyboardTheme: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var keyBackgroundHex: String
    var keyTextHex: String
    var specialKeyBackgroundHex: String
    var backgroundHex: String
    var accentHex: String

    // Computed SwiftUI Color properties (not Codable)
    var keyBackground: Color { Color(hex: keyBackgroundHex) }
    var keyText: Color { Color(hex: keyTextHex) }
    var specialKeyBackground: Color { Color(hex: specialKeyBackgroundHex) }
    var background: Color { Color(hex: backgroundHex) }
    var accent: Color { Color(hex: accentHex) }

    // Built-in themes
    static let defaultLight = KeyboardTheme(
        id: "default-light", name: "Default",
        keyBackgroundHex: "#FFFFFF", keyTextHex: "#000000",
        specialKeyBackgroundHex: "#AEB3BF", backgroundHex: "#D1D3D9", accentHex: "#007AFF"
    )

    static let dark = KeyboardTheme(
        id: "dark", name: "Dark",
        keyBackgroundHex: "#505050", keyTextHex: "#FFFFFF",
        specialKeyBackgroundHex: "#333333", backgroundHex: "#1C1C1E", accentHex: "#0A84FF"
    )

    static let ocean = KeyboardTheme(
        id: "ocean", name: "Ocean",
        keyBackgroundHex: "#E8F4FD", keyTextHex: "#1A3A5C",
        specialKeyBackgroundHex: "#B8D8E8", backgroundHex: "#C5E3F0", accentHex: "#2196F3"
    )

    static let allBuiltIn: [KeyboardTheme] = [defaultLight, dark, ocean]
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
        default:
            r = 1; g = 1; b = 1
        }
        self.init(red: r, green: g, blue: b)
    }
}
