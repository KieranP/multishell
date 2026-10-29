import Foundation
import MultishellCore

extension Helper {
  static func runWorktrees(
    _ arguments: ArraySlice<String>,
    environment: [String: String],
  ) throws
    -> Int32
  {
    let topic = ControlCommand.worktrees.rawValue
    let (words, optionWords) = positionals(arguments.dropFirst())
    switch (arguments.first, words.count) {
    case ("list", 0...1):
      try noOptions(optionWords, topic: topic)
      return try ask(
        .listWorktrees(project: try words.first.map { try projectID($0, topic: topic) }),
        environment: environment,
      )

    case ("add", 2):
      let order = try worktreeOrder(
        branch: words[1],
        project: try projectID(words[0], topic: topic),
        optionWords,
      )
      return try ask(.newWorktree(order), environment: environment, timeout: nil)

    case ("remove", 1):
      let order = try removalOrder(try worktreeID(words[0], topic: topic), optionWords)
      return try ask(.removeWorktree(order), environment: environment, timeout: nil)

    case ("show", 1):
      try noOptions(optionWords, topic: topic)
      return try ask(
        .describeWorktree(id: try worktreeID(words[0], topic: topic)),
        environment: environment,
      )

    case ("rename", 1...2):
      try noOptions(optionWords, topic: topic)
      let name = givenName(in: words)
      return try ask(
        .renameWorktree(id: try worktreeID(words[0], topic: topic), name: name),
        environment: environment,
      )

    case ("select", 1):
      try noOptions(optionWords, topic: topic)
      return try ask(
        .selectWorktree(id: try worktreeID(words[0], topic: topic)),
        environment: environment,
      )

    case ("auto-rename", 1), ("clear-status", 1):
      try noOptions(optionWords, topic: topic)
      let id = try worktreeID(words[0], topic: topic)
      let request: ControlRequest =
        arguments.first == "auto-rename" ? .autoRenameWorktree(id: id) : .clearWorktreeState(id: id)
      return try ask(request, environment: environment)

    case ("resize-groups", 2...):
      try noOptions(optionWords, topic: topic)
      let request = ControlRequest.resizeGroups(
        worktree: try worktreeID(words[0], topic: topic),
        shares: try shares(words.dropFirst(), topic: topic),
      )
      return try ask(request, environment: environment)

    default:
      throw UsageError(
        "worktrees needs: list, add, show, rename, remove, select, auto-rename, clear-status "
          + "or resize-groups",
        topic: topic,
      )
    }
  }

  private static func removalOrder(
    _ id: String,
    _ optionWords: ArraySlice<String>,
  ) throws -> WorktreeRemovalOrder {
    let options = try CommandOptions(
      optionWords,
      valued: [],
      flags: ["delete-branch", "force-delete-branch", "force"],
      topic: ControlCommand.worktrees.rawValue,
    )
    let forcesBranchDeletion = options.has("force-delete-branch")
    return WorktreeRemovalOrder(
      worktreeID: id,
      deletesBranch: forcesBranchDeletion || options.has("delete-branch"),
      forcesBranchDeletion: forcesBranchDeletion,
      force: options.has("force"),
    )
  }

  private static func worktreeOrder(
    branch: String,
    project: String,
    _ optionWords: ArraySlice<String>,
  ) throws -> NewWorktreeOrder {
    let topic = ControlCommand.worktrees.rawValue
    let options = try CommandOptions(
      optionWords,
      valued: ["from", "agent", "prompt"],
      flags: ["existing"],
      topic: topic,
    )
    let createsBranch = !options.has("existing")
    if !createsBranch, options["from"] != nil {
      throw UsageError("--from is where a new branch starts; --existing makes none", topic: topic)
    }
    return NewWorktreeOrder(
      branch: branch,
      projectID: project,
      createsBranch: createsBranch,
      startPoint: options["from"],
      agentID: options["agent"],
      task: options["prompt"],
    )
  }
}
