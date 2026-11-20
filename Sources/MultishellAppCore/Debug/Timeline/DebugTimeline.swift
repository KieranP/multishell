import MultishellProcess

/// What the panel's charts draw for one range: a slot per point, oldest first,
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
    // By the frame's length, not a sample each: a freeze holds the sampler too, so ten
    // seconds frozen land in one sample, or in the next one-second sample after it.
    let stalledSeconds = history.samples(in: range).reduce(0) { count, sample in
      guard sample.smoothness == .stalled, let frame = sample.frameRate?.longestFrame else {
        return count
      }
      return count + max(1, Int(frame.inSeconds.rounded(.up)))
    }
    // A freeze begun before the range counts only the range's own seconds.
    stalledSecondCount = min(stalledSeconds, range.sampleCount)
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

  /// What a tile's label reads: the slot under the pointer, or the latest
  /// where the pointer is off the charts or over a second with no sample.
  public func shownSlot(hovering index: Int?) -> DebugTimelineSlot? {
    slot(at: index) ?? latestSlot
  }

  /// `nil` past the range: a pointer index kept from a longer one.
  public func slot(at index: Int?) -> DebugTimelineSlot? {
    guard let index, slots.indices.contains(index) else { return nil }
    return slots[index]
  }

  /// The slot under a point `fraction` of the way across a chart.
  func slotIndex(atFraction fraction: Double) -> Int {
    let index = Int((fraction * Double(slots.count)).rounded(.down))
    return min(max(index, 0), slots.count - 1)
  }

  /// The slot under a pointer `x` points across a chart, `nil` past either end.
  public func slotIndex(atX x: Double, chartWidth: Double) -> Int? {
    guard chartWidth > 0, x >= 0, x <= chartWidth else { return nil }
    return slotIndex(atFraction: x / chartWidth)
  }

  /// Where the middle of slot `index` sits across a chart `chartWidth` wide:
  /// `slotIndex(atX:chartWidth:)` turned round.
  public func slotMidpointX(_ index: Int, chartWidth: Double) -> Double {
    (Double(index) + 0.5) * chartWidth / Double(max(slots.count, 1))
  }

  /// Each slot's bands stacked, the scale set by the tallest stack.
  public func points(of metric: DebugMetric) -> [DebugChartPoint?] {
    let stacks = slots.map { slot in
      slot.flatMap(metric.values(of:)).map { values in
        values.reduce(into: [Double]()) { tops, value in tops.append((tops.last ?? 0) + value) }
      }
    }
    let scale = metric.scale(forPeak: stacks.compactMap { $0?.last }.max() ?? 0)
    return stacks.map { stack in
      stack.map { tops in DebugChartPoint(tops: tops.map { min($0 / scale, 1) }) }
    }
  }
}
