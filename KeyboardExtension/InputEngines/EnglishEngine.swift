import Foundation

final class EnglishEngine: InputEngine {

    /// `once` = next letter only (tap / auto-capitalization), `locked` = caps lock (double tap).
    enum ShiftState: Equatable { case off, once, locked }

    let language: Language = .english

    var shiftState: ShiftState = .off
    var isShifted: Bool { shiftState != .off }

    var compositionText: String { "" }
    var candidates: [String] { [] }

    func handleKey(_ key: KeyEvent) -> InputResult {
        switch key.keyCode {
        case .character(let ch):
            let output = isShifted ? ch.uppercased() : ch.lowercased()
            if shiftState == .once, ch.count == 1 { shiftState = .off }
            return .insert(output)

        case .shift:
            shiftState = shiftState == .off ? .once : .off
            return .none

        case .backspace:
            return .delete

        case .space:
            return .insert(" ")

        case .return_:
            return .insert("\n")

        case .language, .numbers, .symbols, .emoji, .dismiss:
            return .none
        }
    }

    func selectCandidate(at index: Int) -> String { "" }

    func reset() {
        shiftState = .off
    }
}
