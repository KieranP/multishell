import Foundation

/// Calls a handler in an AppleScript with its arguments as Apple event
/// parameters, never as script text; see Docs/design/smaller-decisions.md.
@MainActor
enum AppleScriptHandler {
  /// Links `/usr/local/bin/multishell` to the stable link. The one script
  /// this app runs with administrator rights.
  static let installCommandLineTool = """
    on installTool(target, link)
      do shell script "mkdir -p /usr/local/bin && ln -sf " & quoted form of target & " " ¬
        & quoted form of link with administrator privileges
    end installTool
    """

  /// Four-char codes from `AppleScript.h`, which Swift does not import:
  /// `ascr`, `psbr` and `snam`.
  private static let suite = AEEventClass(0x6173_6372)
  private static let subroutineEvent = AEEventID(0x7073_6272)
  private static let handlerName = AEKeyword(0x736e_616d)

  @discardableResult
  static func call(_ source: String, handler: String, arguments: [String]) throws -> String? {
    let script = try compile(source)
    let list = NSAppleEventDescriptor.list()
    // `at: 0` appends, this being AppleScript's one-based indexing.
    for argument in arguments {
      list.insert(NSAppleEventDescriptor(string: argument), at: 0)
    }

    let event = NSAppleEventDescriptor(
      eventClass: suite,
      eventID: subroutineEvent,
      targetDescriptor: .currentProcess(),
      returnID: AEReturnID(kAutoGenerateReturnID),
      transactionID: AETransactionID(kAnyTransactionID))
    event.setParam(NSAppleEventDescriptor(string: handler), forKeyword: handlerName)
    event.setParam(list, forKeyword: AEKeyword(keyDirectObject))

    var problem: NSDictionary?
    let result = script.executeAppleEvent(event, error: &problem)
    if let problem { throw AppleScriptFailed(problem) }
    return result.stringValue
  }

  @discardableResult
  static func compile(_ source: String) throws -> NSAppleScript {
    guard let script = NSAppleScript(source: source) else {
      throw AppleScriptFailed(message: t("platform.applescript-unreadable"))
    }
    var problem: NSDictionary?
    guard script.compileAndReturnError(&problem) else { throw AppleScriptFailed(problem) }
    return script
  }
}
