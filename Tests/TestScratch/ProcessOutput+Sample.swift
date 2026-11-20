import Foundation

@testable import MultishellProcess

extension ProcessOutput {
  public static func sample(
    output: String = "",
    error: String = "",
    status: Int32 = 0,
    stopReason: ProcessStopReason? = nil,
  ) -> Self {
    ProcessOutput(
      standardOutputBytes: Data(output.utf8),
      standardError: error,
      status: status,
      stopReason: stopReason,
    )
  }
}
