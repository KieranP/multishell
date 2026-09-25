import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct ShellDetectionTests {
  @Test func shellsComeFromTheSystemListAndThePathWithoutDuplicates() throws {
    let bin = try fakeBin(["fish", "zsh", "nu", "bash"])
    defer { try? FileManager.default.removeItem(at: bin) }
    let list = bin.appendingPathComponent("shells")
    try """
    # List of acceptable shells for chpass(1).

    /bin/sh
    \(bin.appendingPathComponent("bash").path)
    \(bin.appendingPathComponent("zsh").path)
    /no/such/shell
    """.write(to: list, atomically: true, encoding: .utf8)

    let detection = ShellDetection(path: bin.path, systemList: list, loginShell: "/bin/sh")

    #expect(
      detection.installed == [
        bin.appendingPathComponent("bash").path, bin.appendingPathComponent("fish").path,
        bin.appendingPathComponent("nu").path, "/bin/sh", bin.appendingPathComponent("zsh").path,
      ], "sorted by name then path, listed once, the missing one dropped")
    #expect(detection.isInstalled("/bin/sh"))
    #expect(detection.isInstalled(ShellCatalogue.loginShellID))
    #expect(!detection.isInstalled("/opt/gone/fish"))
  }

  @Test func theDropdownLeadsWithTheLoginShellAndKeepsAStaleChoice() {
    let detection = ShellDetection(installed: ["/bin/bash", "/bin/zsh"], loginShell: "/bin/zsh")

    let plain = detection.options(selected: nil)
    #expect(plain.map(\.id) == ["login", "/bin/bash", "/bin/zsh", "custom"])
    #expect(plain[0].label == "Login shell (/bin/zsh)")
    #expect(plain[1].label == "bash  /bin/bash")
    #expect(plain.last?.label == "Custom path…")

    let stale = detection.options(selected: "/opt/homebrew/bin/fish")
    #expect(
      stale.map(\.id) == ["login", "/bin/bash", "/bin/zsh", "/opt/homebrew/bin/fish", "custom"])
    #expect(stale[3].label == "fish  /opt/homebrew/bin/fish (not installed)")
    #expect(stale[3].isInstalled == false)
    #expect(detection.options(selected: "/bin/bash").count == 4, "an installed choice adds nothing")
    #expect(detection.options(selected: "custom").count == 4, "and neither does the custom path")
    #expect(detection.isInstalled(ShellCatalogue.customID))
  }

  /// Every other row is checked against the disk. `$SHELL` pointing at an
  /// uninstalled fish showed an unmarked row, and each new tab died silently.
  @Test func aLoginShellThatIsNotThereIsMarkedLikeAnyOtherMissingOne() {
    let gone = ShellDetection(installed: ["/bin/zsh"], loginShell: "/opt/gone/fish")
    #expect(!gone.isInstalled(ShellCatalogue.loginShellID))
    #expect(gone.options(selected: nil)[0].isInstalled == false)

    let there = ShellDetection(installed: ["/bin/zsh"], loginShell: "/bin/sh")
    #expect(there.isInstalled(ShellCatalogue.loginShellID))
    #expect(there.options(selected: nil)[0].isInstalled)
  }

  @Test func aMissingSystemListIsNotAnError() {
    let detection = ShellDetection(
      path: "/nowhere", systemList: URL(fileURLWithPath: "/no/such/shells"), loginShell: "/bin/sh")
    #expect(detection.installed.isEmpty)
    #expect(detection.options(selected: nil).map(\.id) == ["login", "custom"])
  }
}
