import Foundation
import Testing

@testable import MultishellAppCore

@Suite
struct FileTabImageTests {
  @Test func theCopyOnDiskKeepsItsSourceShownAloneOrBesideTheCommittedOne() {
    let size = ImagePixelSize(width: 1, height: 1)
    let onDisk = ImageFileBytes(data: Data([1, 2]), pixelSize: size)
    let committed = ImageFileBytes(data: Data([3, 4]), pixelSize: size)

    let changed = FileTabImage.sharingBuffers(
      onDisk: onDisk,
      committed: committed,
      committedObjectID: "a",
      keptFrom: nil,
    )
    let alone = changed?.lastCopyOnDisk()

    #expect(changed?.shownCopies.map(\.source) == [.committed, .onDisk])
    #expect(alone?.shownCopies.map(\.source) == [.onDisk])
  }
}
