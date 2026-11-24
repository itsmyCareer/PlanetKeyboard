import Foundation

struct KeyEvent {
    let keyCode: KeyCode
    let character: String?
    let timestamp: CFTimeInterval
    let type: KeyType
}
