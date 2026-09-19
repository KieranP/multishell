import Foundation
import MultishellCore
import Testing
import UniformTypeIdentifiers

@testable import Multishell

/// The identifiers this app spells twice, once in Swift and once in the
/// `Info.plist` template `Scripts/make-app.sh` fills in, and the permission
/// strings that plist alone declares.
///
/// Nothing at build time joins the two, and nothing at run time notices they
/// have parted. Every other test on either side reads the same constant on
/// both, so renaming the Swift one and leaving the script alone passes them
/// all and ships a bundle that exports a type the app never uses and uses a
/// type the bundle never declared.
@Suite
struct BundleDeclarationTests {
  /// The dragged tab's type. CLAUDE.md's rule is that it is spelled in both
  /// places; this is what catches it not being.
  @Test func theDraggedTabTypeIsDeclaredInTheBundleTheScriptWrites() throws {
    let identifier = TabTransfer.contentType.identifier
    // The Bool first, not `template.contains(…)` inside the expectation:
    // swift-testing prints the expression it was given, and that one prints
    // the whole template over the message that says what is wrong.
    let isDeclared = try infoPlistTemplate().contains(
      "<key>UTTypeIdentifier</key><string>\(identifier)</string>")
    #expect(
      isDeclared,
      """
      Info.plist.in does not declare \(identifier) as an exported type. TabTransfer and the \
      Info.plist have to agree, or the drag type the app uses is not the one the bundle exports.
      """)
  }

  /// The subsystem `MacPlatform` logs under is the bundle id, so
  /// `log show --predicate 'subsystem == "…"'` finds this app's lines.
  /// Docs/develop/permissions.md tells you to run exactly that.
  @Test func theLoggingSubsystemIsTheBundleIdentifier() throws {
    let subsystem = MacPlatform.loggingSubsystem
    let isBundleIdentifier = try infoPlistTemplate().contains(
      "<key>CFBundleIdentifier</key><string>\(subsystem)</string>")
    #expect(
      isBundleIdentifier,
      """
      MacPlatform logs under \(subsystem), which is not the bundle identifier Info.plist.in \
      carries, so the `log show` predicate in Docs/develop/permissions.md finds none of \
      this app's lines.
      """)
  }

  /// The key a debug bundle built from a worktree carries its name in, so
  /// two worktrees can both `make run` over their own state and socket.
  ///
  /// Renaming it on the Swift side alone breaks nothing loudly: `Paths`
  /// finds no key, falls back to the plain `.debug` files a checkout build
  /// wants anyway, and the two worktrees go back to sharing one state file
  /// and one socket without a word.
  @Test func theWorktreeVariantKeyIsWrittenIntoTheBundleTheScriptWrites() throws {
    let isWritten = try infoPlistTemplate().contains("<key>\(Paths.variantKey)</key>")
    #expect(
      isWritten,
      """
      Info.plist.in does not carry \(Paths.variantKey), so Paths.variant finds nothing and \
      every worktree's debug build shares one state file and one socket again.
      """)
  }

  /// A pane records through this app, so without this key TCC kills the
  /// asking process rather than showing an alert; permissions.md. The words
  /// are matched too: an empty string is a key TCC does not count.
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

  /// Read from the checkout rather than the built bundle: these tests run
  /// against the package, which has no `Info.plist` of its own, and the
  /// point is to check the source the script fills in.
  private func infoPlistTemplate() throws -> String {
    // …/Apps/macOS/Tests/MultishellTests/App/<this file>
    let macOS = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()  // App
      .deletingLastPathComponent()  // MultishellTests
      .deletingLastPathComponent()  // Tests
      .deletingLastPathComponent()  // macOS
    let template = macOS.appendingPathComponent("Resources/Info.plist.in")
    guard FileManager.default.fileExists(atPath: template.path) else {
      throw TemplateNotFound(path: template.path)
    }
    return try String(contentsOf: template, encoding: .utf8)
  }
}

/// Thrown rather than returned empty, so a checkout laid out differently
/// fails saying where it looked instead of passing on a string with nothing
/// in it.
private struct TemplateNotFound: Error, CustomStringConvertible {
  let path: String
  var description: String { "Info.plist.in not found at \(path)" }
}
