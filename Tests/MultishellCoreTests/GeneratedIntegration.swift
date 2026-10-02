import Foundation
import TestScratch

@testable import MultishellCore

/// The integration files as the app writes them, beside a home with no startup
/// file, so a shell run against them reads nothing this machine has.
struct GeneratedIntegration {
  let root: URL
  let home: URL
  let zshDirectory: URL
  let bashInit: URL

  init(helper: String) throws {
    root = Scratch.path("marks")
    home = root.appendingPathComponent("home", isDirectory: true)
    zshDirectory = root.appendingPathComponent("zsh", isDirectory: true)
    bashInit = root.appendingPathComponent("bash/init.bash")
    try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    try ShellIntegration.refresh(zshDirectory: zshDirectory, bashInit: bashInit, helper: helper)
  }

  func tearDown() {
    Scratch.remove(root)
  }

  /// Where a stand-in for the engine's resources goes; the bootstrap is at
  /// `shell-integration/zsh` below it, as libghostty's is.
  var engineResources: URL { root.appendingPathComponent("resources", isDirectory: true) }

  /// libghostty's bootstrap contract: restore `ZDOTDIR` from `GHOSTTY_ZSH_ZDOTDIR`, source
  /// its `.zshenv`, and from a precmd deferred past `.zshrc` write the prompt start and mark.
  func writeEngineBootstrap() throws -> URL {
    let bootstrap = engineResources.appendingPathComponent(
      "shell-integration/zsh", isDirectory: true)
    try FileManager.default.createDirectory(at: bootstrap, withIntermediateDirectories: true)
    let contents = """
      if [[ -n "${GHOSTTY_ZSH_ZDOTDIR+set}" ]]; then
        ZDOTDIR="$GHOSTTY_ZSH_ZDOTDIR"; unset GHOSTTY_ZSH_ZDOTDIR
      else
        unset ZDOTDIR
      fi
      [[ -r "${ZDOTDIR:-$HOME}/.zshenv" ]] && builtin source -- "${ZDOTDIR:-$HOME}/.zshenv"
      if [[ -o interactive ]]; then
        _engine_precmd() {
          print -n -- $'\\e]133;A\\a'
          [[ "$PS1" == *$'\\e]133;B\\a%}' ]] || PS1="$PS1"$'%{\\e]133;B\\a%}'
        }
        _engine_defer() {
          precmd_functions=(${precmd_functions:#_engine_defer})
          autoload -Uz add-zsh-hook
          add-zsh-hook precmd _engine_precmd
          _engine_precmd
        }
        typeset -ga precmd_functions
        precmd_functions+=(_engine_defer)
      fi

      """
    try Data(contents.utf8).write(to: bootstrap.appendingPathComponent(".zshenv"), options: .atomic)
    return bootstrap
  }

  func writeHomeFile(_ name: String, _ contents: String) throws {
    try Data(contents.utf8).write(to: home.appendingPathComponent(name), options: .atomic)
  }

  func environment(termProgram: String?) -> [String: String] {
    var environment = ["HOME": home.path, "PATH": "/usr/bin:/bin", "TERM": "dumb"]
    environment["TERM_PROGRAM"] = termProgram
    return environment
  }
}
