extension Helper {
  static let windowUsage = """
    usage: multishell window size WIDTH HEIGHT
        Size the main window in points, its top edge kept. Refused while it
        is minimized.
    usage: multishell window full-screen on|off
        Put the main window into full screen or take it out, as View >
        Enter Full Screen does; `info` says which it is once it lands.
        Refused while it is minimized.
    usage: multishell window sidebar-width WIDTH
    usage: multishell window panel-width WIDTH
        Set the sidebar's or the Files panel's width in points, as dragging
        its edge does. Refused past what the drag reaches, half the room the
        other side leaves, the sidebar's other side an open Files panel, and
        refused with no window open. A debug build keeps these apart from the
        installed app's.

    """
}
