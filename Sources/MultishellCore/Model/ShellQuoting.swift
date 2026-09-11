import Foundation

/// Turns an argument list into one POSIX shell command line: libghostty takes
/// a surface's command as a single string it hands to the shell.
public enum ShellQuoting {
  public static func commandLine(_ arguments: [String]) -> String {
    arguments.map(quote).joined(separator: " ")
  }

  /// Single quotes pass everything through untouched except a single quote,
  /// which ends the quoting, adds an escaped one, and starts again.
  public static func quote(_ argument: String) -> String {
    let safe = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_./=:@%+,"))
    if !argument.isEmpty, argument.unicodeScalars.allSatisfy(safe.contains) {
      return argument
    }
    return "'" + argument.replacingOccurrences(of: "'", with: "'\\''") + "'"
  }
}
