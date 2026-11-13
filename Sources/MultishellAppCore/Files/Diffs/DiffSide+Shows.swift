import MultishellCore

extension DiffSide {
  func shows(_ kind: DiffLine.Kind) -> Bool {
    switch kind {
    case .context: true
    case .added: self == .onDisk
    case .removed: self == .committed
    case .padding: false
    }
  }
}
