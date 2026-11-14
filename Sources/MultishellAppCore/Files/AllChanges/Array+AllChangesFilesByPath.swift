extension [AllChangesFile] {
  func keyedByPath() -> [String: AllChangesFile] {
    Dictionary(map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
  }
}
