extension ProjectSettings {
  public func enables(_ integration: ServiceIntegration) -> Bool {
    !disabledIntegrations.contains(integration)
  }

  /// The list is kept in `allCases` order without repeats, so turning one off
  /// and on again leaves the state file as it was.
  public mutating func setIntegration(_ integration: ServiceIntegration, isEnabled: Bool) {
    disabledIntegrations.removeAll { $0 == integration }
    if !isEnabled { disabledIntegrations.append(integration) }
    normalizeIntegrations()
  }

  /// The same form for a list written whole, as the command line does.
  public mutating func normalizeIntegrations() {
    let disabled = Set(disabledIntegrations)
    disabledIntegrations = ServiceIntegration.allCases.filter(disabled.contains)
  }
}
