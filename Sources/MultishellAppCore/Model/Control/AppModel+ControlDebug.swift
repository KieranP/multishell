import Foundation
import MultishellCore

extension AppModel {
  func replyToSetDebugTools(_ enabled: Bool) -> ControlReply {
    setDebugToolsEnabled(enabled)
    return .done
  }

  func replyToSetDebugInfo(_ shown: Bool) -> ControlReply {
    guard shown else {
      if showsDebugInfo { uncoverDetail() }
      return .done
    }
    guard areDebugToolsEnabled else { return .refused(.debugToolsOff) }
    showDebugInfo()
    return .done
  }

  /// The newest `last`, oldest first, live even while the panel is paused.
  func replyToDebugSamples(last: Int) -> ControlReply {
    guard areDebugToolsEnabled else { return .refused(.debugToolsOff) }
    return .json(debugHistory.samples.suffix(max(last, 1)).map(DebugSampleRecord.init))
  }

  func replyToDebugSummary(last: Int) -> ControlReply {
    guard areDebugToolsEnabled else { return .refused(.debugToolsOff) }
    return .json(DebugSummaryRecord(debugHistory.samples.suffix(max(last, 1))))
  }

  func replyToDebugMemory() -> ControlReply {
    guard areDebugToolsEnabled else { return .refused(.debugToolsOff) }
    return .json(DebugMemoryRecord(debugMemoryTable))
  }

  /// Into the next sample, so `samples` lines it up with the frame rate and
  /// CPU around it, and the platform's trace whether or not the tools are on.
  func replyToMarkDebugSample(_ name: String) -> ControlReply {
    platform.signpost(name)
    guard areDebugToolsEnabled else { return .json(["sample": nil as Int?]) }
    debugSampler.pendingMarks.append(name)
    return .json(["sample": debugHistory.nextSequence])
  }

  /// The newest `last` git runs, oldest first, each with the sample it ended in.
  func replyToDebugGitRuns(last: Int) -> ControlReply {
    guard areDebugToolsEnabled else { return .refused(.debugToolsOff) }
    return .json(debugGitRuns.entries.suffix(max(last, 1)).map(DebugGitRunRecord.init))
  }

  /// A PNG, base64 so it rides the reply's one line; the helper writes it.
  func replyToScreenshot(pane id: TerminalSession.ID?) -> ControlReply {
    let image: Data?
    if let id {
      if let refusal = refusalToReachLivePane(id) { return .refused(refusal) }
      image = host.screenshot(of: id)
    } else {
      image = platform.screenshotWorkspaceWindow()
    }
    guard let image else { return .refused(.screenshotFailed) }
    return .output(image.base64EncodedString())
  }
}
