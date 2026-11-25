import CoreGraphics

/// Sizes of the iOS system keyboard (measured on iOS 26, iPhone portrait: 45 pt keys, 11 pt
/// between rows). The height only changes with the orientation and the user's size setting
/// for the current language (Korean / English & Chinese), never with the page.
struct KeyboardMetrics: Equatable {
    var barHeight: CGFloat
    var keyHeight: CGFloat
    var rowGap: CGFloat
    var keyGap: CGFloat
    var sidePadding: CGFloat
    var topPadding: CGFloat
    var bottomPadding: CGFloat

    static let portrait = KeyboardMetrics(barHeight: 44, keyHeight: 45, rowGap: 11, keyGap: 6,
                                          sidePadding: 3, topPadding: 2, bottomPadding: 6)
    static let landscape = KeyboardMetrics(barHeight: 36, keyHeight: 34, rowGap: 6, keyGap: 6,
                                           sidePadding: 3, topPadding: 2, bottomPadding: 4)

    static func forSize(_ size: CGSize) -> KeyboardMetrics {
        size.width > size.height && size.height > 0 ? .landscape : .portrait
    }

    /// System metrics with taller (or shorter) keys and row gaps; widths stay those of the screen.
    static func make(landscape: Bool, scale: Double) -> KeyboardMetrics {
        var m = landscape ? KeyboardMetrics.landscape : .portrait
        let range = AppConstants.keyScaleRange
        let s = CGFloat(min(max(scale, range.lowerBound), range.upperBound))
        m.keyHeight = (m.keyHeight * s).rounded()
        m.rowGap = (m.rowGap * s * 2).rounded() / 2
        return m
    }

    /// Height of the 4 key rows plus padding.
    var keysHeight: CGFloat { topPadding + keyHeight * 4 + rowGap * 3 + bottomPadding }
    var totalHeight: CGFloat { barHeight + keysHeight }
}

/// Pure row layout (unit-tested): frames of each key of a row inside `width`.
enum RowLayout {
    static func frames(for row: KeyRow, width: CGFloat, y: CGFloat, metrics m: KeyboardMetrics) -> [CGRect] {
        let inner = width - m.sidePadding * 2
        let columns = CGFloat(max(row.columns, 1))
        let unit = (inner - m.keyGap * (columns - 1)) / columns
        let visible = row.keys.filter { !$0.isSpacer }.count
        let gaps = m.keyGap * CGFloat(max(visible - 1, 0))

        var fixed: CGFloat = 0
        var flexWeight: CGFloat = 0
        for key in row.keys {
            switch key.width {
            case .standard: fixed += unit
            case .wide(let n): fixed += unit * n + m.keyGap * (n - 1).rounded(.down)
            case .flex(let w): flexWeight += w
            case .gap(let n): fixed += (unit + m.keyGap) * n
            }
        }
        let leftover = max(inner - fixed - gaps, 0)
        // Rows without flexible keys are centred (e.g. 9 keys on a 10-column page).
        var x = m.sidePadding + (flexWeight == 0 ? leftover / 2 : 0)
        var frames: [CGRect] = []
        var previousVisible = false
        for key in row.keys {
            let w: CGFloat
            switch key.width {
            case .standard: w = unit
            case .wide(let n): w = unit * n + m.keyGap * (n - 1).rounded(.down)
            case .flex(let weight): w = leftover * weight / flexWeight
            case .gap(let n): w = (unit + m.keyGap) * n
            }
            if key.isSpacer {
                frames.append(CGRect(x: x, y: y, width: w, height: m.keyHeight))
                x += w
                previousVisible = false
                continue
            }
            if previousVisible { x += m.keyGap }
            frames.append(CGRect(x: x, y: y, width: w, height: m.keyHeight))
            x += w
            previousVisible = true
        }
        return frames
    }
}
