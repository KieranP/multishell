import Foundation

extension Data {
  /// Valid UTF-8 with no zero byte, git's test and more. `isCut` where the
  /// bytes are a file's start, which may have stopped mid-character.
  func readsAsText(isCut: Bool) -> Bool {
    guard !contains(0) else { return false }
    // A read that stopped mid-character cut up to three bytes off its end.
    let cut = isCut ? 0...3 : 0...0
    return cut.contains { String(validating: dropLast($0), as: UTF8.self) != nil }
  }
}
