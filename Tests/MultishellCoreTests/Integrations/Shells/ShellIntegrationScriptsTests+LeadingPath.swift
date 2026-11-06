import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// macOS's login profiles run `path_helper`, which puts `/etc/paths` ahead of
/// the PATH a pane was given; the users' files here stand in for it.
extension ShellIntegrationScriptsTests {
  private static let lead = "/lead/helper:/lead/app"

  private func withLeadingPath(_ base: [String: String]) -> [String: String] {
    var environment = base
    environment["PATH"] = Self.lead + ":/usr/bin:/bin"
    environment[SessionEnvironment.leadingPathVariable] = Self.lead
    return environment
  }

  private func printedPath(in output: String) -> String? {
    output.split(separator: "\n").last { $0.hasPrefix("PATH=") }.map { String($0.dropFirst(5)) }
  }

  @Test func zshPutsTheAppsEntriesBackInFrontOfWhatALoginProfileAdded() async throws {
    try #require(InstalledShells.isInstalled(Self.zshPath))
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.tearDown() }
    try files.writeHomeFile(".zprofile", "export PATH=\"/opt/first:$PATH\"\n")

    let output = try await Detached.output(
      of: Self.zshPath,
      ["-l", "-i", "-c", "print -r -- \"PATH=$PATH\""],
      environment: withLeadingPath(files.zshEnvironment(termProgram: "ghostty")),
      in: files.home,
      standardError: .discarded,
    )

    let path = try #require(printedPath(in: output), "\(output)")
    #expect(path.hasPrefix(Self.lead + ":/opt/first:"), "\(path)")
    #expect(path.components(separatedBy: "/lead/helper").count == 2, "\(path)")
  }

  @Test(arguments: InstalledBashes.all)
  func bashPutsTheAppsEntriesBackInFrontOfWhatALoginProfileAdded(bash: String) async throws {
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.tearDown() }
    try files.writeHomeFile(".bash_profile", "set -u\nPATH=\"/opt/first:$PATH\"\n")

    let output = try await interactiveShellOutput(
      bash,
      arguments: ["--init-file", files.bashInit.path, "-i"],
      environment: withLeadingPath(files.environment(termProgram: "ghostty")),
      input: "printf 'PATH=%s\\n' \"$PATH\"\nexit\n",
    )

    let path = try #require(printedPath(in: output), "\(output)")
    #expect(path.hasPrefix(Self.lead + ":/opt/first:"), "\(path)")
    #expect(path.components(separatedBy: "/lead/helper").count == 2, "\(path)")
  }

  @Test(arguments: InstalledShells.fishes)
  func fishPutsTheAppsEntriesBackInFrontOfWhatItsConfigAdded(fish: String) async throws {
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.tearDown() }
    try FileManager.default.createDirectory(
      at: files.home.appendingPathComponent(".config/fish"),
      withIntermediateDirectories: true,
    )
    try files.writeHomeFile(".config/fish/config.fish", "set -gx PATH /opt/first $PATH\n")
    let launch = ShellLaunch.fishInitArguments(forShell: fish, fishInit: files.fishInit)

    let output = try await interactiveShellOutput(
      fish,
      arguments: Array(launch.dropFirst()) + ["-i"],
      environment: withLeadingPath(files.environment(termProgram: "ghostty")),
      input: "echo PATH=(string join : $PATH)\nexit\n",
    )

    let path = try #require(printedPath(in: output), "\(output)")
    #expect(path.hasPrefix(Self.lead + ":/opt/first:"), "\(path)")
    #expect(path.components(separatedBy: "/lead/helper").count == 2, "\(path)")
  }
}
