import Foundation

extension StatusEntry {
  /// Its letters and path as `git status --short` lines them up, `??` cut to
  /// one `?`: `M src/a.js`, `MM b.js`, `? notes.md`.
  var uncommittedLine: String {
    let letters = isUntracked ? "?" : String([indexState, workTreeState])
    return "\(letters.trimmingCharacters(in: .whitespaces)) \(path)"
  }
}
