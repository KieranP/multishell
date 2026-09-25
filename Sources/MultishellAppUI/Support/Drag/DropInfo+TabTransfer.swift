import SwiftUI

extension DropInfo {
  var carriesATab: Bool { hasItemsConforming(to: [TabTransfer.contentType]) }
}
