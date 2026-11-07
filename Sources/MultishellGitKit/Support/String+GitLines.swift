import Foundation

extension String {
  /// The lines git wrote, split on `\n` alone: a path or branch name may hold
  /// U+2028 or U+0085, which `isNewline` also splits on.
  var gitLines: [String] {
    components(separatedBy: "\n").filter { !$0.isEmpty }
  }
}
