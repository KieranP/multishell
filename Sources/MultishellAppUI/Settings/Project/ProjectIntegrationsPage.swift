import MultishellAppCore
import MultishellCore
import MultishellServices
import SwiftUI

/// Whether this project's pull requests and CI runs are read, and what each
/// integration's tool says of itself, asked as the page opens.
struct ProjectIntegrationsPage: View {
  let model: AppModel
  let project: Project

  var body: some View {
    Form {
      ForEach(ServiceIntegration.allCases, id: \.self) { integration in
        Section {
          InfoToggle(
            integration.settingsLabel,
            info: integration.settingsInfo,
            isOn: Binding(
              get: { model.isIntegrationEnabled(integration, for: project) },
              set: { model.setIntegration(integration, isEnabled: $0, for: project) },
            ),
          )
          SettingsCaption(model.integrationAvailability(integration).text(of: integration))
          if let fit = model.integrationRepositoryFit(integration, for: project).text(
            of: integration
          ) {
            SettingsCaption(fit)
          }
        }
      }
    }
    .formStyle(.grouped)
    .task { await model.refreshServiceToolStatuses() }
    .onDisappear { model.stopAskingToolStatuses() }
  }
}
