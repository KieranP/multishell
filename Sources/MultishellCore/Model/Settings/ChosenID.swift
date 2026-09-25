/// Which catalogue entry is in force: a project's override where it has one,
/// else the global. `nil` where that is blank or the catalogue's `none`.
enum ChosenID {
  static func inForce(global: String?, override: String? = nil, none: String) -> String? {
    let chosen = override ?? global
    guard let chosen, !chosen.isEmpty, chosen != none else { return nil }
    return chosen
  }
}
