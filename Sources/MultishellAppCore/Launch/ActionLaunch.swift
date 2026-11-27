import Foundation
import MultishellCore
import MultishellProcess

/// The line an action's tab runs: its script as sh, run as a hook runs, told
/// to the app as a shell's command is, then a shell; see Docs/design/actions.md.
enum ActionLaunch {
  /// Where the action's own script travels, beside the wrapper in the hook's
  /// variable, so neither is ever written into the other.
  private static let actionScriptVariable = "MULTISHELL_ACTION_SCRIPT"
  /// The worktree's values the script was given, frozen at launch, which a
  /// plain tab's shell has none of. The port every pane has stays.
  private static let worktreeVariables = WorktreePlaceholder.allCases
    .filter { $0 != .port }.map(\.variable).joined(separator: " ")

  static func command(
    for action: ProjectAction,
    values: [WorktreePlaceholder: String],
    in directory: URL,
    hasPort: Bool,
    tabShell: String,
    loginShell: String = ShellChoice.loginShellPath(),
    helper: URL = Paths.buildHelperLink,
  ) -> [String] {
    let (shell, handOver) = TabCommand.loginShell(handingOverTo: tabShell, loginShell: loginShell)
    let script = action.scriptLine(values: values)
    let wrapper = wrapper(
      entering: directory,
      unsettingPort: !hasPort,
      helper: helper,
      handOver: handOver,
    )
    let (line, scriptEnvironment) = ShellCommand.evaluating(wrapper)
    let environment = scriptEnvironment.merging([actionScriptVariable: script.text]) { $1 }
    // The wrapper unsets the empty history file before the hand-over.
    return script.prefixing(
      [shell.executable.path] + shell.arguments + [LeadingPathStatement.line(for: shell) + line],
      adding: ShellInvocation.historyless(environment),
    )
  }

  /// sh, whichever shell set the environment. It traps Ctrl+C so the end is
  /// still told after the script is interrupted, then `exec`s the tab's shell.
  private static func wrapper(
    entering directory: URL,
    unsettingPort: Bool,
    helper: URL,
    handOver: String,
  ) -> String {
    let quote = AnyShellQuoting.quote
    let report = quote(helper.path)
    let portUnset = unsettingPort ? "unset \(WorktreePlaceholder.port.variable)\n" : ""
    return """
      _multishell_action=$\(actionScriptVariable)
      unset \(actionScriptVariable) HISTFILE
      \(report) command-started --pid $$ >/dev/null 2>&1
      printf '\\033]133;C\\007'
      _multishell_started=$(date +%s)
      if cd \(quote(directory.path)); then
        \(portUnset)trap : INT
        ( set -e; eval "$_multishell_action" )
        _multishell_status=$?
        trap - INT
      else
        _multishell_status=1
      fi
      printf '\\033]133;D;%s\\007' "$_multishell_status"
      _multishell_seconds=$(( $(date +%s) - _multishell_started ))
      \(report) command-finished --exit "$_multishell_status" \\
        --duration "$_multishell_seconds" >/dev/null 2>&1
      unset _multishell_action _multishell_status _multishell_started _multishell_seconds \
      \(worktreeVariables)
      \(handOver)
      """
  }
}
