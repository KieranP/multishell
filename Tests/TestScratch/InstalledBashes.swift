import Foundation

/// The system's bash 3.2 and any newer one installed, whose `$!` and `wait` differ.
public enum InstalledBashes {
  static let system = "/bin/bash"

  public static let all = InstalledShells.only([
    system, "/opt/homebrew/bin/bash", "/usr/local/bin/bash",
  ])

  public static var newer: String? { all.first { $0 != system } }
}
