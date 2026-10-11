import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellProcess

@Suite
struct LeadingPathStatementTests {
  @Test(arguments: ["/bin/zsh", "/bin/bash", "/bin/sh", "/bin/ksh", "/opt/homebrew/bin/fish"])
  func aLoginShellsLineReadsTheLeadingPathInItsOwnSyntaxStartingNoOtherShell(shell: String) {
    let line = LeadingPathStatement.line(
      for: ShellInvocation(executable: URL(fileURLWithPath: shell), arguments: ["-l", "-i", "-c"])
    )

    #expect(line.contains(SessionEnvironment.leadingPathVariable), "\(shell)")
    #expect(!line.contains("/bin/sh"), "\(shell): \(line)")
  }
}
