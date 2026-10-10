import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// The generated startup files on disk, where a tab's `ZDOTDIR`, bash's
/// `--init-file` and fish's `-C` point.
@Suite
struct ShellIntegrationTests {
  @Test func refreshWritesEveryFileAndRewritesAStaleOne() throws {
    let root = try Scratch.directory("integration")
    defer { Scratch.remove(root) }
    let zsh = root.appendingPathComponent("zsh", isDirectory: true)
    let bashInit = root.appendingPathComponent("bash/init.bash")
    let fishInit = root.appendingPathComponent("fish/init.fish")

    for helper in ["/old/multishell", "/new/multishell"] {
      try ShellIntegration.refresh(
        zshDirectory: zsh,
        bashInit: bashInit,
        fishInit: fishInit,
        helper: helper,
      )
    }

    let written = try FileManager.default.contentsOfDirectory(atPath: zsh.path)
    #expect(Set(written) == [".zshenv", ".zprofile", ".zshrc"])
    let zshrc = try String(contentsOf: zsh.appendingPathComponent(".zshrc"), encoding: .utf8)
    #expect(
      zshrc == ShellIntegrationScripts.forZsh(helper: "/new/multishell")[".zshrc"]
    )
    #expect(!zshrc.contains("/old/multishell"), "a moved bundle's path is replaced, not kept")
    let bash = try String(contentsOf: bashInit, encoding: .utf8)
    #expect(bash == ShellIntegrationScripts.forBash(helper: "/new/multishell"))
    let fish = try String(contentsOf: fishInit, encoding: .utf8)
    #expect(fish == ShellIntegrationScripts.forFish(helper: "/new/multishell"))
  }
}
