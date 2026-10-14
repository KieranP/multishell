import MultishellAppCore
import SwiftUI

/// Settings > Notifications, one toggle per reported state. The rows and the
/// caption are `NotificationSettingsText`, which also words a refusal.
struct AppNotificationsPage: View {
  let model: AppModel

  var body: some View {
    Form {
      Section {
        ForEach(NotificationSettingsText.rows) { row in
          InfoToggle(row.title, info: row.info, isOn: model.notificationBinding(for: row.state))
        }
      } header: {
        Text(t("notifications.header"))
      } footer: {
        SettingsCaption(model.notificationSettingsCaption)
      }
    }
    .formStyle(.grouped)
    .onAppear { model.refreshNotificationAuthorization() }
  }
}
