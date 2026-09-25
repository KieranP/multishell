/// Whose hooks and whether the command-line tool are installed, read off
/// the main actor and recorded on it by `AppModel.recordInstallState`.
struct IntegrationInstallState: Sendable {
  let installedHooks: Set<String>
  let staleHooks: Set<String>
  let commandLineToolInstalled: Bool
}
