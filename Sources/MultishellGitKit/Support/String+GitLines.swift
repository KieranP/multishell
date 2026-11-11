import Foundation

extension String {
  /// The lines git wrote, split on `\n` alone and a `\r` before it dropped: a path
  /// or branch name may hold U+2028 or U+0085, which `isNewline` also splits on.
  var gitLines: [String] {
    components(separatedBy: "\n")
      .map { $0.hasSuffix("\r") ? String($0.dropLast()) : $0 }
      .filter { !$0.isEmpty }
  }
}
