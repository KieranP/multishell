import Foundation
import MultishellCore
import MultishellGitKit

/// An image tab's two copies, for `FileTabReader`; see Docs/design/files/image-tabs.md.
enum FileTabImageReader {
  /// A camera's photo or a 5K screenshot fits; decoded, a picture costs its
  /// pixels, not its file, which the view caps when it draws one.
  static let sizeLimit = 32 << 20

  /// Blocking, a camera raw's header being long: callers run it through `runOnDispatch`.
  static func bytes(_ data: Data, _ rule: ImageRule) -> ImageFileBytes? {
    rule.pixelSize(data).map { ImageFileBytes(data: data, pixelSize: $0) }
  }

  /// `nil` where neither copy is an image, for the text reading to say why; the last
  /// committed copy beside the new read where git could not place or read the side.
  static func content(
    onDisk read: ImageFileBytes?,
    of repository: RepositoryLocation,
    against side: CommittedSide?,
    git: WorktreeGit,
    previous: FileTabImage?,
    _ rule: ImageRule,
  ) async -> FileTabContent? {
    guard let side else { return await keptBeside(read, previous: previous) }
    let committed = await committedCopy(
      of: repository,
      against: side,
      git: git,
      previous: previous,
      rule,
    )
    guard let committed else { return await keptBeside(read, previous: previous) ?? .unreadable }
    return await image(read, committed: committed, previous)
  }

  /// The last committed copy beside the new read, where git could not say what
  /// the committed side holds; `nil` where no image was read before.
  private static func keptBeside(
    _ read: ImageFileBytes?,
    previous: FileTabImage?,
  ) async -> FileTabContent? {
    guard let previous else { return nil }
    return await image(
      read,
      committed: (previous.committed, previous.committedObjectID),
      previous,
    )
  }

  private static func image(
    _ read: ImageFileBytes?,
    committed: (bytes: ImageFileBytes?, objectID: String?),
    _ previous: FileTabImage?,
  ) async -> FileTabContent? {
    let image = await runOnDispatch {
      FileTabImage.sharingBuffers(
        onDisk: read,
        committed: committed.bytes,
        committedObjectID: committed.objectID,
        keptFrom: previous,
      )
    }
    return image.map(FileTabContent.image)
  }

  /// Read whole only where its object moved since the last read, by that id so
  /// the bytes are the ones it names; `nil` where git could not say.
  private static func committedCopy(
    of repository: RepositoryLocation,
    against side: CommittedSide,
    git: WorktreeGit,
    previous: FileTabImage?,
    _ rule: ImageRule,
  ) async -> (bytes: ImageFileBytes?, objectID: String?)? {
    guard let size = side.size, size <= sizeLimit else { return (nil, nil) }
    let objectID: String?
    do {
      objectID = try await git.committedObjectID(
        of: repository.path,
        in: repository.directory,
        at: side.commit,
      )
    } catch {
      return nil
    }
    // The size said there is a copy, so none now is a `HEAD` moved mid-read.
    guard let objectID else { return nil }
    if objectID == previous?.committedObjectID { return (previous?.committed, objectID) }
    // Sized again by its id: `HEAD` may have moved since the side was sized.
    let objectSize: Int?
    do {
      objectSize = try await git.objectSize(objectID, in: repository.directory)
    } catch {
      return nil
    }
    // An object `rev-parse` named but git cannot size is no answer, not no copy.
    guard let objectSize else { return nil }
    guard objectSize <= sizeLimit else { return (nil, objectID) }
    guard let data = await git.objectBytes(objectID, in: repository.directory) else { return nil }
    return (await runOnDispatch { bytes(data, rule) }, objectID)
  }
}
