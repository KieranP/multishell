import Foundation

public struct ProcessOutput: Sendable {
  public let standardOutput: String
  public let standardError: String
  public let status: Int32

  public var succeeded: Bool { status == 0 }
}

public struct ProcessFailure: Error, CustomStringConvertible {
  public let executable: String
  public let arguments: [String]
  public let status: Int32
  public let message: String

  public init(executable: String, arguments: [String], status: Int32, message: String) {
    self.executable = executable
    self.arguments = arguments
    self.status = status
    self.message = message
  }

  public var description: String {
    "\(executable) \(arguments.joined(separator: " ")) failed (\(status)): \(message)"
  }
}

/// Runs a child process and captures its output.
public struct ProcessRunner: Sendable {
  public init() {}

  /// Throws `ProcessFailure` on a non-zero exit.
  public func run(
    _ executable: URL,
    _ arguments: [String],
    in directory: URL,
    environment: [String: String] = [:]
  ) async throws -> String {
    let output = try await capture(executable, arguments, in: directory, environment: environment)
    guard output.succeeded else {
      throw ProcessFailure(
        executable: executable.lastPathComponent,
        arguments: arguments,
        status: output.status,
        message: output.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
      )
    }
    return output.standardOutput
  }

  /// Returns the exit status instead of throwing.
  public func capture(
    _ executable: URL,
    _ arguments: [String],
    in directory: URL,
    environment: [String: String] = [:]
  ) async throws -> ProcessOutput {
    try await Task.detached {
      try invoke(executable, arguments, in: directory, environment: environment)
    }.value
  }
}

private func invoke(
  _ executable: URL,
  _ arguments: [String],
  in directory: URL,
  environment: [String: String]
) throws -> ProcessOutput {
  let process = Process()
  process.executableURL = executable
  process.arguments = arguments
  process.currentDirectoryURL = directory
  if !environment.isEmpty {
    process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
  }

  let outPipe = Pipe()
  let errPipe = Pipe()
  process.standardOutput = outPipe
  process.standardError = errPipe

  try process.run()

  // Both pipes must drain concurrently: whichever is read second can fill its
  // 64 KiB buffer and block the child forever. Each closure writes its own
  // variable and `group.wait()` orders those writes before the reads below.
  nonisolated(unsafe) var outData = Data()
  nonisolated(unsafe) var errData = Data()
  let group = DispatchGroup()
  let queue = DispatchQueue(label: "io.multishell.process", attributes: .concurrent)
  queue.async(group: group) { outData = outPipe.fileHandleForReading.readDataToEndOfFile() }
  queue.async(group: group) { errData = errPipe.fileHandleForReading.readDataToEndOfFile() }
  group.wait()
  process.waitUntilExit()

  return ProcessOutput(
    standardOutput: String(decoding: outData, as: UTF8.self),
    standardError: String(decoding: errData, as: UTF8.self),
    status: process.terminationStatus
  )
}
