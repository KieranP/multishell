import TestScratch

/// Everything one interactive shell writes before `exit` reaches it. bash writes its
/// prompt to stderr and zsh to stdout, so the two are read as one.
func interactiveShellOutput(
  _ executable: String,
  arguments: [String],
  environment: [String: String],
  input: String = "true\nexit\n",
) async throws -> String {
  try await Detached.output(
    of: executable,
    arguments,
    environment: environment,
    input: input,
  )
}
