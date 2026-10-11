import Foundation

@testable import MultishellAppCore
@testable import MultishellProcess

extension String {
  /// A tab's line without the PATH statement it opens with, whichever login
  /// shell `SHELL` names on the machine running the tests.
  var withoutLeadingPathStatement: String {
    for shell in ["/bin/zsh", "/opt/homebrew/bin/fish", "/bin/bash"] {
      let invocation = ShellInvocation(executable: URL(fileURLWithPath: shell), arguments: ["-l"])
      let statement = LeadingPathStatement.line(for: invocation)
      if hasPrefix(statement) { return String(dropFirst(statement.count)) }
    }
    return self
  }
}
