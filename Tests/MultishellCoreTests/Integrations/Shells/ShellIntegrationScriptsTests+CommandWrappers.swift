import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// `sudo` and `ssh` wrapped as the user's `shell-integration-features` ask, in
/// zsh and in macOS's bash 3.2 and a current one.
extension ShellIntegrationScriptsTests {
  /// Stand-ins on PATH that print the name they ran as, TERM and their arguments.
  private static let recordingCommands = """
    mkdir -p ~/bin
    for name in sudo ssh; do
      printf '#!/bin/sh\\necho "${0##*/} TERM=$TERM $*"\\n' > ~/bin/$name
      chmod +x ~/bin/$name
    done
    PATH=~/bin:$PATH
    export TERMINFO=/bundle/terminfo

    """

  @Test func zshSudoCarriesTheBundledTerminfoWhereTheUsersFeaturesAsk() async throws {
    let output = try await zshOutput(
      features: "sudo",
      input: "sudo vim\nexit\n",
      usersRC: Self.recordingCommands,
    )
    #expect(
      output.contains("sudo TERM=") && output.contains(" --preserve-env=TERMINFO vim"),
      "\(output)",
    )
  }

  @Test func zshWrappersWorkUnderAUsersStrictestOptions() async throws {
    let output = try await zshOutput(
      features: "sudo,ssh-env",
      input: "sudo vim\nssh host\nexit\n",
      usersRC: Self.recordingCommands + "\nsetopt err_exit no_unset ksh_arrays",
    )
    #expect(output.contains("--preserve-env=TERMINFO vim"), "\(output)")
    #expect(output.contains("SendEnv TERM_PROGRAM TERM_PROGRAM_VERSION host"), "\(output)")
  }

  @Test func zshSudoeditIsPassedOnAsTyped() async throws {
    let output = try await zshOutput(
      features: "sudo",
      input: "sudo -u root -e notes\nexit\n",
      usersRC: Self.recordingCommands,
    )
    #expect(output.contains(" -u root -e notes"), "\(output)")
    #expect(!output.contains("--preserve-env"))
  }

  @Test func zshSudoIsLeftAloneWhereTheUsersFeaturesLeaveItOut() async throws {
    let output = try await zshOutput(
      features: "title",
      input: "sudo vim\nexit\n",
      usersRC: Self.recordingCommands,
    )
    #expect(output.contains("sudo TERM=dumb vim"), "\(output)")
  }

  @Test func zshKeepsAUsersOwnSudoFunction() async throws {
    let output = try await zshOutput(
      features: "sudo",
      input: "sudo vim\nexit\n",
      usersRC: Self.recordingCommands + "\nfunction sudo { echo users-own-sudo }",
    )
    #expect(output.contains("users-own-sudo"), "\(output)")
  }

  @Test func zshSshEnvSendsATermEveryHostKnowsAndTheTerminalsColourAndName() async throws {
    let output = try await zshOutput(
      features: "ssh-env",
      input: "ssh host\nexit\n",
      usersRC: Self.recordingCommands,
    )
    #expect(
      output.contains(
        "ssh TERM=xterm-256color -o SetEnv COLORTERM=truecolor"
          + " -o SendEnv TERM_PROGRAM TERM_PROGRAM_VERSION host"
      ),
      "\(output)",
    )
  }

  @Test func zshSshTerminfoSendsATermEveryHostKnows() async throws {
    let output = try await zshOutput(
      features: "ssh-terminfo",
      input: "ssh host\nexit\n",
      usersRC: Self.recordingCommands,
    )
    #expect(output.contains("ssh TERM=xterm-256color host"), "\(output)")
  }

  @Test func zshSshIsLeftAloneWhereTheUsersFeaturesLeaveItOut() async throws {
    let output = try await zshOutput(
      features: "sudo",
      input: "ssh host\nexit\n",
      usersRC: Self.recordingCommands,
    )
    #expect(output.contains("ssh TERM=dumb host"), "\(output)")
  }

  @Test func zshSudoKeepsTheTerminfoForACommandWithAnEOptionOfItsOwn() async throws {
    let output = try await zshOutput(
      features: "sudo",
      input: "sudo less -e log\nexit\n",
      usersRC: Self.recordingCommands,
    )
    #expect(output.contains("--preserve-env=TERMINFO less -e log"), "\(output)")
  }

  @Test(arguments: InstalledBashes.all)
  func bashSudoCarriesTheBundledTerminfoWhereTheUsersFeaturesAsk(bash: String) async throws {
    let output = try await bashOutput(
      bash,
      features: "sudo",
      input: "sudo vim\nexit\n",
      usersRC: Self.recordingCommands,
    )
    #expect(
      output.contains("sudo TERM=") && output.contains(" --preserve-env=TERMINFO vim"),
      "\(output)",
    )
  }

  @Test(arguments: InstalledBashes.all)
  func bashWrappersWorkUnderNounset(bash: String) async throws {
    let output = try await bashOutput(
      bash,
      features: "sudo,ssh-terminfo",
      input: "sudo vim\nssh host\nexit\n",
      usersRC: Self.recordingCommands + "set -u\n",
    )
    #expect(output.contains("--preserve-env=TERMINFO vim"), "\(output)")
    #expect(output.contains("ssh TERM=xterm-256color host"), "\(output)")
  }

  @Test(arguments: InstalledBashes.all)
  func bashSudoeditIsPassedOnAsTyped(bash: String) async throws {
    let output = try await bashOutput(
      bash,
      features: "sudo",
      input: "sudo -u root -e notes\nexit\n",
      usersRC: Self.recordingCommands,
    )
    #expect(output.contains(" -u root -e notes"), "\(output)")
    #expect(!output.contains("--preserve-env"))
  }

  @Test(arguments: InstalledBashes.all)
  func bashSudoIsLeftAloneWhereTheUsersFeaturesLeaveItOut(bash: String) async throws {
    let output = try await bashOutput(
      bash,
      features: "title",
      input: "sudo vim\nexit\n",
      usersRC: Self.recordingCommands,
    )
    #expect(output.contains("sudo TERM=dumb vim"), "\(output)")
  }

  @Test(arguments: InstalledBashes.all)
  func bashKeepsAUsersOwnSudoFunction(bash: String) async throws {
    let output = try await bashOutput(
      bash,
      features: "sudo",
      input: "sudo vim\nexit\n",
      usersRC: Self.recordingCommands + "sudo() { echo users-own-sudo; }\n",
    )
    #expect(output.contains("users-own-sudo"), "\(output)")
  }

  /// `alias sudo='sudo '` is common, and an alias expands inside `sudo() {`.
  @Test(arguments: InstalledBashes.all)
  func bashWrapsSudoUnderAUsersSudoAlias(bash: String) async throws {
    let output = try await bashOutput(
      bash,
      features: "sudo",
      input: "sudo vim\nexit\n",
      usersRC: Self.recordingCommands + "alias sudo='sudo '\n",
    )
    #expect(output.contains("--preserve-env=TERMINFO vim"), "\(output)")
  }

  @Test(arguments: InstalledBashes.all)
  func bashSshEnvSendsATermEveryHostKnowsAndTheTerminalsColourAndName(bash: String) async throws {
    let output = try await bashOutput(
      bash,
      features: "ssh-env",
      input: "ssh host\nexit\n",
      usersRC: Self.recordingCommands,
    )
    #expect(
      output.contains(
        "ssh TERM=xterm-256color -o SetEnv COLORTERM=truecolor"
          + " -o SendEnv TERM_PROGRAM TERM_PROGRAM_VERSION host"
      ),
      "\(output)",
    )
  }

  @Test(arguments: InstalledBashes.all)
  func bashSshIsLeftAloneWhereTheUsersFeaturesLeaveItOut(bash: String) async throws {
    let output = try await bashOutput(
      bash,
      features: "sudo",
      input: "ssh host\nexit\n",
      usersRC: Self.recordingCommands,
    )
    #expect(output.contains("ssh TERM=dumb host"), "\(output)")
  }

  @Test(arguments: InstalledBashes.all)
  func bashSudoKeepsTheTerminfoForACommandWithAnEOptionOfItsOwn(bash: String) async throws {
    let output = try await bashOutput(
      bash,
      features: "sudo",
      input: "sudo less -e log\nexit\n",
      usersRC: Self.recordingCommands,
    )
    #expect(output.contains("--preserve-env=TERMINFO less -e log"), "\(output)")
  }
}
