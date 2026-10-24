/// Each agent's one-shot run, read from its own `--help` and model list on
/// 2026-10-24; see Docs/design/agents.md for each choice.
extension AgentCatalogue {
  private static let claudeEfforts = ["low", "medium", "high", "xhigh", "max"]
  private static let copilotEfforts = ["none", "minimal", "low", "medium", "high", "xhigh", "max"]
  private static let codexEfforts = ["low", "medium", "high", "xhigh", "max"]

  // Aliases follow each release. No MCP server, and user settings only: `-p`
  // skips the trust prompt a repository's hooks wait behind. See agents.md.
  static let claudeOneShot = AgentOneShot(
    leadingArguments: [
      "-p", "--no-session-persistence", "--strict-mcp-config", "--setting-sources", "user",
      "--tools", "",
    ],
    promptArgument: .operand,
    models: ["fable", "opus", "sonnet", "haiku"].map { AgentModel($0, efforts: claudeEfforts) },
    effortFlag: AgentOption(name: "--effort"),
  )

  // The models `codex debug models` lists as visible, with each one's efforts.
  // The sandbox holds only its shell, so the user's MCP servers are emptied.
  static let codexOneShot = AgentOneShot(
    leadingArguments: [
      "exec", "--sandbox", "read-only", "--ephemeral", "--color", "never", "-c", "mcp_servers={}",
    ],
    promptArgument: .operand,
    models: [
      AgentModel("gpt-6.1-sol", efforts: codexEfforts + ["ultra"]),
      AgentModel("gpt-6-sol", efforts: codexEfforts + ["ultra"]),
      AgentModel("gpt-6-astra", efforts: codexEfforts + ["ultra"]),
      AgentModel("gpt-6-luna", efforts: codexEfforts),
      AgentModel("gpt-5.6-sol", efforts: codexEfforts + ["ultra"]),
      AgentModel("gpt-5.6-terra", efforts: codexEfforts + ["ultra"]),
      AgentModel("gpt-5.6-luna", efforts: codexEfforts),
      AgentModel("gpt-5.5", efforts: ["low", "medium", "high", "xhigh"]),
    ],
    effortFlag: AgentOption(name: "-c", valuePrefix: "model_reasoning_effort="),
  )

  // Gemini's own aliases; its thinking budget is a setting, not a flag.
  static let geminiOneShot = AgentOneShot(
    leadingArguments: ["--approval-mode", "plan"],
    promptArgument: .option("--prompt"),
    models: ["pro", "flash", "flash-lite"].map { AgentModel($0) },
  )

  // Copilot 1.0.98's `help config` list. Its effort flag names one set for
  // every model, so each is offered them all.
  static let copilotOneShot = AgentOneShot(
    leadingArguments: [
      "--silent", "--no-ask-user", "--disable-builtin-mcps", "--deny-tool=shell",
      "--deny-tool=write",
    ],
    promptArgument: .option("--prompt"),
    models: [
      "claude-sonnet-5.5", "claude-sonnet-5", "claude-fable-5.1", "claude-fable-5",
      "claude-opus-5.5", "claude-opus-5", "claude-opus-4.8", "claude-opus-4.8-fast",
      "claude-sonnet-4.6", "claude-haiku-5.5", "claude-haiku-4.5", "gpt-6.1-sol", "gpt-6-sol",
      "gpt-6-luna", "gpt-6-astra", "gpt-5.6-sol", "gpt-5.6-terra", "gpt-5.6-luna", "gpt-5.5",
      "gpt-5.4", "gpt-5.4-mini", "gpt-5.3-codex", "gpt-5-mini", "mai-code-1.1-flash",
      "gemini-4-argon", "gemini-3.8-flash", "gemini-3.7-flash", "grok-4.7", "grok-4.6",
      "grok-4.5", "kimi-k3",
    ].map { AgentModel($0, efforts: copilotEfforts) },
    effortFlag: AgentOption(name: "--reasoning-effort"),
  )

  // `--standalone`, or the background service runs it without this environment;
  // a repository's own config and plugins are not loaded. See agents.md.
  static let openCodeOneShot = AgentOneShot(
    leadingArguments: ["run", "--standalone"],
    promptArgument: .operand,
    models: [
      "anthropic/claude-fable-5-1", "anthropic/claude-opus-5-5", "anthropic/claude-sonnet-5-5",
      "anthropic/claude-haiku-5-5", "openai/gpt-6.1-sol", "openai/gpt-6-astra",
      "openai/gpt-6-luna", "openai/gpt-5.6-luna", "google/gemini-4-argon",
      "google/gemini-3.8-flash", "google/gemini-3.5-flash-lite",
    ].map { AgentModel($0) },
    environment: [
      "OPENCODE_CONFIG_CONTENT": #"{"permission":"deny"}"#,
      "OPENCODE_DISABLE_PROJECT_CONFIG": "1",
    ],
  )
}
