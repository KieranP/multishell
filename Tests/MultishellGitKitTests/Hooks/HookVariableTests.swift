import Testing

@testable import MultishellCore
@testable import MultishellGitKit

@Suite
struct HookVariableTests {
  @Test func everyHookVariableIsSpelledAsTheAgentPlaceholderMeaningTheSame() {
    let placeholderVariables = Set(AgentPlaceholder.allCases.map(\.variable))
    for variable in HookVariable.allCases {
      #expect(placeholderVariables.contains(variable.name), "\(variable.name)")
    }
  }
}
