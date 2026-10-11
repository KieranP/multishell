import Foundation
import MultishellAppCore
import MultishellCore
import SwiftUI

/// The executable's entry: run as `multishell` with a command, it becomes the
/// helper (HelperHandOff); otherwise the app starts.
@main
enum MultishellLaunch {
  static func main() {
    if let arguments = HelperHandOff.helperArguments(from: CommandLine.arguments) {
      handOver(arguments)
    }
    // Before any child: every pane is a session of its own, not the launching shell's.
    for name in InheritedShellState.names(in: ProcessInfo.processInfo.environment) {
      unsetenv(name)
    }
    MultishellApp.main()
  }

  private static func handOver(_ arguments: [String]) -> Never {
    guard let helper = MacPlatform.bundledHelper else {
      FileHandle.standardError.write(Data("multishell: this build has no helper beside it\n".utf8))
      exit(1)
    }
    let argv = (["multishell"] + arguments).map { strdup($0) } + [nil]
    execv(helper.path, argv)
    perror("multishell: \(helper.path)")
    exit(1)
  }
}
