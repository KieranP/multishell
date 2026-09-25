import MultishellAppCore
import MultishellCore
import SwiftUI

/// Settings > Notifications, one toggle per reported state. The rows and the
/// note are `NotificationSettingsText`, which also words a refusal.
struct NotificationsSettingsPage: View {
  let model: AppModel

  var body: some View {
    Form {
      Section {
        ForEach(NotificationSettingsText.rows) { row in
          InfoToggle(row.title, info: row.info, isOn: model.notificationSetting(for: row.state))
        }
      } header: {
        Text(t("notifications.header"))
      } footer: {
        SettingsCaption(model.notificationSettingsNote)
      }
    }
    .formStyle(.grouped)
    .onAppear { model.refreshNotificationAuthorization() }
  }
}
