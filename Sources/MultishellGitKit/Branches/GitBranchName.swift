import Foundation

/// Whether git would take a name as a branch: `git-check-ref-format(1)`'s rules in Swift, less the
/// full-refname ones about slashes; see worktrees/creating-and-removing.md.
public enum GitBranchName {
  private static let forbidden: Set<Unicode.Scalar> = [
    " ", "~", "^", ":", "?", "*", "[", "\\",
  ]

  /// By byte, as git judges it: a combining mark after `.`, `:` or `/` joins it
  /// into one `Character`, which a Character search would miss.
  public static func isValid(_ name: String) -> Bool {
    let name = name.trimmingCharacters(in: .whitespaces)
    let bytes = Array(name.utf8)
    // `@` alone is barred for a whole refname, not for a branch: git takes
    // it as `refs/heads/@`. `HEAD` it reads as the current branch instead.
    guard !bytes.isEmpty, name != "HEAD", !bytes.starts(with: "-".utf8), !ends(bytes, with: ".")
    else { return false }
    guard !bytes.starts(with: "/".utf8), !ends(bytes, with: "/"), !ends(bytes, with: ".lock") else {
      return false
    }
    guard !bytes.contains(Array("..".utf8)), !bytes.contains(Array("@{".utf8)),
      !bytes.contains(Array("//".utf8))
    else { return false }
    for component in bytes.split(separator: UInt8(ascii: "/"), omittingEmptySubsequences: false) {
      guard !component.isEmpty, !component.starts(with: ".".utf8),
        !ends(Array(component), with: ".lock")
      else { return false }
    }
    return !name.unicodeScalars.contains { scalar in
      forbidden.contains(scalar) || scalar.value < 0x20 || scalar.value == 0x7f
    }
  }

  private static func ends(_ bytes: [UInt8], with suffix: String) -> Bool {
    bytes.reversed().starts(with: suffix.utf8.reversed())
  }
}
