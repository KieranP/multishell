import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite(.serialized)
struct FileTabImageReaderTests {
  private static func address(of copy: ImageFileBytes?) throws -> UnsafeRawPointer? {
    try #require(copy).data.withUnsafeBytes { $0.baseAddress }
  }

  @Test func aChangedImageShowsItsCommittedCopyBeforeTheFileOnDisk() async throws {
    let repository = try await FileTabRepository.make()
    defer { repository.tearDown() }
    let before = FakeImage.bytes(width: 4, height: 3)
    let after = FakeImage.bytes(width: 8, height: 6)
    try await repository.commit(before, as: "logo.png")
    try after.write(to: repository.path.appending(path: "logo.png"))

    let reading = await repository.read("logo.png")

    let image = try #require(reading.image)
    #expect(image.shownCopies.map(\.image.data) == [before, after])
    #expect(image.shownCopies.map(\.side) == [.before, .after])
    #expect(image.onDisk?.pixelSize == ImagePixelSize(width: 8, height: 6))
    #expect(!reading.isFileGone)
  }

  @Test func anUnchangedOrNewImageShowsOneUnlabelledCopy() async throws {
    let repository = try await FileTabRepository.make()
    defer { repository.tearDown() }
    let logo = FakeImage.bytes(width: 4, height: 3)
    try await repository.commit(logo, as: "logo.png")
    try FakeImage.bytes(width: 2, height: 2).write(to: repository.path.appending(path: "new.png"))

    let unchanged = try #require((await repository.read("logo.png")).image)
    let new = try #require((await repository.read("new.png")).image)

    #expect(unchanged.shownCopies.map(\.side) == [nil])
    #expect(new.shownCopies.map(\.image.pixelSize) == [ImagePixelSize(width: 2, height: 2)])
  }

  @Test func aReadOfUnchangedCopiesKeepsTheBuffersTheLastReadHeld() async throws {
    let repository = try await FileTabRepository.make()
    defer { repository.tearDown() }
    try await repository.commit(
      FakeImage.bytes(width: 4, height: 3, padding: 64),
      as: "logo.png",
    )
    try FakeImage.bytes(width: 8, height: 6, padding: 64).write(
      to: repository.path.appending(path: "logo.png")
    )
    let first = await repository.read("logo.png")

    let second = await repository.read("logo.png", previous: first)

    let before = try #require(first.image)
    let after = try #require(second.image)
    #expect(try Self.address(of: after.onDisk) == Self.address(of: before.onDisk))
    #expect(try Self.address(of: after.committed) == Self.address(of: before.committed))
  }

  /// `rev-parse` exiting 1 and 2, then `cat-file -s` failing so no side resolves.
  @Test(arguments: [
    "case \"$*\" in *rev-parse*) exit 1;; esac",
    "case \"$*\" in *rev-parse*) exit 2;; esac",
    "case \"$*\" in *\"cat-file -s\"*) exit 2;; esac",
  ])
  func aGitReadThatFailsKeepsTheCommittedCopyBesideTheNewFile(failure: String) async throws {
    let repository = try await FileTabRepository.make()
    defer { repository.tearDown() }
    let committed = FakeImage.bytes(width: 1, height: 1)
    try await repository.commit(committed, as: "logo.png")
    let file = repository.path.appending(path: "logo.png")
    try FakeImage.bytes(width: 2, height: 2).write(to: file)
    let first = await repository.read("logo.png")
    let failing = try repository.wrappingGit(in: failure)
    let edited = FakeImage.bytes(width: 3, height: 3)
    try edited.write(to: file)

    let second = await failing.read("logo.png", previous: first)

    #expect(second.image?.shownCopies.map(\.image.data) == [committed, edited])
  }

  @Test func bytesThatNoLongerDecodeWhereGitCannotSayKeepTheLastReading() async throws {
    let repository = try await FileTabRepository.make()
    defer { repository.tearDown() }
    try await repository.commit(FakeImage.bytes(width: 1, height: 1), as: "logo.png")
    let file = repository.path.appending(path: "logo.png")
    try FakeImage.bytes(width: 2, height: 2).write(to: file)
    let first = await repository.read("logo.png")
    let failing = try repository.wrappingGit(
      in: "case \"$*\" in *\"cat-file -s\"*) exit 2;; esac"
    )
    try Data([0x00, 0x01]).write(to: file)

    let second = await failing.read("logo.png", previous: first)

    #expect(second == first)
  }

  @Test func aCommitOfTheFileAsShownKeepsTheBufferTheTabHolds() async throws {
    let repository = try await FileTabRepository.make()
    defer { repository.tearDown() }
    try await repository.commit(
      FakeImage.bytes(width: 1, height: 1, padding: 64),
      as: "logo.png",
    )
    try FakeImage.bytes(width: 2, height: 2, padding: 64).write(
      to: repository.path.appending(path: "logo.png")
    )
    let first = await repository.read("logo.png")
    _ = try await repository.runner.run(["commit", "-qam", "logo"], in: repository.path)

    let second = await repository.read("logo.png", previous: first)

    #expect(try Self.address(of: second.image?.onDisk) == Self.address(of: first.image?.onDisk))
    #expect(try Self.address(of: second.image?.committed) == Self.address(of: first.image?.onDisk))
  }

  @Test func aCommittedObjectGitNamesButCannotSizeIsNoCopyToKeepUnderItsID() async throws {
    let repository = try await FileTabRepository.make()
    defer { repository.tearDown() }
    try await repository.commit(FakeImage.bytes(width: 1, height: 1), as: "logo.png")
    try FakeImage.bytes(width: 2, height: 2).write(to: repository.path.appending(path: "logo.png"))
    let objectID = String(repeating: "?", count: 40)
    let failing = try repository.wrappingGit(
      in: "case \"$*\" in *\"cat-file -s \"\(objectID)) exit 128;; esac"
    )

    let reading = await failing.read("logo.png")

    #expect(reading.content == .unreadable)
  }

  @Test func aDeletedImageShowsItsCommittedCopyAlone() async throws {
    let repository = try await FileTabRepository.make()
    defer { repository.tearDown() }
    let logo = FakeImage.bytes(width: 4, height: 3)
    try await repository.commit(logo, as: "logo.png")
    try FileManager.default.removeItem(at: repository.path.appending(path: "logo.png"))

    let reading = await repository.read("logo.png")

    #expect(reading.isFileGone)
    #expect(reading.image?.shownCopies.map(\.image.data) == [logo])
  }

  @Test func anImageDeletedUnderAnOpenTabKeepsTheCopyItLastShowed() async throws {
    let repository = try await FileTabRepository.make()
    defer { repository.tearDown() }
    try await repository.commit(FakeImage.bytes(width: 4, height: 3), as: "logo.png")
    let edited = FakeImage.bytes(width: 9, height: 9)
    let file = repository.path.appending(path: "logo.png")
    try edited.write(to: file)
    let before = await repository.read("logo.png")
    try FileManager.default.removeItem(at: file)

    let after = await repository.read("logo.png", previous: before)

    #expect(after.isFileGone)
    #expect(after.image?.shownCopies.map(\.image.data) == [edited])
  }

  @Test func sinceTheBaseTheCommittedCopyIsTheMergeBases() async throws {
    let repository = try await FileTabRepository.make()
    defer { repository.tearDown() }
    let original = FakeImage.bytes(width: 1, height: 1)
    try await repository.commit(original, as: "logo.png")
    let base = try await repository.base()
    _ = try await repository.runner.run(["checkout", "-q", "-b", "work"], in: repository.path)
    let committed = FakeImage.bytes(width: 2, height: 2)
    try await repository.commit(committed, as: "logo.png")

    let sinceHead = try #require((await repository.read("logo.png")).image)
    let sinceBase = try #require((await repository.read("logo.png", since: base)).image)

    #expect(sinceHead.shownCopies.map(\.side) == [nil])
    #expect(sinceBase.shownCopies.map(\.image.data) == [original, committed])
  }

  @Test func anImageNamedFileThatDecodesAsNoImageIsReadAsBefore() async throws {
    let repository = try await FileTabRepository.make()
    defer { repository.tearDown() }
    try Data([0x89, 0x50, 0x00]).write(to: repository.path.appending(path: "broken.png"))
    try repository.write("not a picture\n", to: "notes.png")

    #expect(await repository.read("broken.png").content == .binary(bytes: 3))
    #expect((await repository.read("notes.png")).image == nil)
  }

  @Test func anImageIsShownPastTheTextCapUpToItsOwn() async throws {
    let repository = try await FileTabRepository.make()
    defer { repository.tearDown() }
    let large = FakeImage.bytes(width: 4, height: 4, padding: FileTabReader.sizeLimit)
    try large.write(to: repository.path.appending(path: "large.png"))
    let huge = FakeImage.bytes(width: 4, height: 4, padding: FileTabImageReader.sizeLimit)
    try huge.write(to: repository.path.appending(path: "huge.png"))

    #expect((await repository.read("large.png")).image?.onDisk?.data == large)
    #expect(await repository.read("huge.png").content == .tooLarge(bytes: huge.count))
  }
}
