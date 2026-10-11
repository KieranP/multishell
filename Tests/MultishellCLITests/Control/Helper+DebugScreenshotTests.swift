import Foundation
import TestScratch
import Testing

@testable import MultishellCLI
@testable import MultishellCore
@testable import MultishellProcess

@Suite(.serialized)
struct HelperDebugScreenshotTests {
  @Test func aScreenshotIsWrittenWhereTheCommandSaysNotByTheApp() async throws {
    let app = try ControlListener(reply: .output("AQID"))
    let file = Scratch.path("snap").appendingPathExtension("png")
    defer {
      app.stop()
      try? FileManager.default.removeItem(at: file)
    }
    let pane = UUID()

    let output = try await HelperBinary.run(
      ["debug", "screenshot", file.path, "--pane", pane.uuidString],
      environment: app.environment,
    )

    #expect(output.succeeded, "\(output.standardError)")
    #expect(try Data(contentsOf: file) == Data([1, 2, 3]))
    let printed = try JSONSerialization.jsonObject(with: Data(output.standardOutput.utf8))
    #expect((printed as? [String: String]) == ["path": file.path])
    #expect(app.requests.received == [.screenshot(pane: pane)])
  }

  @Test func aScreenshotWithNoFileIsANewOneUnderTmpWhosePathIsPrinted() async throws {
    let app = try ControlListener(reply: .output("AQID"))
    defer { app.stop() }

    let output = try await HelperBinary.run(["debug", "screenshot"], environment: app.environment)

    let printed = try JSONSerialization.jsonObject(with: Data(output.standardOutput.utf8))
    let path = (printed as? [String: String])?["path"] ?? ""
    defer { try? FileManager.default.removeItem(atPath: path) }
    #expect(output.succeeded, "\(output.standardError)")
    #expect(path.hasPrefix("/tmp/multishell-screenshot-") && path.hasSuffix(".png"), "\(path)")
    #expect(FileManager.default.contents(atPath: path) == Data([1, 2, 3]))
  }

  @Test func anAnswerWithNoImageWritesNoFile() async throws {
    let app = try ControlListener(reply: .done)
    let file = Scratch.path("snap").appendingPathExtension("png")
    defer {
      app.stop()
      try? FileManager.default.removeItem(at: file)
    }

    let output = try await HelperBinary.run(
      ["debug", "screenshot", file.path],
      environment: app.environment,
    )

    #expect(output.status == 1)
    #expect(!FileManager.default.fileExists(atPath: file.path))
  }

  @Test func aScreenshotUnderTmpNeverWritesThroughANameAlreadyThere() throws {
    let date = Date(timeIntervalSince1970: 86_400 * 365)
    let planted = try Helper.writeScreenshot(Data([0]), to: nil, at: date)
    let target = Scratch.path("planted-target")
    try Data([9]).write(to: target)
    try FileManager.default.removeItem(at: planted)
    try FileManager.default.createSymbolicLink(at: planted, withDestinationURL: target)
    defer {
      try? FileManager.default.removeItem(at: planted)
      try? FileManager.default.removeItem(at: target)
    }

    let written = try Helper.writeScreenshot(Data([1, 2, 3]), to: nil, at: date)
    defer { try? FileManager.default.removeItem(at: written) }

    #expect(try Data(contentsOf: target) == Data([9]))
    #expect(written != planted)
    #expect(try Data(contentsOf: written) == Data([1, 2, 3]))
  }
}
