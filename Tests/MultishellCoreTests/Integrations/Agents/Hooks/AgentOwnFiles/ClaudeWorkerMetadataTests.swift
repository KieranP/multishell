import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// Files in the shape Claude Code 2.1.292 writes them.
struct ClaudeWorkerMetadataTests {
  private func metadata(_ json: String) -> ClaudeWorkerMetadata? {
    ClaudeWorkerMetadata(json: Data(json.utf8))
  }

  @Test func aWorkerKeepsItsNameAndItsDescriptionApart() {
    #expect(
      metadata(
        #"{"agentType":"general-purpose","description":"/code-review . high","name":"code-review"}"#
      ) == ClaudeWorkerMetadata(name: "code-review", description: "/code-review . high"))
    #expect(
      metadata(#"{"description":"Reuse angle","parentAgentId":"ac15f9fedbcaa9669"}"#)
        == ClaudeWorkerMetadata(parentID: "ac15f9fedbcaa9669", description: "Reuse angle"))
  }

  @Test func aParentThatCouldNotBeAnIdIsNoParentAndAFileThatIsNotJSONIsNoMetadata() {
    #expect(metadata(#"{"parentAgentId":"../x"}"#)?.parentID == nil)
    #expect(metadata(#"{"name":"","description":""}"#) == ClaudeWorkerMetadata())
    #expect(metadata("not json") == nil)
  }

  @Test func theFileSitsInTheSessionsFolderBesideItsTranscript() {
    #expect(
      ClaudeWorkerMetadata.path(ofWorker: "a1", transcriptPath: "/p/session.jsonl")
        == "/p/session/subagents/agent-a1.meta.json")
  }

  @Test func aWorkerIdThatWouldLeaveTheFolderIsNeverRead() throws {
    let directory = try Scratch.directory("worker-metadata")
    defer { Scratch.remove(directory) }
    try Data(#"{"name":"planted"}"#.utf8).write(to: directory.appendingPathComponent("x.meta.json"))
    try FileManager.default.createDirectory(
      at: directory.appendingPathComponent("session/subagents/agent-"),
      withIntermediateDirectories: true)
    let transcript = directory.appendingPathComponent("session.jsonl").path
    #expect(ClaudeWorkerMetadata.read(ofWorker: "/../../../x", transcriptPath: transcript) == nil)
  }
}
