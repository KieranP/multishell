extension Helper {
  static let configUsage = """
    usage: multishell config global list
    usage: multishell config global get KEY
    usage: multishell config global set KEY VALUE
        Read or change a setting, through what the Settings window does.
        Keys are the state file's: autoStartAgent, defaultShell, themeID,
        notifications.done, agentFlags.claude and the rest, which list
        prints. An empty VALUE clears a setting that may be empty.
        defaultShell takes a shell's full path, login or custom.
    usage: multishell config project PROJECT_ID list
    usage: multishell config project PROJECT_ID get KEY
    usage: multishell config project PROJECT_ID set KEY VALUE
        The same for a project's own settings. VALUE null hands a key back
        to the global; a key that takes text keeps VALUE as typed, quotes and
        all, and any other reads it as JSON, so `true` and `12` mean what
        they say. The shared-settings trust answers are the app's own
        question to ask.

    """
}
