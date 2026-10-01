import Foundation

/// The system's bash 3.2 and any newer one installed, whose `$!` and `wait` differ.
public enum InstalledBashes {
  public static let system = "/bin/bash"

  public static let all = [system, "/opt/homebrew/bin/bash", "/usr/local/bin/bash"]
    .filter { FileManager.default.isExecutableFile(atPath: $0) }

  public static var newer: String? { all.first { $0 != system } }
}
