import SwiftUI

/// Shows ThirdPartyNotices.txt (GPL-3.0 notice, librime and its dependencies, rime-ice, Unicode CLDR).
struct LicensesView: View {
    private let text: String = {
        guard let url = Bundle.main.url(forResource: "ThirdPartyNotices", withExtension: "txt"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return "License information is unavailable."
        }
        return content
    }()

    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle("Open Source Licenses")
        .navigationBarTitleDisplayMode(.inline)
    }
}
