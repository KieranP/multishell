import MultishellAppCore
import MultishellCore
import SwiftUI

/// What heads a page of what `.multishell.json` may ask for: its trust where
/// it asks for any, else why it would not read.
struct SharedSettingsHeader: View {
  let model: AppModel
  let project: Project
  let lines: SharedSettingsTrustLines

  var body: some View {
    if project.sharedSettingsSnapshot.confined?.asksForTrust == true {
      SharedSettingsTrustSection(model: model, project: project, lines: lines)
    } else if let problem = project.sharedSettingsSnapshot.problem {
      SettingsGroup { SettingsCaption(problem) }
    }
  }
}
