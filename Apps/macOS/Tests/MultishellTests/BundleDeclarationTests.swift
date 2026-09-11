import Foundation
import MultishellCore
import Testing
import UniformTypeIdentifiers

@testable import Multishell

/// The identifiers this app spells twice: once in Swift, once in the
/// `Info.plist` that `Scripts/make-app.sh` writes.
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
    // The Bool first, not `script.contains(…)` inside the expectation:
    // swift-testing prints the expression it was given, and that one prints
    // the whole shell script over the message that says what is wrong.
    let isDeclared = try makeAppScript().contains(
      "<key>UTTypeIdentifier</key><string>\(identifier)</string>")
    #expect(
      isDeclared,
      """
      make-app.sh does not declare \(identifier) as an exported type. TabTransfer and the \
      Info.plist have to agree, or the drag type the app uses is not the one the bundle exports.
      """)
  }

  /// The subsystem `MacPlatform` logs under is the bundle id, so
  /// `log show --predicate 'subsystem == "…"'` finds this app's lines.
  /// docs/develop/permissions.md tells you to run exactly that.
  @Test func theLoggingSubsystemIsTheBundleIdentifier() throws {
    let subsystem = MacPlatform.loggingSubsystem
    let isBundleIdentifier = try makeAppScript().contains(
      "<key>CFBundleIdentifier</key><string>\(subsystem)</string>")
    #expect(
      isBundleIdentifier,
      """
      MacPlatform logs under \(subsystem), which is not the bundle identifier make-app.sh \
      writes, so the `log show` predicate in docs/develop/permissions.md finds none of \
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
    let isWritten = try makeAppScript().contains("<key>\(Paths.variantKey)</key>")
    #expect(
      isWritten,
      """
      make-app.sh does not write \(Paths.variantKey), so Paths.variant finds nothing and \
      every worktree's debug build shares one state file and one socket again.
      """)
  }

  /// Read from the checkout rather than the built bundle: these tests run
  /// against the package, which has no `Info.plist` of its own, and the
  /// point is to check the source the script generates it from.
  private func makeAppScript() throws -> String {
    // …/Apps/macOS/Tests/MultishellTests/<this file>
    let root = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()  // MultishellTests
      .deletingLastPathComponent()  // Tests
      .deletingLastPathComponent()  // macOS
      .deletingLastPathComponent()  // Apps
      .deletingLastPathComponent()  // the checkout
    let script = root.appendingPathComponent("Scripts/make-app.sh")
    guard FileManager.default.fileExists(atPath: script.path) else {
      throw ScriptNotFound(path: script.path)
    }
    return try String(contentsOf: script, encoding: .utf8)
  }
}

/// Thrown rather than returned empty, so a checkout laid out differently
/// fails saying where it looked instead of passing on a string with nothing
/// in it.
private struct ScriptNotFound: Error, CustomStringConvertible {
  let path: String
  var description: String { "make-app.sh not found at \(path)" }
}
