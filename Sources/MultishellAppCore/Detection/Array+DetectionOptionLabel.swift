extension [DetectionOption] {
  /// The words a menu of these options gives `id`; `nil` where none is it.
  public func label(of id: String) -> String? {
    first { $0.id == id && $0.id != DetectionOption.dividerID }?.label
  }
}
