import Foundation
import MultishellCore
import Testing
import UniformTypeIdentifiers

@testable import MultishellAppUI

/// Swift and the `Info.plist.in` that `Scripts/make-app.sh` fills in both spell these, and
/// every other test reads one constant for both, so a rename on one side passes them all.
@Suite
struct BundleDeclarationTests {
  @Test func theDraggedTabTypeIsDeclaredInTheBundleTheScriptWrites() throws {
    let identifier = TabTransfer.contentType.identifier
    // A Bool rather than `contains(…)` in the #expect, since swift-testing prints that
    // expression, the whole template, over the message.
    let isDeclared = try infoPlistTemplate().contains(
      "<key>UTTypeIdentifier</key><string>\(identifier)</string>")
    #expect(
      isDeclared,
      """
      Info.plist.in does not declare \(identifier) as an exported type. TabTransfer and the \
      Info.plist have to agree, or the drag type the app uses is not the one the bundle exports.
      """)
  }

  /// `log show --predicate 'subsystem == "…"'` with the bundle id finds nothing unless
  /// `MacPlatform` logs under it.
  @Test func theLoggingSubsystemIsTheBundleIdentifier() throws {
    let subsystem = MacPlatform.loggingSubsystem
    let isBundleIdentifier = try infoPlistTemplate().contains(
      "<key>CFBundleIdentifier</key><string>\(subsystem)</string>")
    #expect(
      isBundleIdentifier,
      """
      MacPlatform logs under \(subsystem), which is not the bundle identifier Info.plist.in \
      carries, so a `log show` predicate on the bundle id finds none of this app's lines.
      """)
  }

  /// A worktree's debug bundle carries its name in this key. Renamed on the Swift side alone,
  /// `Paths` falls back to the plain `.debug` files without a word.
  @Test func theWorktreeVariantKeyIsWrittenIntoTheBundleTheScriptWrites() throws {
    let isWritten = try infoPlistTemplate().contains("<key>\(Paths.variantKey)</key>")
    #expect(
      isWritten,
      """
      Info.plist.in does not carry \(Paths.variantKey), so Paths.variant finds nothing and \
      every worktree's debug build shares one state file and one socket again.
      """)
  }

  @Test func theCommitKeyTheAboutPanelReadsIsWrittenIntoTheBundle() throws {
    let isWritten = try infoPlistTemplate().contains(
      "<key>\(AboutPanel.commitKey)</key><string>@COMMIT@</string>")
    #expect(
      isWritten,
      """
      Info.plist.in does not carry \(AboutPanel.commitKey), so the About panel shows no commit \
      and a bug report cannot say which tree was installed.
      """)
  }

  /// Without this key TCC kills a pane's process that asks for the mic instead of alerting,
  /// and TCC ignores an empty string; see Docs/develop/permissions.md.
  @Test func theMicrophoneUsageStringIsDeclaredInTheBundleTheScriptWrites() throws {
    let isDeclared =
      try infoPlistTemplate().range(
        of: #"<key>NSMicrophoneUsageDescription</key>\s*<string>[^<]+</string>"#,
        options: .regularExpression) != nil
    #expect(
      isDeclared,
      """
      Info.plist.in carries no NSMicrophoneUsageDescription with words in it, so TCC kills \
      anything that asks for the microphone in a terminal instead of showing the alert, and \
      Multishell never appears under Microphone in Privacy & Security.
      """)
  }

  /// From the checkout, since the package these tests run in has no `Info.plist`
  /// and the script's source is what is under test.
  private func infoPlistTemplate() throws -> String {
    let checkout = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()  // App
      .deletingLastPathComponent()  // MultishellAppUITests
      .deletingLastPathComponent()  // Tests
      .deletingLastPathComponent()
    let template = checkout.appendingPathComponent("Resources/Info.plist.in")
    guard FileManager.default.fileExists(atPath: template.path) else {
      throw TemplateNotFound(path: template.path)
    }
    return try String(contentsOf: template, encoding: .utf8)
  }
}

/// Thrown rather than returning empty, so a different checkout layout fails naming where it
/// looked instead of passing on an empty string.
private struct TemplateNotFound: Error, CustomStringConvertible {
  let path: String
  var description: String { "Info.plist.in not found at \(path)" }
}
