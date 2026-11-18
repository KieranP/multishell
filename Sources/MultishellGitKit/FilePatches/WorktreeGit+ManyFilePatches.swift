import Foundation
import MultishellCore

/// Many files' patches in a few git runs, for the All changes tab, which ran
/// one or two a file; see Docs/design/files/all-changes-tab.md.
extension WorktreeGit {
  private static let pathsPerDiff = 40
  private static let headerStart = Data("diff --git ".utf8)

  /// Each file's part of a patch naming many, by its `diff --git a/P b/P`
  /// header; `nil` where a header names none of `paths` as written.
  private static func patchesByPath(_ output: Data, of paths: [String]) -> [String: Data]? {
    let headers = Dictionary(
      paths.map { ("diff --git a/\($0) b/\($0)", $0) },
      uniquingKeysWith: { first, _ in first },
    )
    var starts: [Data.Index] = []
    var searchFrom = output.startIndex
    while let range = output.range(of: headerStart, in: searchFrom..<output.endIndex) {
      if range.lowerBound == output.startIndex || output[range.lowerBound - 1] == UInt8(ascii: "\n")
      {
        starts.append(range.lowerBound)
      }
      searchFrom = range.upperBound
    }
    var parts: [String: Data] = [:]
    for (index, start) in starts.enumerated() {
      let end = index + 1 < starts.count ? starts[index + 1] : output.endIndex
      let lineEnd = output[start..<end].firstIndex(of: UInt8(ascii: "\n")) ?? end
      guard let header = String(data: output[start..<lineEnd], encoding: .utf8),
        let path = headers[header]
      else { return nil }
      // A type change, a file become a link, is two sections under one header.
      parts[path, default: Data()].append(output[start..<end])
    }
    return parts
  }

  /// Each path's patches as `patches(of:)` gives them, against `commit` else `base`;
  /// a path git quoted is left out to read alone. `nil` where git cannot say.
  public func patches(
    ofMany paths: [String],
    in directory: URL,
    diffAlgorithm: DiffAlgorithm,
    since commit: String?,
    base: String,
  ) async -> [String: FilePatches]? {
    let chunks = paths.chunked(into: Self.pathsPerDiff)
    // A steady few in flight, the next started as each lands: a wave waited on its slowest.
    return await withTaskGroup(of: [String: FilePatches]?.self) { group in
      var next = 0
      func startNext() {
        guard next < chunks.count else { return }
        let chunk = chunks[next]
        next += 1
        group.addTask {
          await patches(ofChunk: chunk, in: directory, diffAlgorithm, since: commit, base: base)
        }
      }
      for _ in 0..<Self.runsAtOnce { startNext() }
      var found: [String: FilePatches] = [:]
      for await part in group {
        guard let part else {
          group.cancelAll()
          return nil
        }
        found.merge(part) { first, _ in first }
        startNext()
      }
      return found
    }
  }

  /// One run's paths; a chunk whose headers git quoted gives none, each of its
  /// files then read alone.
  private func patches(
    ofChunk chunk: [String],
    in directory: URL,
    _ diffAlgorithm: DiffAlgorithm,
    since commit: String?,
    base: String,
  ) async -> [String: FilePatches]? {
    // Headers name each path as written, an accented one too, to split the output by.
    let arguments = ["-c", "core.quotePath=false"] + Self.patchArguments(diffAlgorithm)
    async let onDiskRun = runner.outputBytes(
      arguments + [commit ?? base, "--"] + chunk,
      in: directory,
    )
    async let stagedRun: Data? =
      commit == nil
      ? runner.outputBytes(arguments + ["--cached", base, "--"] + chunk, in: directory)
      : Data()
    guard let onDiskOutput = await onDiskRun, let stagedOutput = await stagedRun else {
      return nil
    }
    guard let onDisk = Self.patchesByPath(onDiskOutput, of: chunk),
      let staged = Self.patchesByPath(stagedOutput, of: chunk)
    else { return [:] }
    return Dictionary(
      uniqueKeysWithValues: chunk.map { path in
        (
          path,
          FilePatches(
            onDisk: onDisk[path] ?? Data(),
            staged: commit == nil ? staged[path] ?? Data() : nil,
          ),
        )
      }
    )
  }
}
