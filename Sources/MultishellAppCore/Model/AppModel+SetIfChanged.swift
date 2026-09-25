extension AppModel {
  /// Writes only where the value differs: an observed write redraws every
  /// view reading it, and most of these land on a timer. `true` where it wrote.
  @discardableResult
  func setIfChanged<T: Equatable>(
    _ path: ReferenceWritableKeyPath<AppModel, T>, _ value: T
  )
    -> Bool
  {
    guard self[keyPath: path] != value else { return false }
    self[keyPath: path] = value
    return true
  }
}
