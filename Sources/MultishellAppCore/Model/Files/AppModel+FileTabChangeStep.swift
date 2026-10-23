import MultishellCore

/// A file tab bar's arrows, stepping its view from change to change.
extension AppModel {
  /// Queued, a second click possibly landing before the view takes the first.
  public func stepToChange(_ direction: CycleDirection, in id: FileTab.ID) {
    changeStepRequests[id, default: []].append(direction)
  }

  /// The view's, as its selection or scroll moves: where the arrows can go.
  public func noteChangeSteps(_ steps: ChangeSteps, of id: FileTab.ID) {
    setIfChanged(\.fileTabChangeSteps[id], steps)
  }

  /// No step either way until the tab's view has said where it is.
  public func changeSteps(of id: FileTab.ID) -> ChangeSteps {
    fileTabChangeSteps[id] ?? .neitherWay
  }

  /// The view's, as it boxes a change or lets go of one, for the view rebuilt
  /// after a hidden tab dropped it; nothing redraws for it.
  public func noteSteppedChangeAnchor(_ anchor: ChangeAnchor?, of id: FileTab.ID) {
    fileTabSteppedChangeAnchors[id] = anchor
  }

  public func steppedChangeAnchor(of id: FileTab.ID) -> ChangeAnchor? {
    fileTabSteppedChangeAnchors[id]
  }

  /// The view's, as it updates: each step once, in the order asked. Read first,
  /// as a removal of nothing still redraws every file tab.
  public func takeChangeStepRequests(_ id: FileTab.ID) -> [CycleDirection] {
    guard changeStepRequests[id] != nil else { return [] }
    return changeStepRequests.removeValue(forKey: id) ?? []
  }
}
