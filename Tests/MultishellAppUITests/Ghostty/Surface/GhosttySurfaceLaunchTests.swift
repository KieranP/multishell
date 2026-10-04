import AppKit
import GhosttyKit
import Testing

@testable import MultishellAppUI

@Suite
@MainActor
struct GhosttySurfaceLaunchTests {
  private func decodedConfig(
    _ launch: GhosttySurfaceLaunch
  ) -> (
    directory: String?, command: String?, environment: [String: String], handsOverTheView: Bool
  ) {
    let view = NSView()
    return launch.withCConfig(view: view, scale: 2) { config in
      let variables = UnsafeBufferPointer(start: config.env_vars, count: config.env_var_count)
      let environment = Dictionary(
        uniqueKeysWithValues: variables.map { (String(cString: $0.key), String(cString: $0.value)) }
      )
      return (
        config.working_directory.map { String(cString: $0) },
        config.command.map { String(cString: $0) }, environment,
        config.platform.macos.nsview == Unmanaged.passUnretained(view).toOpaque()
          && config.userdata == Unmanaged.passUnretained(view).toOpaque()
      )
    }
  }

  @Test func theShellStartsWhereTheSessionIsWithItsVariables() {
    let launch = GhosttySurfaceLaunch(
      workingDirectory: "/w", environment: ["A": "1", "B": "2"], command: "exec zsh -l")
    let seen = decodedConfig(launch)
    #expect(seen.directory == "/w")
    #expect(seen.command == "exec zsh -l")
    #expect(seen.environment == ["A": "1", "B": "2"])
  }

  @Test func libghosttyDrawsIntoTheViewAndCallsBackWithIt() {
    let launch = GhosttySurfaceLaunch(workingDirectory: "/w", environment: [:], command: nil)
    #expect(decodedConfig(launch).handsOverTheView)
  }

  @Test func noCommandLeavesLibghosttyToStartTheLoginShell() {
    let seen = decodedConfig(
      GhosttySurfaceLaunch(workingDirectory: "/w", environment: [:], command: nil))
    #expect(seen.command == nil)
    #expect(seen.environment.isEmpty)
  }
}
