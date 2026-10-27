import CoreGraphics

/// Where the pointer last was over the list, held by reference so writing it
/// on each move redraws nothing.
final class QuickSwitcherPointer {
  var location: CGPoint

  init(location: CGPoint) {
    self.location = location
  }
}
