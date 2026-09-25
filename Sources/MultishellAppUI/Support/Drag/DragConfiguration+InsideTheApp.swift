import SwiftUI

extension DragConfiguration {
  /// Finder took a tab or project dropped on it and made a file of it, the
  /// tab's `.ownProcess` visibility notwithstanding.
  static var insideTheAppOnly: DragConfiguration {
    DragConfiguration(
      operationsWithinApp: .init(allowCopy: true, allowMove: true),
      operationsOutsideApp: .init(allowCopy: false, allowMove: false, allowDelete: false))
  }
}
