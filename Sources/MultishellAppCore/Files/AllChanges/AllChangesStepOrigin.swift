/// Where the All changes tab's next step counts from: the boxed change while it
/// is in the clip, else the clip's top, as a file tab counts from its caret in view.
public struct AllChangesStepOrigin: Equatable, Sendable {
  let top: Double
  let isBoxed: Bool

  init(top: Double, isBoxed: Bool) {
    self.top = top
    self.isBoxed = isBoxed
  }

  public init(boxedTop: Double?, clipTop: Double, clipHeight: Double) {
    let clip = clipTop..<(clipTop + clipHeight)
    if let boxedTop, clip.contains(boxedTop) {
      self.init(top: boxedTop, isBoxed: true)
    } else {
      self.init(top: clipTop, isBoxed: false)
    }
  }
}
