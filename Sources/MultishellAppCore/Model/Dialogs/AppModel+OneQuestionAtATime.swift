extension AppModel {
  /// A base update, Abort, branch publish or trust question waits on its answer.
  /// Raised over each other they fought on one window, so a second waits.
  var isAskingAQuestion: Bool {
    pendingBaseUpdate != nil || pendingUpdateAbort != nil || pendingBranchPublish != nil
      || pendingSharedSettingsTrust != nil
  }

  /// A click that would ask a second question beeps instead, and `true` says it did.
  func beepIfAQuestionWaits() -> Bool {
    guard isAskingAQuestion else { return false }
    platform.beep()
    return true
  }
}
