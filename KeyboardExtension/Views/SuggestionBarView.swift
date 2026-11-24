import SwiftUI

/// The strip above the keys: Pinyin candidates (first one = what space commits) mixed with
/// emoji, or emoji suggestions for the word before the cursor (ㅋㅋ → 😂).
struct SuggestionBarView: View {
    @ObservedObject var model: KeyboardViewModel
    var height: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            if let toggle = model.languageToggle, !model.isComposing {
                LanguageToggleView(toggle: toggle) { model.onToggleLanguage?() }
            }
            if model.suggestions.isEmpty {
                Spacer()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(model.suggestions) { item in
                            Button { model.onSelect?(item) } label: {
                                SuggestionCell(item: item, isPrimary: model.isComposing && item.id == 0)
                            }
                            .buttonStyle(SuggestionButtonStyle())
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .modifier(NoScrollEdgeEffect())
            }
            trailingButton
        }
        .frame(height: height)
    }

    @ViewBuilder private var trailingButton: some View {
        if model.isComposing {
            Button { model.isExpanded.toggle() } label: {
                Image(systemName: model.isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 44, height: height)
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
        } else {
            Button { model.onDismiss?() } label: {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.system(size: 17))
                    .frame(width: 44, height: height)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

/// 한 中 / EN 中: one button that flips between the base language and Chinese. The current
/// one sits in a raised key-coloured box; the other is smaller and dimmed.
struct LanguageToggleView: View {
    let toggle: KeyboardViewModel.LanguageToggle
    let action: () -> Void
    @Namespace private var namespace
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                segment(toggle.baseLabel, selected: !toggle.chineseSelected)
                segment("中", selected: toggle.chineseSelected)
            }
            .padding(2)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.07)))
            .padding(.leading, 6)
            .padding(.trailing, 4)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: toggle)
        .accessibilityLabel(toggle.chineseSelected ? "中文" : (toggle.baseLabel == "EN" ? "English" : "한국어"))
    }

    private func segment(_ text: String, selected: Bool) -> some View {
        Text(text)
            .font(.system(size: selected ? 16 : 13, weight: selected ? .semibold : .regular))
            .foregroundStyle(selected ? Color.primary : Color.secondary)
            .frame(width: 32, height: 28)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(colorScheme == .dark ? Color(white: 0.42) : Color.white)
                        .shadow(color: .black.opacity(0.25), radius: 0, x: 0, y: 1)
                        .matchedGeometryEffect(id: "selection", in: namespace)
                }
            }
    }
}

struct SuggestionCell: View {
    let item: KeyboardViewModel.Suggestion
    let isPrimary: Bool

    var body: some View {
        Text(item.text)
            .font(.system(size: item.isEmoji ? 26 : 20, weight: isPrimary ? .semibold : .regular))
            .foregroundStyle(isPrimary ? Color.accentColor : Color.primary)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, item.isEmoji ? 7 : 11)
            .frame(minWidth: 40, maxHeight: .infinity)
            .contentShape(Rectangle())
    }
}

struct SuggestionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(configuration.isPressed ? 0.12 : 0)))
    }
}

/// iOS 26+ blurs content scrolling under bar edges; candidates must stay sharp.
struct NoScrollEdgeEffect: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectHidden(true, for: .all)
        } else {
            content
        }
    }
}

/// All candidates in a grid (the chevron in the bar), shown in place of the keys. Like the
/// system keyboard the grid has 6 columns and a long word spans as many columns as it needs.
struct CandidateGridView: View {
    @ObservedObject var model: KeyboardViewModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            ColumnFlowLayout(columns: 6, rowHeight: 46) {
                ForEach(model.suggestions) { item in
                    Button { model.onSelect?(item) } label: {
                        SuggestionCell(item: item, isPrimary: item.id == 0)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .buttonStyle(SuggestionButtonStyle())
                }
            }
            .padding(.horizontal, 4)
        }
        .modifier(NoScrollEdgeEffect())
    }
}

/// Places views left to right in rows; each view takes a whole number of equal columns.
struct ColumnFlowLayout: Layout {
    var columns: Int
    var rowHeight: CGFloat

    private func spans(_ subviews: Subviews, unit: CGFloat) -> [Int] {
        subviews.map { view in
            let ideal = view.sizeThatFits(.unspecified).width
            return min(columns, max(1, Int((ideal / unit).rounded(.up))))
        }
    }

    private func rows(_ spans: [Int]) -> [[Int]] {
        var rows: [[Int]] = [[]]
        var used = 0
        for (i, span) in spans.enumerated() {
            if used + span > columns, !rows[rows.count - 1].isEmpty {
                rows.append([])
                used = 0
            }
            rows[rows.count - 1].append(i)
            used += span
        }
        return rows
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 360
        let unit = width / CGFloat(columns)
        let count = subviews.isEmpty ? 0 : rows(spans(subviews, unit: unit)).count
        return CGSize(width: width, height: CGFloat(count) * rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let unit = bounds.width / CGFloat(columns)
        let spans = spans(subviews, unit: unit)
        let allRows = rows(spans)
        for (r, row) in allRows.enumerated() {
            // Stretch full rows to the width; the last row keeps plain columns.
            let used = row.reduce(0) { $0 + spans[$1] }
            let scale = r == allRows.count - 1 ? 1 : CGFloat(columns) / CGFloat(max(used, 1))
            var x = bounds.minX
            for i in row {
                let w = unit * CGFloat(spans[i]) * scale
                subviews[i].place(at: CGPoint(x: x, y: bounds.minY + CGFloat(r) * rowHeight),
                                  proposal: ProposedViewSize(width: w, height: rowHeight))
                x += w
            }
        }
    }
}
