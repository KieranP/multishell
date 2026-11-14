import Foundation
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit

@Suite(.serialized)
struct AllChangesReaderTests {
  private static func status(of repository: FileTabRepository) async throws -> [StatusChange] {
    try await repository.git.status(
      inRepositoryAt: repository.path,
      counting: .default,
      diffAlgorithm: .histogram,
    )
    .changes
  }

  private static func read(
    _ changes: [StatusChange],
    in repository: FileTabRepository,
    since base: DefaultBranch? = nil,
    previous: AllChangesReading? = nil,
    rereading stale: AllChangesStaleness = .everything,
    rowCap: Int = AllChangesReader.rowCap,
  ) async -> AllChangesReading {
    await AllChangesReader.read(
      AllChangesOrder.files(of: changes),
      in: repository.path,
      git: repository.git,
      diffAlgorithm: .histogram,
      since: base,
      previous: previous,
      rereading: stale,
      imageRule: .fake,
      rowCap: rowCap,
    )
    .reading
  }

  @Test func aModifiedAnAddedADeletedAndABinaryFileReadAsTheirFileTabsWouldInTheListsOrder()
    async throws
  {
    let repository = try await FileTabRepository.make()
    defer { repository.tearDown() }
    try await TestRepository.commit(
      "seed",
      files: ["a.txt": "one\ntwo\n", "gone.txt": "bye\n"],
      in: repository.path,
      using: repository.runner,
    )
    try await repository.commit(Data([0, 1, 2]), as: "blob.bin")
    try repository.write("one\nTWO\n", to: "a.txt")
    try FileManager.default.createDirectory(
      at: repository.path.appending(path: "docs"),
      withIntermediateDirectories: true,
    )
    try repository.write("new\n", to: "docs/new.txt")
    try FileManager.default.removeItem(at: repository.path.appending(path: "gone.txt"))
    try Data([0, 9, 9, 9]).write(to: repository.path.appending(path: "blob.bin"))

    let reading = await Self.read(try await Self.status(of: repository), in: repository)

    #expect(reading.files.map(\.path) == ["docs/new.txt", "a.txt", "blob.bin", "gone.txt"])
    #expect(reading.files.map(\.change.kind) == [.added, .modified, .modified, .deleted])
    for file in reading.files {
      #expect(file.reading == (await repository.read(file.path)), "\(file.path)")
    }
    #expect(reading.files[3].reading?.isFileGone == true)
    #expect(reading.lineCounts == FileLineCounts(insertions: 2, deletions: 2))
  }

  @Test func underBranchEachFileCountsFromWhereTheBranchLeftItsBase() async throws {
    let repository = try await FileTabRepository.make()
    defer { repository.tearDown() }
    try await TestRepository.commit(
      "seed",
      files: ["a.txt": "one\n"],
      in: repository.path,
      using: repository.runner,
    )
    let base = try await repository.base()
    _ = try await repository.runner.run(["checkout", "-q", "-b", "feature"], in: repository.path)
    try await TestRepository.commit(
      "work",
      files: ["a.txt": "one\ntwo\n"],
      in: repository.path,
      using: repository.runner,
    )
    let changes = try #require(
      await repository.git.branchChanges(
        inRepositoryAt: repository.path,
        since: base,
        status: nil,
        diffAlgorithm: .histogram,
      )
    )

    let reading = await Self.read(changes.changes, in: repository, since: base)

    #expect(reading.files.map(\.path) == ["a.txt"])
    #expect(reading.files.first?.rows?.lineCounts == FileLineCounts(insertions: 1, deletions: 0))
  }

  @Test func aFilePastTheFileTabsCapSaysSoAndFilesPastTheRowCapAreNotRead() async throws {
    let repository = try await FileTabRepository.make()
    defer { repository.tearDown() }
    try repository.write(
      String(repeating: "x", count: FileTabReader.sizeLimit + 1),
      to: "big.txt",
    )
    try repository.write("a\nb\nc\n", to: "c.txt")
    try repository.write("d\n", to: "d.txt")
    try repository.write("e\n", to: "e.txt")
    try repository.write("f\n", to: "f.txt")
    try repository.write("g\n", to: "g.txt")

    let reading = await Self.read(try await Self.status(of: repository), in: repository, rowCap: 3)

    #expect(reading.files.first?.reading?.content == .tooLarge(bytes: FileTabReader.sizeLimit + 1))
    #expect(reading.files.map(\.path) == ["big.txt", "c.txt", "d.txt", "e.txt", "f.txt", "g.txt"])
    #expect(reading.files.dropFirst(4).allSatisfy { $0.content == .pastRowCap })
  }

  @Test func aSubmodulesFolderListedAsAChangeIsLeftOutAsTheChangesListLeavesIt() async throws {
    let repository = try await FileTabRepository.make()
    defer { repository.tearDown() }
    try FileManager.default.createDirectory(
      at: repository.path.appending(path: "vendor/lib"),
      withIntermediateDirectories: true,
    )
    try repository.write("a\n", to: "a.txt")
    let changes = [
      StatusChange(path: "vendor/lib", kind: .modified, lines: .notCounted),
      StatusChange(path: "a.txt", kind: .added, lines: .counted(insertions: 1, deletions: 0)),
    ]

    let reading = await Self.read(changes, in: repository)

    #expect(reading.files.map(\.path) == ["a.txt"])
  }

  @Test func aReadNamingOneFileRunsGitForThatFileAloneAndKeepsTheRest() async throws {
    let plain = try await FileTabRepository.make()
    defer { plain.tearDown() }
    try await TestRepository.commit(
      "seed",
      files: ["a.txt": "one\n", "b.txt": "two\n"],
      in: plain.path,
      using: plain.runner,
    )
    try plain.write("ONE\n", to: "a.txt")
    try plain.write("TWO\n", to: "b.txt")
    let changes = try await Self.status(of: plain)
    let first = await Self.read(changes, in: plain)
    let log = plain.root.appending(path: "git.log")
    let logged = try plain.wrappingGit(in: "echo \"$*\" >> '\(log.path)'")
    try logged.write("ONE\nmore\n", to: "a.txt")

    let second = await Self.read(
      changes,
      in: logged,
      previous: first,
      rereading: .paths(["a.txt"]),
    )

    let runs = (try? String(contentsOf: log, encoding: .utf8)) ?? ""
    #expect(runs.contains("a.txt") && !runs.contains("b.txt"))
    #expect(second.files.last == first.files.last)
    #expect(second.files.first?.rows?.lineCounts == FileLineCounts(insertions: 2, deletions: 1))
  }

  @Test func aFileWhoseSignatureMovedIsReadAgainThoughNoEventNamedIt() async throws {
    let repository = try await FileTabRepository.make()
    defer { repository.tearDown() }
    try await TestRepository.commit(
      "seed",
      files: ["a.txt": "one\n"],
      in: repository.path,
      using: repository.runner,
    )
    try repository.write("ONE\n", to: "a.txt")
    let changes = try await Self.status(of: repository)
    let first = await Self.read(changes, in: repository)
    try repository.write("ONE\nmore\n", to: "a.txt")

    let second = await Self.read(changes, in: repository, previous: first, rereading: .nothing)

    #expect(second.files.first?.rows?.lineCounts == FileLineCounts(insertions: 2, deletions: 1))
  }
}
