import Foundation
import Synchronization
import TestScratch
import Testing

@testable import MultishellCLI
@testable import MultishellCore
@testable import MultishellProcess

@Suite(.serialized)
struct HelperDebugSamplesTests {
  @Test func followingPrintsEachNewSampleOnALineOfItsOwnAndStopsAtTheCount() async throws {
    let landed = Mutex(0)
    let app = try ControlListener { _ in
      let newest = landed.withLock { count in
        defer { count += 1 }
        return count
      }
      let samples = (0...newest).map { #"{"sequence":\#($0),"appMemory":7}"# }
      return .output("[" + samples.joined(separator: ",") + "]")
    }
    defer { app.stop() }

    let output = try await HelperBinary.run(
      ["debug", "samples", "--follow", "--count", "2"],
      environment: app.environment,
    )

    #expect(output.succeeded, "\(output.standardError)")
    #expect(
      output.standardOutput
        == #"{"appMemory":7,"sequence":1}"# + "\n" + #"{"appMemory":7,"sequence":2}"# + "\n"
    )
  }

  @Test func followingAsksForTheNewestFewAndForMoreOnlyOnceItFellBehind() async throws {
    let asked = Mutex<[Int]>([])
    let app = try ControlListener { request in
      guard case .debugSamples(let last) = request else { return .output("[]") }
      let call = asked.withLock { asked in
        asked.append(last)
        return asked.count - 1
      }
      let newest = call < 2 ? call : 6
      let samples = (max(0, newest - last + 1)...newest).map { #"{"sequence":\#($0)}"# }
      return .output("[" + samples.joined(separator: ",") + "]")
    }
    defer { app.stop() }

    let output = try await HelperBinary.run(
      ["debug", "samples", "--follow", "--count", "6"],
      environment: app.environment,
    )

    #expect(output.standardOutput == (1...6).map { #"{"sequence":\#($0)}"# + "\n" }.joined())
    #expect(asked.withLock { $0 } == [1, 2, 2, 30])
  }

  @Test func aCountWithoutFollowIsAUsageError() async throws {
    #expect(try await HelperBinary.run(["debug", "samples", "--count", "2"]).status == 2)
  }

  @Test func aSampleLandingAsTheBacklogIsReadIsPrintedOnce() async throws {
    let asked = Mutex(0)
    let app = try ControlListener { _ in
      let call = asked.withLock { count in
        defer { count += 1 }
        return count
      }
      return .output(call == 0 ? #"[{"sequence":0}]"# : #"[{"sequence":0},{"sequence":1}]"#)
    }
    defer { app.stop() }

    let output = try await HelperBinary.run(
      ["debug", "samples", "--follow", "--last", "2", "--count", "1"],
      environment: app.environment,
    )

    #expect(output.standardOutput == #"{"sequence":0}"# + "\n" + #"{"sequence":1}"# + "\n")
  }

  @Test func aSummaryCannotBeFollowed() async throws {
    #expect(try await HelperBinary.run(["debug", "samples", "--summary", "--follow"]).status == 2)
  }
}
