extension Helper {
  static let windowUsage = """
    usage: multishell window size WIDTH HEIGHT
        Size the main window in points, its top edge kept.
    usage: multishell window full-screen on|off
        Put the main window into full screen or take it out, as View >
        Enter Full Screen does; `info` says which it is once it lands.
    usage: multishell window sidebar-width WIDTH
    usage: multishell window panel-width WIDTH
        Set the sidebar's or the Files panel's width in points, as dragging
        its edge does; a window too narrow for it draws it narrower. A debug
        build keeps these apart from the installed app's.

    """
}
