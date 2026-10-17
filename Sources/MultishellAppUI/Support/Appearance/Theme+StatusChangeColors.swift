import MultishellCore
import MultishellGitKit
import SwiftUI

extension Theme {
  /// A file's dot: modified yellow, new green, deleted red, as the git badge
  /// colours its counts.
  func color(for change: StatusChange.Kind) -> Color {
    switch change {
    case .added: insertionsColor
    case .deleted: deletionsColor
    case .modified: ansiRGB(.yellow).color
    }
  }
}
