/// Which catalogue entry is in force: a project's override where it has one,
/// else the global. `nil` where that is blank or the catalogue's none id.
enum ChosenID {
  static func effective(global: String?, override: String? = nil, noneID: String) -> String? {
    let chosen = override ?? global
    guard let chosen, !chosen.isEmpty, chosen != noneID else { return nil }
    return chosen
  }
}
