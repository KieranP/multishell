import SwiftUI

extension EdgeInsets {
  /// The same insets pulling in rather than out, to undo a padding that only
  /// widened a hit area.
  var negated: EdgeInsets {
    EdgeInsets(top: -top, leading: -leading, bottom: -bottom, trailing: -trailing)
  }
}
