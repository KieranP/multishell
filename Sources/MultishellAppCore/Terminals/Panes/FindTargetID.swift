import Foundation

/// What a find bar searches: a pane, by its session's id, or a file tab, by
/// its own. The two draw from one space of ids, so one key serves both.
public typealias FindTargetID = UUID
