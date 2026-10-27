import MultishellCore
import MultishellServices

extension ServiceReadFailure {
  /// Why a read gave no answer, as a tooltip or the panel says it.
  func reason(integration: ServiceIntegration) -> String {
    switch self {
    case .failed(let message): message
    case .loggedOut: t("services.logged-out", integration.displayName)
    case .notHosted: t("services.not-hosted", integration.displayName)
    }
  }
}
