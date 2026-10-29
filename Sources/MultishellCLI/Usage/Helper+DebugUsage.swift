import MultishellProcess

extension Helper {
  static let debugUsage = """
    usage: multishell debug tools on|off
        Turn View > Enable Debug Tools on or off. Off drops every sample.
    usage: multishell debug info show|hide
        Show Debug Info over the panes, or put the panes back.
    usage: multishell debug samples [--last N]
        Print the newest N samples, 1 by default, oldest first, as JSON:
        durations in milliseconds, memory in bytes.
    usage: multishell debug samples --follow [--last N] [--count N]
        Print each sample as it lands, one JSON object a line, after the
        last N; stop after --count of them, or at an interrupt.
    usage: multishell debug samples --summary [--last N]
        Sum up the newest N samples, 60 by default: each reading's least,
        mean and most, the git runs, reports and marks in them.
    usage: multishell debug memory
        Print the Memory by tab table as JSON, in bytes.
    usage: multishell debug notifications
        Print the Dock badge and the banners posted this run, oldest first,
        each with the pane it is about and whether it is still up.
    usage: multishell debug git [--last N]
        Print the newest N git runs, 20 by default, one by one: command,
        directory, milliseconds, peak memory and the sample each ended in.
    usage: multishell debug mark NAME
        Put NAME into the next sample's marks, to line an action up with
        the readings around it, and into Instruments' Points of Interest.
    usage: multishell debug report PANE_ID STATE [--agent ID] [--message TEXT]
        Report STATE for the pane as an agent's hook would, and print the
        pane as it then is: the dot, banner and board follow.
    usage: multishell debug screenshot [FILE] [--pane PANE_ID]
        Write the main window, or one pane on screen, to FILE as a PNG, or
        with no FILE to a new one under /tmp, and print its path.
    usage: multishell debug log [--since SPAN] [--follow] [--plain]
        Print the running app's own log lines from the last SPAN, 5m by
        default, or follow them as they come: one JSON object a line, or
        with --plain the log tool's compact text.

    usage: multishell debug services stand-in FILE
    usage: multishell debug services stand-in -
        Answer every pull request and CI read from FILE's JSON, or standard
        input's, in place of gh and circleci, until `debug services clear` or
        the app quits, and return once the projects in view are read through
        it. The JSON holds "pullRequests" and "ciRuns", keyed as `worktrees
        show` prints them; Docs/design/services.md gives the whole shape. A
        worktree matches as with the tools: its branch pushed to a remote
        whose URL names the pull request's headRepository. A request holds
        \(UnixSocketServer.maximumLineLength / 1024) KB, the JSON's quotes and newlines escaped.
    usage: multishell debug services clear
        Hand back to gh and circleci, and read the projects in view again.

    Debug info, samples, memory, git and the marks need the debug tools on,
    which sample once a second.

    """
}
