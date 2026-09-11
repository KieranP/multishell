import MultishellAppCore
import MultishellCore
import SwiftUI

/// Settings > Notifications: which reported states post a system
/// notification for a tab the user is not looking at, one toggle each.
///
/// The rows, their help and the note under them are `NotificationSettings`,
/// which also decides what that note says when macOS has refused: the page
/// asks for permission as the first toggle goes on, so a refusal has to be
/// shown here or the toggles above it are three switches that do nothing.
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
