import Foundation

@testable import MultishellProcess

extension ShellInvocation {
  static let loginZsh = ShellInvocation(
    executable: URL(fileURLWithPath: "/bin/zsh"),
    arguments: ["-l", "-i", "-c"],
  )
}
