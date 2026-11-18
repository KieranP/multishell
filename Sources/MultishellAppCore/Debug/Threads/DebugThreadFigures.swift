/// What a row of CPU Breakdown adds up, a group's or one name's threads alike.
public protocol DebugThreadFigures {
  var title: String { get }
  var threadCount: Int { get }
  var cpuTime: Duration { get }
  /// Their CPU over the range's seconds: 100 is one core busy throughout.
  var meanPercent: Double { get }
}
