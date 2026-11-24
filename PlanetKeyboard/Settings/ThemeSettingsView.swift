import SwiftUI

struct ThemeSettingsView: View {
    @Binding var selectedThemeID: String

    var body: some View {
        List(KeyboardTheme.allBuiltIn) { theme in
            Button {
                selectedThemeID = theme.id
            } label: {
                HStack(spacing: 12) {
                    themePreview(theme)
                    Text(theme.name)
                        .foregroundStyle(.primary)
                    Spacer()
                    if theme.id == selectedThemeID {
                        Image(systemName: "checkmark")
                            .foregroundColor(.accentColor)
                            .fontWeight(.semibold)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("Theme")
    }

    private func themePreview(_ theme: KeyboardTheme) -> some View {
        HStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 3)
                .fill(theme.background)
                .frame(width: 14, height: 32)
            VStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.keyBackground)
                    .frame(width: 20, height: 14)
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.specialKeyBackground)
                    .frame(width: 20, height: 14)
            }
            RoundedRectangle(cornerRadius: 3)
                .fill(theme.accent)
                .frame(width: 14, height: 32)
        }
        .padding(4)
        .background(theme.background)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
    }
}
