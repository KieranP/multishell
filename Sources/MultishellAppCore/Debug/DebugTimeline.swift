/// What the panel's strips draw for one range: a slot per point, oldest first,
/// `nil` where no sample has landed yet, so a fresh history fills from the right.
public struct DebugTimeline: Sendable, Equatable {
  public let range: DebugRange
  public let slots: [DebugTimelineSlot?]
  /// The seconds in the range whose longest frame was a stall.
  public let stalledSecondCount: Int

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

  public var latestSlot: DebugTimelineSlot? { slots.last ?? nil }

  /// `nil` past the range: a pointer index kept from a longer one.
  public func slot(at index: Int?) -> DebugTimelineSlot? {
    guard let index, slots.indices.contains(index) else { return nil }
    return slots[index]
  }

  /// The slot under a point `fraction` of the way across the strip.
  public func slotIndex(atFraction fraction: Double) -> Int {
    let index = Int((fraction * Double(slots.count)).rounded(.down))
    return min(max(index, 0), slots.count - 1)
  }

  public func points(of metric: DebugMetric) -> [DebugStripPoint?] {
    let values = slots.map { $0.flatMap(metric.values(of:)) }
    let scale = metric.scale(forPeak: values.compactMap { $0?.total }.max() ?? 0)
    return values.map { value in
      value.map { DebugStripPoint(app: min($0.app / scale, 1), total: min($0.total / scale, 1)) }
    }
  }
}
