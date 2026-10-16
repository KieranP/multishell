import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite
struct WatchedDirectoriesTests {
  @Test func aChangeDeepInADirectoryIsReportedAsTheDirectoryHoldingIt() throws {
    let root = try Scratch.directory("watched")
    defer { Scratch.remove(root) }
    let watched = WatchedDirectories([root])
    let real = try #require(watched.realPaths.first)

    #expect(
      watched.reportedURL(forEventAt: "\(real)/src/deep/a.swift")
        == root.appending(path: "src/deep")
    )
    #expect(watched.reportedURL(forEventAt: "\(real)/src/deep/") == root.appending(path: "src"))
  }

  @Test func anEntryAtTheTopOfAWatchedDirectoryIsReportedAsItself() throws {
    let root = try Scratch.directory("watched")
    defer { Scratch.remove(root) }
    let watched = WatchedDirectories([root])
    let real = try #require(watched.realPaths.first)

    #expect(watched.reportedURL(forEventAt: "\(real)/HEAD") == root.appending(path: "HEAD"))
  }

  @Test func aChangeInTheDirectoryItselfIsReportedAsTheDirectory() throws {
    let root = try Scratch.directory("watched")
    defer { Scratch.remove(root) }
    let watched = WatchedDirectories([root])
    let real = try #require(watched.realPaths.first)

    #expect(watched.reportedURL(forEventAt: "\(real)/") == root)
  }

  @Test func theDeepestWatchedDirectoryHoldingAChangeReportsIt() throws {
    let main = try Scratch.directory("watched")
    defer { Scratch.remove(main) }
    let git = main.appending(path: ".git")
    try FileManager.default.createDirectory(at: git, withIntermediateDirectories: true)
    let watched = WatchedDirectories([main, git])
    let realGit = try #require(watched.realPaths.first { $0.hasSuffix("/.git") })

    #expect(
      watched.reportedURL(forEventAt: "\(realGit)/refs/heads/main")
        == git.appending(path: "refs/heads")
    )
  }

  @Test func aSiblingWhoseNameStartsLikeAWatchedDirectoryIsNotInIt() throws {
    let root = try Scratch.directory("watched")
    defer { Scratch.remove(root) }
    let watched = WatchedDirectories([root])
    let real = try #require(watched.realPaths.first)

    #expect(watched.reportedURL(forEventAt: "\(real)-side/src/") == nil)
  }

  @Test func aDirectoryThatIsNotThereIsNotWatched() {
    let watched = WatchedDirectories([URL(fileURLWithPath: "/definitely/not/here")])

    #expect(watched.realPaths.isEmpty)
  }

  @Test func aChangeIsReportedInTheSpellingTheCallerWatchedNotTheRealPath() throws {
    let root = try Scratch.directory("watched")
    defer { Scratch.remove(root) }
    let link = root.deletingLastPathComponent().appending(path: "\(root.lastPathComponent)-link")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: root)
    defer { try? FileManager.default.removeItem(at: link) }
    let watched = WatchedDirectories([link])
    let real = try #require(watched.realPaths.first)

    #expect(watched.reportedURL(forEventAt: "\(real)/src/") == link.appending(path: "src"))
  }

  @Test func aLockFileIsReportedByItsFullPathSoItsReaderCanTellItFromWhatItGuards() throws {
    let root = try Scratch.directory("watched")
    defer { Scratch.remove(root) }
    let watched = WatchedDirectories([root])
    let real = try #require(watched.realPaths.first)

    #expect(
      watched.reportedURL(forEventAt: "\(real)/refs/remotes/origin/main.lock")
        == root.appending(path: "refs/remotes/origin/main.lock")
    )
  }

  @Test func aChangeUnderAWatchedRootDirectoryIsReported() {
    let watched = WatchedDirectories([URL(fileURLWithPath: "/")])

    #expect(watched.reportedURL(forEventAt: "/tmp/x") == URL(fileURLWithPath: "/tmp"))
  }

  @Test func aGitignoreIsReportedByItsFullPathSoItsReaderCanTellItChanged() throws {
    let root = try Scratch.directory("watched")
    defer { Scratch.remove(root) }
    let watched = WatchedDirectories([root])
    let real = try #require(watched.realPaths.first)

    #expect(
      watched.reportedURL(forEventAt: "\(real)/packages/p/.gitignore")
        == root.appending(path: "packages/p/.gitignore")
    )
  }

  @Test func gitsFileMonitorEntriesAreReportedByTheirFullPath() throws {
    let root = try Scratch.directory("watched")
    defer { Scratch.remove(root) }
    let watched = WatchedDirectories([root])
    let real = try #require(watched.realPaths.first)

    for entry in ["fsmonitor--daemon", "fsmonitor--daemon.ipc"] {
      #expect(
        watched.reportedURL(forEventAt: "\(real)/worktrees/side/\(entry)")
          == root.appending(path: "worktrees/side/\(entry)")
      )
    }
  }
}
