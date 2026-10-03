import Darwin

/// A terminal's device number, as a process table names its controlling
/// terminal, from the path an engine names it by.
public enum TerminalDevice {
  /// `nil` for a path that is not there.
  public static func number(atPath path: String) -> Int32? {
    var status = stat()
    guard stat(path, &status) == 0 else { return nil }
    return status.st_rdev
  }
}
