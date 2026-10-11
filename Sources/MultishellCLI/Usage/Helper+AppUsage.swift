extension Helper {
  static let appUsage = """
    usage: multishell open
        Start the app this helper came with, or bring it forward, and return
        once it answers.
    usage: multishell quit [--force]
        Quit it without the confirmation, and return once it has gone.
        Refused while an agent is working, unless --force.
    usage: multishell info
        Print the answering app's pid, state file and socket as JSON,
        whether its debug tools are on, its open windows, and every alert,
        dialog, sheet or name field up, topmost first.

    """
}
