import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

struct AllChangesReadSlotsTests {
  private static func file(_ path: String, rows: Int) -> AllChangesFile {
    AllChangesFile(
      change: AllChangesFileChange(path: path, kind: .modified, lineCounts: nil),
      content: .read(
        FileTabReading(
          content: .text(
            FileTabRows(
              lines: (0..<rows).map { line in
                DiffLine(kind: .added, oldNumber: nil, newNumber: line + 1, text: "\(line)")
              },
              marksStaging: true,
            )
          ),
          isFileGone: false,
        )
      ),
      signature: nil,
    )
  }

  @Test func rowsReachingTheCapAheadOfASlowFirstFileStopFurtherReads() {
    var slots = AllChangesReadSlots(count: 4, rowCap: 10)

    slots.land(Self.file("b.txt", rows: 6), at: 1)
    slots.land(Self.file("c.txt", rows: 6), at: 2)

    #expect(slots.reachesRowCap)
    #expect(!slots.isCapped)
  }

  @Test func onceTheFirstFileLandsTheFilesPastTheCapShowTheirHeadersAlone() {
    var slots = AllChangesReadSlots(count: 4, rowCap: 10)
    let files = ["a.txt", "b.txt", "c.txt", "d.txt"].map { Self.file($0, rows: 6) }
    slots.land(files[1], at: 1)
    slots.land(files[2], at: 2)

    slots.land(files[0], at: 0)

    let landed = slots.files(of: files.map { ($0.change, nil) })
    #expect(landed.map { $0.content == .pastRowCap } == [false, false, true, true])
  }

  @Test func filesLandedInOrderThatReachTheCapPutEveryFileAfterThemPastIt() {
    var slots = AllChangesReadSlots(count: 4, rowCap: 10)
    let files = ["a.txt", "b.txt", "c.txt", "d.txt"].map { Self.file($0, rows: 6) }

    slots.land(files[0], at: 0)
    slots.land(files[1], at: 1)

    #expect(slots.isCapped)
    let landed = slots.files(of: files.map { ($0.change, nil) })
    #expect(landed.map { $0.content == .pastRowCap } == [false, false, true, true])
  }
}
