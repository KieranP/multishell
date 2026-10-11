extension Helper {
  static let uiUsage = """
    usage: multishell ui show board|all-terminals|settings
    usage: multishell ui show project-settings [PROJECT_ID]
        Open what the menu item or click opens: the Agents board, its Show
        all terminals, the Settings window, or a project's settings.
    usage: multishell ui hide board|all-terminals|settings|project-settings
    usage: multishell ui filter [TEXT]
        Filter the sidebar as typing in its field does; no TEXT clears it.
    usage: multishell ui dismiss
        Cancel the alert, dialog, sheet or name field on top, and print
        what went as JSON. `multishell info` lists what is up.
    usage: multishell ui menu
        List every item of the menu bar as JSON, by its titles from the bar
        down, enabled and ticked as the menu would draw it now. Items macOS
        adds as a menu opens, such as View > Enter Full Screen, are left out
        until someone has opened it; `window full-screen` is that one.
    usage: multishell ui menu "TITLE > TITLE..."
    usage: multishell ui menu TITLE TITLE...
        Choose the item, as a click on it: `ui menu "View > Enable Debug
        Tools"`, or each title a word. Refused where it is greyed out.

    """
}
