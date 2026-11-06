import AppKit
import MultishellAppCore
import MultishellCore
import SwiftUI

/// One copy of a file tab's image, drawn a point to a pixel and scaled down
/// to fit; decoded off the main thread each time a read brings new bytes.
struct ImageCopyView: NSViewRepresentable {
  final class Coordinator {
    var shownData: Data?
    var decoding: Task<Void, Never>?

    deinit { decoding?.cancel() }
  }

  let copy: ShownImageCopy

  func makeCoordinator() -> Coordinator { Coordinator() }

  func makeNSView(context: Context) -> NSImageView {
    let view = NSImageView()
    view.imageScaling = .scaleProportionallyDown
    view.imageAlignment = .alignCenter
    view.isEditable = false
    for orientation in [NSLayoutConstraint.Orientation.horizontal, .vertical] {
      view.setContentCompressionResistancePriority(.defaultLow, for: orientation)
      view.setContentHuggingPriority(.defaultLow, for: orientation)
    }
    return view
  }

  func updateNSView(_ view: NSImageView, context: Context) {
    view.setAccessibilityLabel(copy.caption)
    let coordinator = context.coordinator
    let data = copy.image.data
    // The model keeps a read's buffers while its bytes match, so this compares no bytes.
    guard coordinator.shownData != data else { return }
    coordinator.shownData = data
    coordinator.decoding?.cancel()
    let size = NSSize(width: copy.image.pixelSize.width, height: copy.image.pixelSize.height)
    coordinator.decoding = Task { @MainActor [weak view] in
      let decoded = await ImageCopyDecoder.decodeInTurn(data)
      guard !Task.isCancelled, let view else { return }
      view.image = decoded.map { NSImage(cgImage: $0, size: size) }
    }
  }
}
