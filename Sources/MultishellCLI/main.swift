import Foundation

exit(
  Helper.run(
    Array(CommandLine.arguments.dropFirst()),
    environment: ProcessInfo.processInfo.environment,
    standardInput: FileHandle.standardInput
  ))
