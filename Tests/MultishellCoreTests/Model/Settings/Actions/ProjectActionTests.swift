import Foundation
import Testing

@testable import MultishellCore

@Suite
struct ProjectActionTests {
  @Test func aBlankNameOrCommandIsNoActionAndANameIsReadTrimmed() throws {
    #expect(throws: (any Error).self) {
      try decodeJSON(ProjectAction.self, #"{ "name": " ", "command": "true" }"#)
    }
    #expect(throws: (any Error).self) {
      try decodeJSON(ProjectAction.self, #"{ "name": "Serve", "command": "\n" }"#)
    }
    let read = try decodeJSON(ProjectAction.self, #"{ "name": " Serve ", "command": "bin/dev" }"#)
    #expect(read == ProjectAction(name: "Serve", command: "bin/dev"))
  }

  @Test func aRowIsFilledInOnlyWithANameAndACommand() {
    #expect(ProjectAction(name: "Serve", command: "").hasName)
    #expect(!ProjectAction(name: " ", command: "bin/dev").hasName)
    #expect(ProjectAction.serve.isFilledIn)
    #expect(!ProjectAction(name: "New Action", command: " ").isFilledIn)
    #expect(!ProjectAction(name: "", command: "bin/dev").isFilledIn)
  }

  @Test func anEditedActionKeepsItsRowButEqualityIgnoresIt() {
    let action = ProjectAction(name: "", command: "")

    let edited = action.renamed("Serve").withCommand("bin/dev")

    #expect(edited.id == action.id)
    #expect(edited == ProjectAction(name: "Serve", command: "bin/dev"))
    #expect(ProjectAction(name: "", command: "").id != action.id)
  }

  @Test func aScriptRunsAsWrittenWithTheWorktreesValuesInTheirVariables() {
    let action = ProjectAction(name: "Serve", command: "npm run dev -- --port {{port}}")

    let line = action.scriptLine(values: [.port: "3010", .branch: "feature-x"])

    #expect(line.text == action.command)
    #expect(line.environment == ["MULTISHELL_PORT": "3010", "MULTISHELL_BRANCH": "feature-x"])
  }
}
