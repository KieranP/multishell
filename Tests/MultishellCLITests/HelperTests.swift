import Foundation
import Testing

@testable import MultishellCore
@testable import MultishellProcess

/// The built `multishell` binary's command line.
@Suite(.serialized)
struct HelperTests {
  @Test func usageErrorsExitTwo() async throws {
    #expect(try await HelperBinary.run([]).status == 2)
    #expect(try await HelperBinary.run(["state", "sleeping"]).status == 2)
    #expect(try await HelperBinary.run(["state", "done", "--bogus"]).status == 2)
    #expect(try await HelperBinary.run(["frobnicate"]).status == 2)
  }

  @Test func theVersionNamesTheProtocolTheAppSpeaks() async throws {
    let version = try await HelperBinary.run(["--version"])
    #expect(version.succeeded && version.standardOutput.contains("protocol version 1"))
  }

  @Test func aMisspeltOptionWithAValueIsAUsageErrorForEveryReportingCommand() async throws {
    let environment = ["MULTISHELL_SOCKET": "/tmp/ms-nobody.sock"]
    let lines = [
      ["state", "running", "--sesion", UUID().uuidString],
      ["command-started", "--pdi", "4242"],
      ["command-finished", "--exit", "0", "--duraton", "3"],
      ["relay", "--pdi", "4242"],
    ]
    for line in lines {
      let output = try await HelperBinary.run(line, environment: environment)
      #expect(output.status == 2, "\(line)")
      #expect(output.standardError.contains("unexpected argument --"), "\(line)")
    }
  }
}
