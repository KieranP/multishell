import MultishellAppCore
import MultishellCore
import SwiftUI

/// A file tab's image, its committed copy beside it where the two differ,
/// each captioned with its size.
struct FileTabImageView: View {
  private static let padding: Double = 16

  let model: AppModel
  let image: FileTabImage
  let theme: Theme

  var body: some View {
    HStack(spacing: 0) {
      // By source, so a copy never draws another's picture, nor decodes its own again.
      ForEach(image.shownCopies, id: \.source) { copy in
        if copy.isAfterAnother { theme.fileTab.border.frame(width: 1) }
        captioned(copy)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  /// Sized a point to a pixel at most, so the caption sits under the picture.
  private func captioned(_ copy: ShownImageCopy) -> some View {
    let size = CGSize(width: copy.image.pixelSize.width, height: copy.image.pixelSize.height)
    return VStack(spacing: 8) {
      ImageCopyView(copy: copy)
        .aspectRatio(size, contentMode: .fit)
        .frame(maxWidth: size.width, maxHeight: size.height)
      Text(copy.caption)
        .font(model.metrics.font(size: model.metrics.caption))
        .foregroundStyle(theme.fileTab.textTertiary)
        .lineLimit(1)
        .truncationMode(.middle)
        .accessibilityHidden(true)
    }
    // Clicks fall through to the tab's focus target behind.
    .allowsHitTesting(false)
    .padding(Self.padding)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
