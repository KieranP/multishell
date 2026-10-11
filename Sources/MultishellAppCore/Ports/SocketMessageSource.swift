import Foundation
import MultishellCore
import MultishellProcess

/// `MessageSource` over the Unix socket in the state directory. Handlers
/// run on the main queue, so lines arrive in order and without a hop.
@MainActor
public final class SocketMessageSource: MessageSource {
  /// An empty line would read to the helper as an app older than itself.
  nonisolated private static let unencodedReplyLine =
    (try? ControlReply.refused(.replyNotEncoded).encodedLine()) ?? ""

  public var onReport: (@MainActor (SessionStateReport) -> Void)?
  public var onRequest: ControlRequestHandler?

  private let server: UnixSocketServer

  public init(path: URL = Paths.socketFile) {
    server = UnixSocketServer(path: path, queue: .main)
    server.onLine = { [weak self] line, channel in
      MainActor.assumeIsolated { self?.receive(line, on: channel) }
    }
  }

  /// A line that is neither gets no answer, which the helper reads as an
  /// app older than itself.
  private func receive(_ line: String, on channel: SocketReplyChannel) {
    if let report = SessionStateReport.parse(line) {
      onReport?(report)
      return
    }
    guard let request = ControlRequest.parse(line), let onRequest, let reply = channel.open()
    else { return }
    let answering = Task {
      guard let answer = await onRequest(request) else { return }
      reply.send((try? answer.encodedLine()) ?? Self.unencodedReplyLine)
    }
    reply.watchForHangUp { answering.cancel() }
  }

  public func start() throws {
    try server.start()
  }

  public func stop() {
    server.stop()
  }
}
