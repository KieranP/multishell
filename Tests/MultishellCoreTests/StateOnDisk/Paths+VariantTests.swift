import Foundation
import TestScratch
import Testing

@testable import MultishellCore

@Suite
struct PathsVariantTests {
  /// A debug bundle built from a worktree gets its own state file, socket,
  /// integration directory and drops, so two worktrees can both `make run`.
  @Test func aWorktreesDebugBundleNamesItself() {
    #expect(Paths.debugVariant(named: "fix1") == ".debug-fix1")
    #expect(Paths.debugVariant(named: nil) == ".debug", "the checkout keeps the plain files")
    #expect(Paths.debugVariant(named: "") == ".debug", "make-app.sh writes the key empty")
  }

  /// `sun_path` holds 103 bytes, two spent on the `.b` the socket binds under, and this
  /// directory plus `multishell.debug-.sock` takes about 75, so the name is cut.
  @Test func aLongOrOddWorktreeNameIsCutAndSpelledSafely() {
    let longest = Paths.debugVariant(named: String(repeating: "\u{1F600}", count: 40))
    #expect(longest.hasPrefix(".debug-" + String(repeating: "-", count: 9)))
    #expect(longest.count == ".debug-".count + 14)
    #expect(longest.allSatisfy { $0 == "." || $0.isPortableNameCharacter })
    #expect(Paths.debugVariant(named: "feat.two wd").hasPrefix(".debug-feat-two-"))
    let socket =
      "/Users/averylongusername/Library/Application Support/Multishell"
      + "/multishell\(longest).sock"
    #expect(socket.utf8.count + ".b".utf8.count <= 103, "\(socket.utf8.count) bytes: \(socket)")
  }

  @Test func namesThatCutOrSpellToTheSameStartStillGetFilesOfTheirOwn() {
    let login = Paths.debugVariant(named: "feature-auth-login")
    let logout = Paths.debugVariant(named: "feature-auth-logout")

    #expect(login != logout)
    #expect(login.count == ".debug-".count + 14)
    #expect(Paths.debugVariant(named: "feat.two") != Paths.debugVariant(named: "feat-two"))
    #expect(login == ".debug-feature-a-a48e", "the same every launch, as no seeded hash is")
  }

  @Test func aStateFileSavedUnderTheCutNameFromBeforeTheHashIsCarriedOver() throws {
    let root = Scratch.path("variant")
    defer { Scratch.remove(root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let name = "feature-sidebar-filter"
    let before = root.appendingPathComponent("state.debug-feature-sideba.json")
    let now = root.appendingPathComponent("state\(Paths.debugVariant(named: name)).json")
    try Data("{\"saved\":1}".utf8).write(to: before)

    Paths.carryOverStateFileFromBeforeTheHash(named: name, in: root)

    #expect(try Data(contentsOf: now) == Data("{\"saved\":1}".utf8))
    #expect(!FileManager.default.fileExists(atPath: before.path))
  }

  @Test func aStateFileAlreadyUnderTheHashedNameIsNotReplaced() throws {
    let root = Scratch.path("variant")
    defer { Scratch.remove(root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let name = "feature-sidebar-filter"
    let before = root.appendingPathComponent("state.debug-feature-sideba.json")
    let now = root.appendingPathComponent("state\(Paths.debugVariant(named: name)).json")
    try Data("old".utf8).write(to: before)
    try Data("new".utf8).write(to: now)

    Paths.carryOverStateFileFromBeforeTheHash(named: name, in: root)

    #expect(try Data(contentsOf: now) == Data("new".utf8))
    #expect(FileManager.default.fileExists(atPath: before.path))
  }

  @Test func aHelperReachedThroughLinksReadsTheVariantOfTheBundleItIsIn() throws {
    let root = Scratch.path("variant")
    defer { Scratch.remove(root) }
    let helpers = root.appendingPathComponent("B.app/Contents/Helpers", isDirectory: true)
    try FileManager.default.createDirectory(at: helpers, withIntermediateDirectories: true)
    let plist = [Paths.variantKey: "probe"] as NSDictionary
    try plist.write(to: root.appendingPathComponent("B.app/Contents/Info.plist"))
    let helper = helpers.appendingPathComponent("multishell")
    try Data().write(to: helper)
    let link = root.appendingPathComponent("bin/multishell")
    try FileManager.default.createDirectory(
      at: link.deletingLastPathComponent(),
      withIntermediateDirectories: true,
    )
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: helper)

    #expect(Paths.variantName(ofBundleHolding: helper) == "probe")
    #expect(Paths.variantName(ofBundleHolding: link) == "probe", "as /usr/local/bin reaches it")
  }
}
