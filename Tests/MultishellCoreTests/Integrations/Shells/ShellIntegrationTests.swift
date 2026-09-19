import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// The generated startup files on disk, where a tab's `ZDOTDIR` and bash's
/// `--init-file` point.
@Suite
struct ShellIntegrationTests {
  private func scratch() throws -> URL {
    let url = try Scratch.directory("integration")
    return url
  }

  @Test func refreshWritesEveryFileAndRewritesAStaleOne() throws {
    let root = try scratch()
    defer { try? FileManager.default.removeItem(at: root) }
    let zsh = root.appendingPathComponent("zsh", isDirectory: true)
    let bashInit = root.appendingPathComponent("bash/init.bash")

    try ShellIntegration.refresh(zshDirectory: zsh, bashInit: bashInit, helper: "/old/multishell")
    try ShellIntegration.refresh(zshDirectory: zsh, bashInit: bashInit, helper: "/new/multishell")

    let written = try FileManager.default.contentsOfDirectory(atPath: zsh.path)
    #expect(Set(written) == [".zshenv", ".zprofile", ".zshrc"])
    let zshrc = try String(contentsOf: zsh.appendingPathComponent(".zshrc"), encoding: .utf8)
    #expect(zshrc == ShellStateHooks.zshIntegrationFiles(helper: "/new/multishell")[".zshrc"])
    #expect(!zshrc.contains("/old/multishell"), "a moved bundle's path is replaced, not kept")
    let bash = try String(contentsOf: bashInit, encoding: .utf8)
    #expect(bash == ShellStateHooks.bashInitFile(helper: "/new/multishell"))
  }
}
