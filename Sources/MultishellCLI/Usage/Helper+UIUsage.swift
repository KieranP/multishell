extension Helper {
  static let uiUsage = """
    usage: multishell ui show board|all-terminals|settings
    usage: multishell ui show project-settings [PROJECT_ID]
        Open what the menu item or click opens: the Agents board, its Show
        all terminals, the Settings window, or a project's settings.
    usage: multishell ui show services [WORKTREE_ID]
        Open the worktree's pull request and CI popover, the one in view's
        by default, as a click on its row's glyphs does. Refused where the
        row shows neither.
    usage: multishell ui hide board|all-terminals|settings|project-settings|services
    usage: multishell ui filter [TEXT]
        Filter the sidebar as typing in its field does; no TEXT clears it.
    usage: multishell ui dismiss
        Cancel the alert, dialog, sheet, quick switcher or name field on
        top, and print what went as JSON. `multishell info` lists what is up.
    usage: multishell ui menu
        List every item of the menu bar as JSON, by its titles from the bar
        down, enabled, ticked and with its keys as the menu would draw it
        now. Items macOS adds as a menu opens, such as View > Enter Full
        Screen, are left out until someone has opened it; `window
        full-screen` is that one.
    usage: multishell ui menu "TITLE > TITLE..."
    usage: multishell ui menu TITLE TITLE...
        Choose the item, as a click on it: `ui menu "View > Enable Debug
        Tools"`, or each title a word. Refused where it is greyed out.
    usage: multishell ui switcher [TEXT] [--scope SCOPE] [--next | --previous]
                                [--choose]
        Open the quick switcher where it is shut, then, in this order, turn
        it to SCOPE (all, agents, worktrees, tabs, files or commands), type
        TEXT into its field, press an arrow, and press Return on the row
        selected. Prints its sections and rows as JSON, the selected one
        marked, or nothing once a row is chosen. `ui dismiss` closes it.

    """
}
