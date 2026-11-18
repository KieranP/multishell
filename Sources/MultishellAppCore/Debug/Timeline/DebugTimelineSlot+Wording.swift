import Foundation

extension DebugTimelineSlot {
  /// Under the charts while the pointer is over this slot: the time alone, as
  /// a timeline covers fifteen minutes at most.
  public var startedAtText: String { startedAt.formatted(date: .omitted, time: .standard) }
}
