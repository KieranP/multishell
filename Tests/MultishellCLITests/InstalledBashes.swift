import Foundation

/// The system's bash 3.2 and any newer one installed, whose `$!` and `wait` differ.
enum InstalledBashes {
  static let system = "/bin/bash"

  static let all = [system, "/opt/homebrew/bin/bash", "/usr/local/bin/bash"]
    .filter { FileManager.default.isExecutableFile(atPath: $0) }

  static var newer: String? { all.first { $0 != system } }
}
