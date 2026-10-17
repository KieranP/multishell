import MultishellCore
import MultishellGitKit
import SwiftUI

extension Theme {
  /// A file's dot, in the git badge's colours.
  func color(for change: StatusChange.Kind) -> Color {
    switch change {
    case .added: insertionsColor
    case .deleted: deletionsColor
    case .modified: unscoredFilesColor
    }
  }
}
