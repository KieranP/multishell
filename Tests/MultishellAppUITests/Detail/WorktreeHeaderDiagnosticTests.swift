import AppKit
import SwiftUI
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI
@testable import MultishellCore

@Suite @MainActor
struct WorktreeHeaderDiagnosticTests {
  private func runs(width: Double, worktree: Worktree, harness: ModelHarness) throws -> [ClosedRange<Int>] {
    let theme = try MagentaTheme.with([.header: [.textTertiary]])
    let bitmap = try #require(
      OffscreenWindow.pixels(
        ofHosted: WorktreeHeader(model: harness.model, worktree: worktree, theme: theme),
        size: CGSize(width: width, height: 40),
      )
    )
    let ppp = bitmap.pixelsWide / Int(width)
    let pixelRuns: [ClosedRange<Int>] = MagentaTheme.inkedColumns(in: bitmap)
      .reduce(into: []) { runs, x in
        if let last = runs.last, x - last.upperBound <= 3 * ppp {
          runs[runs.count - 1] = last.lowerBound...x
        } else {
          runs.append(x...x)
        }
      }
    return pixelRuns.map { ($0.lowerBound / ppp)...($0.upperBound / ppp) }
  }

  @Test func reportLayout() throws {
    let harness = ModelHarness()
    let worktree = harness.addPrimaryWorktree(branch: "feature/long-branch-name")
    harness.model.renameWorktree(worktree.id, to: "Auth")
    let caption = harness.model.metrics.caption
    let path = worktree.path.path.abbreviatingHomeDirectory()
    var lines = ["os=\(ProcessInfo.processInfo.operatingSystemVersionString) caption=\(caption) path=\(path)"]

    let tail = ReadableTail(
      text: path,
      leastWidth: UIMetrics.readableTailWidth(atSize: caption),
      insets: EdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 0),
    )
    .font(.system(size: caption, design: .monospaced))
    let controller = NSHostingController(rootView: tail)
    let offers: [Double] = [0, 1, 10, 20, 35, 50, 87, 88, 89, 100, 200, 10000]
    lines.append(
      "tail: " + offers.map { "\($0)→\(controller.sizeThatFits(in: CGSize(width: $0, height: 40)).width)" }
        .joined(separator: " ")
    )
    let branchText = Text(worktree.name).font(.system(size: caption, design: .monospaced)).lineLimit(1)
    lines.append("branch ideal=\(NSHostingController(rootView: branchText).sizeThatFits(in: CGSize(width: 10000, height: 40)).width)")

    let wide = try runs(width: 1600, worktree: worktree, harness: harness)
    lines.append("wide=\(wide)")
    for extra in [100.0, 110, 120, 130, 140, 150, 160, 200] {
      let width = Double(wide[1].upperBound) + extra
      lines.append("+\(extra) w=\(width): \(try runs(width: width, worktree: worktree, harness: harness))")
    }

    let shortHarness = ModelHarness()
    let primary = shortHarness.addPrimaryWorktree(branch: "feature/long-branch-name")
    let short = Worktree(
      path: URL(fileURLWithPath: "/w"),
      projectID: shortHarness.project.id,
      head: "abc1234",
      branch: "feature/long-branch-name",
    )
    shortHarness.store.replaceWorktrees([primary, short], forProject: shortHarness.project.id)
    shortHarness.model.renameWorktree(short.id, to: "Auth")
    let shortWide = try runs(width: 1600, worktree: short, harness: shortHarness)
    lines.append("short-path wide=\(shortWide)")
    for extra in [100.0, 110, 120, 130, 140, 150] {
      let width = Double(shortWide[1].upperBound) + extra
      lines.append("short +\(extra): \(try runs(width: width, worktree: short, harness: shortHarness))")
    }

    Issue.record(Comment(rawValue: "DIAG\n" + lines.joined(separator: "\n")))
  }
}
