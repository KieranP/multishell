import MultishellAppCore
import MultishellCore
import SwiftUI

/// Settings > Notifications, one toggle per reported state. The rows and the
/// note are `NotificationSettings`, which also words a refusal.
struct NotificationSettingsTab: View {
  let model: AppModel

  var body: some View {
    Form {
      Section {
        ForEach(NotificationSettings.rows) { row in
          InfoToggle(row.title, info: row.info, isOn: notifies(row.state))
        }
      } header: {
        Text(t("notifications.header"))
      } footer: {
        SettingsCaption(
          NotificationSettings.note(
            for: model.notificationAuthorization,
            settingsLocation: model.platform.notificationSettingsLocation))
      }
    }
    .formStyle(.grouped)
    .onAppear { model.refreshNotificationAuthorization() }
  }

  private func notifies(_ state: SessionState) -> Binding<Bool> {
    Binding(
      get: { model.workspace.notifications[state] },
      set: { on in
        var preference = model.workspace.notifications
        preference[state] = on
        model.setNotifications(preference)
      }
    )
  }
}
