import Foundation
import MultishellCore
import MultishellProcess

extension PresentedError {
  /// A child process, a file descriptor or the socket.
  static func processAlert(_ error: any Error) -> Alert? {
    switch error {
    case let failure as ProcessFailure where failure.message.contains("invalid reference: HEAD"):
      // An unborn HEAD: the repository has never been committed to.
      return (t("error.no-commits-title"), t("error.no-commits-message"))

    case let failure as ProcessFailure where failure.arguments.first == "fetch":
      // Fetch runs with no terminal to answer on, so a repository wanting a
      // password waits out the timeout: the likeliest way this ends.
      switch failure.stopReason {
      case .timedOut:
        return (t("error.fetch-timed-out-title"), t("error.fetch-timed-out-message"))

      case .byUser, .none:
        return (t("error.fetch-failed-title"), outputOrStatus(failure))
      }

    case let failure as ProcessFailure:
      return (
        t(
          "error.command-failed-title",
          failure.executable,
          failure.arguments.prefix(2).joined(separator: " "),
        ),
        outputOrStatus(failure),
      )

    case let failure as SocketFailure:
      return socketAlert(failure)

    case let failure as DescriptorUnavailable:
      return (t("error.no-descriptor-title"), descriptorMessage(failure))

    default:
      return nil
    }
  }

  static func descriptorMessage(_ failure: DescriptorUnavailable) -> String {
    t("error.no-descriptor-message", String(cString: strerror(failure.code)), failure.code)
  }

  private static func outputOrStatus(_ failure: ProcessFailure) -> String {
    failure.message.isEmpty ? t("error.exit-status", failure.status) : failure.message
  }

  /// A second copy holding the socket is its own alert; the rest say what
  /// the call was. Only `strerror` stays in English, being the system's.
  private static func socketAlert(_ failure: SocketFailure) -> Alert {
    switch failure.kind {
    case .inUse:
      (t("error.another-app-title"), t("error.another-app-message", failure.path))

    case .pathTooLong:
      (
        t("error.socket-title"),
        t("error.socket-message", t("error.socket-path-too-long", failure.path)),
      )

    case .system(let operation, let code):
      (
        t("error.socket-title"),
        t(
          "error.socket-message",
          t(
            "error.socket-call-failed",
            operation,
            failure.path,
            String(cString: strerror(code)),
            code,
          ),
        ),
      )
    }
  }
}
