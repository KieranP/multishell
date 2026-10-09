/// What the panel's strips draw for one range: a slot per point, oldest first,
/// `nil` where no sample has landed yet, so a fresh history fills from the right.
public struct DebugTimeline: Sendable, Equatable {
  public let range: DebugRange
  public let slots: [DebugTimelineSlot?]
  /// The seconds in the range whose longest frame was a stall.
  let stalledSecondCount: Int

  public var hasStalls: Bool { stalledSecondCount > 0 }

  private var latestSlot: DebugTimelineSlot? { slots.last ?? nil }

  init(history: DebugHistory, range: DebugRange) {
    self.range = range
    stalledSecondCount = history.samples(in: range).filter { $0.smoothness == .stalled }.count
    guard let newest = history.latest else {
      slots = Array(repeating: nil, count: range.slotCount)
      return
    }
    let newestSlotNumber = newest.sequence / range.secondsPerSlot
    let oldestSlotNumber = newestSlotNumber - range.slotCount + 1
    var samplesBySlotNumber: [Int: [DebugSample]] = [:]
    for sample in history.samples.reversed() {
      let slotNumber = sample.sequence / range.secondsPerSlot
      guard slotNumber >= oldestSlotNumber else { break }
      samplesBySlotNumber[slotNumber, default: []].insert(sample, at: 0)
    }
    slots = (oldestSlotNumber...newestSlotNumber).map { slotNumber in
      samplesBySlotNumber[slotNumber].map(DebugTimelineSlot.init(samples:))
    }
  }

  /// What a strip's label reads: the slot under the pointer, or the latest
  /// where the pointer is off the strip or over a second with no sample.
  public func shownSlot(hovering index: Int?) -> DebugTimelineSlot? {
    slot(at: index) ?? latestSlot
  }

  /// `nil` past the range: a pointer index kept from a longer one.
  public func slot(at index: Int?) -> DebugTimelineSlot? {
    guard let index, slots.indices.contains(index) else { return nil }
    return slots[index]
  }

  /// The slot under a point `fraction` of the way across the strip.
  func slotIndex(atFraction fraction: Double) -> Int {
    let index = Int((fraction * Double(slots.count)).rounded(.down))
    return min(max(index, 0), slots.count - 1)
  }

  /// The slot under a pointer `x` points across a row whose strip starts
  /// after `labelWidth`, `nil` over the labels or past the strip's end.
  public func slotIndex(atX x: Double, labelWidth: Double, chartWidth: Double) -> Int? {
    let intoChart = x - labelWidth
    guard chartWidth > 0, intoChart >= 0, intoChart <= chartWidth else { return nil }
    return slotIndex(atFraction: intoChart / chartWidth)
  }

  /// Where the middle of slot `index` sits across a strip `chartWidth` wide:
  /// `slotIndex(atX:labelWidth:chartWidth:)` turned round.
  public func slotMidpointX(_ index: Int, chartWidth: Double) -> Double {
    (Double(index) + 0.5) * chartWidth / Double(max(slots.count, 1))
  }

  public func points(of metric: DebugMetric) -> [DebugStripPoint?] {
    let values = slots.map { $0.flatMap(metric.values(of:)) }
    let scale = metric.scale(forPeak: values.compactMap { $0?.total }.max() ?? 0)
    return values.map { value in
      value.map { point in
        DebugStripPoint(
          app: min(point.app / scale, 1),
          appWithTerminals: min(point.appWithTerminals / scale, 1),
          total: min(point.total / scale, 1),
        )
      }
    }
  }
}
