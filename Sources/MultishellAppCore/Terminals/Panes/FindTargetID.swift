import Foundation

/// What a find bar searches: a pane, by its session's id, or a file or All changes tab,
/// by its own. All draw from one space of ids, so one key serves each.
public typealias FindTargetID = UUID
