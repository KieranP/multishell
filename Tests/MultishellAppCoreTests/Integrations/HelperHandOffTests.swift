import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite
struct HelperHandOffTests {
  @Test func aCommandTypedAtThePaneThatFoundTheAppGoesToTheHelper() {
    #expect(HelperHandOff.helperArguments(from: ["/A/Multishell", "help"]) == ["help"])
    #expect(HelperHandOff.helperArguments(from: ["/A/Multishell", "--help"]) == ["--help"])
    #expect(HelperHandOff.helperArguments(from: ["/A/Multishell", "-h"]) == ["-h"])
    #expect(
      HelperHandOff.helperArguments(from: ["/A/Multishell", "tabs", "open", "w-0123abcd"])
        == ["tabs", "open", "w-0123abcd"]
    )
  }

  @Test func aLaunchWithNoArgumentsOrAppKitsOwnStartsTheApp() {
    #expect(HelperHandOff.helperArguments(from: ["/A/Multishell"]) == nil)
    #expect(HelperHandOff.helperArguments(from: ["/A/Multishell", "-psn_0_12345"]) == nil)
    #expect(
      HelperHandOff.helperArguments(from: ["/A/Multishell", "-NSDocumentRevisionsDebugMode", "YES"])
        == nil
    )
    #expect(
      HelperHandOff.helperArguments(from: ["/A/Multishell", "-AppleLanguages", "(de)"]) == nil
    )
  }

  @Test func theHelperIsFoundInTheBundleALinkToTheExecutableLeadsTo() throws {
    let root = Scratch.path("handoff")
    defer { Scratch.remove(root) }
    let bundle = try linkedBundle(in: root)

    let found = HelperHandOff.helper(inBundleOf: bundle.link)

    #expect(found?.resolvingSymlinksInPath() == bundle.helper.resolvingSymlinksInPath())
    #expect(HelperHandOff.helper(inBundleOf: root.appendingPathComponent("bin/other")) == nil)
  }

  @Test func aLaunchThroughALinkPutsTheBundlesOwnDirectoriesOnAPanesPath() throws {
    let root = Scratch.path("handoff")
    defer { Scratch.remove(root) }
    let bundle = try linkedBundle(in: root)

    let directories = try #require(HelperHandOff.bundleDirectories(of: bundle.link))

    let macOS = bundle.executable.deletingLastPathComponent().resolvingSymlinksInPath()
    #expect(directories.app.resolvingSymlinksInPath() == macOS)
    #expect(
      directories.helper.resolvingSymlinksInPath()
        == bundle.helper.deletingLastPathComponent().resolvingSymlinksInPath()
    )
  }

  private func linkedBundle(in root: URL) throws -> (executable: URL, helper: URL, link: URL) {
    let contents = root.appendingPathComponent("X.app/Contents", isDirectory: true)
    let executable = contents.appendingPathComponent("MacOS/Multishell")
    let helper = contents.appendingPathComponent("Helpers/multishell")
    let link = root.appendingPathComponent("bin/multishell")
    for file in [executable, helper] {
      try FileManager.default.createDirectory(
        at: file.deletingLastPathComponent(),
        withIntermediateDirectories: true,
      )
      try Data().write(to: file)
      try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
    }
    try FileManager.default.createDirectory(
      at: link.deletingLastPathComponent(),
      withIntermediateDirectories: true,
    )
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: executable)
    return (executable, helper, link)
  }
}
