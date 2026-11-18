import Foundation
import TestScratch
import Testing

@testable import MultishellProcess

@Suite
struct OpenDescriptorCountTests {
  private static let pipeCount = 50

  @Test func openPipesRaiseTheCountByTheirEnds() throws {
    let pid = ProcessInfo.processInfo.processIdentifier
    let before = try #require(OpenDescriptorCount.of(pid))
    let pipes = (0..<Self.pipeCount).map { _ in Pipe() }
    let held = try #require(OpenDescriptorCount.of(pid))

    #expect(held >= before + Self.pipeCount)
    withExtendedLifetime(pipes) {}
  }

  @Test func aPIDNothingHoldsHasNoCount() {
    #expect(OpenDescriptorCount.of(deadPID()) == nil)
  }
}
