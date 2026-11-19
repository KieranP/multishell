extension ShortcutJudgement {
  var isAllowed: Bool {
    if case .allowed = self { true } else { false }
  }
}
