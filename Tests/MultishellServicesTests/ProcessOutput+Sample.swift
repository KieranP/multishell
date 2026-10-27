import Foundation

@testable import MultishellProcess

extension ProcessOutput {
  static func sample(output: String = "", error: String = "", status: Int32 = 0) -> Self {
    ProcessOutput(
      standardOutputBytes: Data(output.utf8),
      standardError: error,
      status: status,
      stopReason: nil,
    )
  }
}
