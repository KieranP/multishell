/// What `multishell ui switcher` asks of the quick switcher, opening it first
/// where it is shut.
public struct QuickSwitcherOrder: Codable, Equatable, Sendable {
  /// The scope bar's word, as `ui switcher --scope` takes it; `nil` keeps the one up.
  public let scope: String?
  /// As typed into its field; `nil` keeps what is there.
  public let text: String?
  /// An arrow key, after the text.
  public let step: CycleDirection?
  /// Return on the row selected, last.
  public let choosesSelected: Bool

  public init(scope: String?, text: String?, step: CycleDirection?, choosesSelected: Bool) {
    self.scope = scope
    self.text = text
    self.step = step
    self.choosesSelected = choosesSelected
  }
}
