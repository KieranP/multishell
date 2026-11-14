import CoreGraphics

/// A file's height as its view last measured it, with the estimate then: a
/// new estimate means its rows moved since, and the measure no longer holds.
struct AllChangesMeasuredHeight {
  let height: CGFloat
  let estimate: CGFloat
}
