import Foundation

protocol InputEngine: AnyObject {
    var language: Language { get }
    func handleKey(_ key: KeyEvent) -> InputResult
    var compositionText: String { get }
    var candidates: [String] { get }
    func selectCandidate(at index: Int) -> String
    func reset()
}
