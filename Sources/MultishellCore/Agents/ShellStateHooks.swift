import Foundation

/// The command-status hooks a shell runs so the dots follow every command,
/// and the generated startup files that carry them into this app's terminals.
///
/// A `preexec`/`precmd` pair calls the helper's `command-started` and
/// `command-finished --exit $?`; the helper maps the code. Injected per
/// session, silently: zsh through a `ZDOTDIR` that chains to the user's own
/// files, bash through `--init-file`. Nothing is written to a file the user
/// owns, and the hooks do nothing outside a Multishell terminal
/// (`MULTISHELL_SESSION` unset) or when the helper is missing.
public enum ShellStateHooks {
  /// zsh writes to the socket itself through `zsocket`, so a command line
  /// costs two socket writes and no process; the helper is only the fallback
  /// for a zsh built without `zsh/net/socket`. A connect that fails means the
  /// app is not running, and then nothing else is tried.
  private static func zshBody(helper: String) -> String {
    """
    if [ -n "$MULTISHELL_SESSION" ] && [ -n "$MULTISHELL_SOCKET" ]; then
      typeset -g _multishell_bin="\(helper)"
      typeset -g _multishell_ran=0
      typeset -g _multishell_started=0
      zmodload zsh/net/socket 2>/dev/null
      zmodload zsh/datetime 2>/dev/null
      # $1 is the JSON line; the rest is the helper's argv for the fallback.
      _multishell_send() {
        local line="$1"; shift
        if (( ${+builtins[zsocket]} )); then
          local fd
          zsocket "$MULTISHELL_SOCKET" 2>/dev/null || return 0
          fd=$REPLY
          print -r -u $fd -- "$line"
          exec {fd}>&-
        elif [ -x "$_multishell_bin" ]; then
          "$_multishell_bin" "$@" >/dev/null 2>&1
        fi
      }
      _multishell_json() {
        local cwd="${MULTISHELL_WORKTREE//\\\\/\\\\\\\\}"
        cwd="${cwd//\\"/\\\\\\"}"
        print -r -- "{\\"v\\":1,\\"state\\":\\"$1\\",\\"session\\":\\"$MULTISHELL_SESSION\\",\\"cwd\\":\\"$cwd\\"$2}"
      }
      # Both reports run inline: a fast command's finished must not overtake
      # its started, and a fast close must not skip either.
      _multishell_preexec() {
        _multishell_ran=1
        _multishell_started=${EPOCHREALTIME:-$SECONDS}
        _multishell_send "$(_multishell_json running ",\\"pid\\":$$")" command-started --pid $$
      }
      _multishell_precmd() {
        local e=$?
        [ "$_multishell_ran" = 1 ] || return
        _multishell_ran=0
        local d state
        printf -v d '%.3f' $(( ${EPOCHREALTIME:-$SECONDS} - _multishell_started ))
        if [ "$e" -eq 0 ] || [ "$e" -gt 128 ]; then state=done; else state=error; fi
        _multishell_send "$(_multishell_json $state ",\\"duration\\":$d")" command-finished --exit "$e" --duration "$d"
      }
      # `exit` runs preexec but never the next precmd, so clear on the way out.
      _multishell_zshexit() { _multishell_send "$(_multishell_json idle "")" state idle; }
      autoload -Uz add-zsh-hook 2>/dev/null
      add-zsh-hook preexec _multishell_preexec
      add-zsh-hook precmd _multishell_precmd
      add-zsh-hook zshexit _multishell_zshexit
    fi
    """
  }

  /// bash has no preexec, so a DEBUG trap stands in. It fires before every
  /// simple command, including the pieces of PROMPT_COMMAND, so it is gated
  /// by a flag that is armed as the last PROMPT_COMMAND step and cleared by
  /// the first command after it: one "started" per command line, none for
  /// the prompt's own work, the way bash-preexec does it.
  private static func bashBody(helper: String) -> String {
    """
    if [ -n "$MULTISHELL_SESSION" ] && [ -x "\(helper)" ]; then
      _multishell_bin="\(helper)"
      _multishell_ran=0
      _multishell_armed=0
      _multishell_started=0
      # Inline, not in the background, for the same reasons as the zsh body.
      _multishell_command_started() {
        _multishell_ran=1
        _multishell_started=${EPOCHREALTIME:-$SECONDS}
        "$_multishell_bin" command-started --pid $$ >/dev/null 2>&1
      }
      _multishell_debug() {
        [ "$_multishell_armed" = 1 ] || return 0
        [ -n "${COMP_LINE-}" ] && return 0
        _multishell_armed=0
        case "$BASH_COMMAND" in _multishell_*) return 0 ;; esac
        _multishell_command_started
      }
      _multishell_precmd() {
        local e=$?
        if [ "$_multishell_ran" = 1 ]; then
          _multishell_ran=0
          # bash 3.2 has no EPOCHREALTIME; SECONDS is whole seconds, enough.
          local now=${EPOCHREALTIME:-$SECONDS}
          local d=$(( ${now%.*} - ${_multishell_started%.*} ))
          "$_multishell_bin" command-finished --exit "$e" --duration "$d" >/dev/null 2>&1
        fi
      }
      _multishell_arm() { _multishell_armed=1; }
      trap '_multishell_debug' DEBUG
      case "${PROMPT_COMMAND-}" in
        *_multishell_precmd*) ;;
        *)
          if [[ "$(declare -p PROMPT_COMMAND 2>/dev/null)" == "declare -a"* ]]; then
            PROMPT_COMMAND=(_multishell_precmd "${PROMPT_COMMAND[@]}" _multishell_arm)
          else
            PROMPT_COMMAND="_multishell_precmd${PROMPT_COMMAND:+; $PROMPT_COMMAND}; _multishell_arm"
          fi ;;
      esac
    fi
    """
  }

  // MARK: - Per-session injection (zsh)

  /// The zsh startup files to place in a directory this app sets as a
  /// session's `ZDOTDIR`. Each chains to the user's own file first, so their
  /// config loads unchanged, then `.zshrc` adds the command-status hooks and
  /// hands `ZDOTDIR` back so nested shells are untouched. This is how the
  /// hooks reach a terminal without editing any file the user owns.
  public static func zshIntegrationFiles(
    helper: String = ClaudeCodeHooks.helperReference
  )
    -> [String: String]
  {
    [
      ".zshenv": zshChain(
        userFile: ".zshenv", restoreToSelf: true, capturesUserZdotdir: true, appending: nil),
      ".zprofile": zshChain(userFile: ".zprofile", restoreToSelf: true, appending: nil),
      ".zshrc": zshChain(
        userFile: ".zshrc", restoreToSelf: false, appending: zshBody(helper: helper)),
    ]
  }

  /// Sources the user's `file`, with `ZDOTDIR` pointed at the user's own
  /// directory while it runs. `restoreToSelf` keeps our directory in force
  /// for the next startup file; the last one instead hands `ZDOTDIR` back to
  /// the user so a nested shell does not re-enter this chain.
  /// `capturesUserZdotdir`: the user's `.zshenv` may itself relocate
  /// `ZDOTDIR`; the directory it leaves is where their `.zprofile` and
  /// `.zshrc` live, so it is recorded for the later files to chain to.
  private static func zshChain(
    userFile: String, restoreToSelf: Bool, capturesUserZdotdir: Bool = false,
    appending extra: String?
  ) -> String {
    let header = """
      # Multishell zsh integration, for this app's terminals only. It chains
      # to your own zsh startup files, so nothing here is written to your
      # ~/.zshrc; it runs solely because Multishell set ZDOTDIR for this
      # session.
      _multishell_self_zdotdir="$ZDOTDIR"
      if [ -n "${MULTISHELL_USER_ZDOTDIR-}" ]; then
        export ZDOTDIR="$MULTISHELL_USER_ZDOTDIR"
      else
        unset ZDOTDIR
      fi
      [ -f "${ZDOTDIR:-$HOME}/\(userFile)" ] && source "${ZDOTDIR:-$HOME}/\(userFile)"
      \(capturesUserZdotdir ? "[ -n \"${ZDOTDIR-}\" ] && export MULTISHELL_USER_ZDOTDIR=\"$ZDOTDIR\"" : "")
      """
    let footer =
      restoreToSelf
      ? """
      export ZDOTDIR="$_multishell_self_zdotdir"
      """
      : """
      # Hand ZDOTDIR back to the user so nested shells do not re-enter this.
      if [ -n "${MULTISHELL_USER_ZDOTDIR-}" ]; then
        export ZDOTDIR="$MULTISHELL_USER_ZDOTDIR"
      else
        unset ZDOTDIR
      fi
      """
    return [header, extra, footer].compactMap { $0 }.joined(separator: "\n") + "\n"
  }

  /// A bash init file to launch with `--init-file`. Interactive bash reads
  /// it instead of `~/.bashrc` and, since it is not a login shell, would skip
  /// the profile chain, so this reproduces that chain first, then the user's
  /// `.bashrc`, then adds the hooks. Nothing is written to the user's files.
  public static func bashInitFile(helper: String = ClaudeCodeHooks.helperReference) -> String {
    """
    # Multishell bash integration, for this app's terminals only. bash was
    # launched with --init-file pointing here, so reproduce a login shell's
    # startup, then add the command-status hooks.
    if [ -f /etc/profile ]; then . /etc/profile; fi
    for _multishell_profile in "$HOME/.bash_profile" "$HOME/.bash_login" "$HOME/.profile"; do
      if [ -f "$_multishell_profile" ]; then . "$_multishell_profile"; break; fi
    done
    unset _multishell_profile
    # In case the profile did not already source it.
    if [ -f "$HOME/.bashrc" ]; then . "$HOME/.bashrc"; fi

    \(bashBody(helper: helper))
    """ + "\n"
  }
}
