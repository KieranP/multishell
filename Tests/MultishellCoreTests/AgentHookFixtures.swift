import Foundation
import TestScratch

protocol AgentHookFixtures {}

extension AgentHookFixtures {
  var helper: String { "$HOME/Library/Application Support/Multishell/bin/multishell" }

  func temporaryDirectory() -> URL {
    Scratch.path("hooks")
  }
}
