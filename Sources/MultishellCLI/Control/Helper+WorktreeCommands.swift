import Foundation
import MultishellCore

extension Helper {
  static func runWorktrees(
    _ arguments: ArraySlice<String>,
    environment: [String: String],
  ) throws
    -> Int32
  {
    let topic = "worktrees"
    let (words, options) = positionals(arguments.dropFirst())
    switch (arguments.first, words.count) {
    case ("list", 0...1):
      try noOptions(options, topic: topic)
      return try ask(
        .listWorktrees(project: try words.first.map { try projectID($0, topic: topic) }),
        environment: environment,
      )

    case ("add", 2):
      let order = try worktreeOrder(
        branch: words[1],
        project: try projectID(words[0], topic: topic),
        options,
      )
      return try ask(.newWorktree(order), environment: environment, timeout: nil)

    case ("remove", 1):
      let options = try CommandOptions(
        options,
        valued: [],
        flags: ["delete-branch", "force-delete-branch", "force"],
        topic: topic,
      )
      let forcesBranchDeletion = options.has("force-delete-branch")
      let order = WorktreeRemovalOrder(
        worktreeID: try worktreeID(words[0], topic: topic),
        deletesBranch: forcesBranchDeletion || options.has("delete-branch"),
        forcesBranchDeletion: forcesBranchDeletion,
        force: options.has("force"),
      )
      return try ask(.removeWorktree(order), environment: environment, timeout: nil)

    case ("show", 1):
      try noOptions(options, topic: topic)
      return try ask(
        .describeWorktree(id: try worktreeID(words[0], topic: topic)),
        environment: environment,
      )

    case ("rename", 1...2):
      try noOptions(options, topic: topic)
      let name = givenName(in: words)
      return try ask(
        .renameWorktree(id: try worktreeID(words[0], topic: topic), name: name),
        environment: environment,
      )

    case ("select", 1):
      try noOptions(options, topic: topic)
      return try ask(
        .selectWorktree(id: try worktreeID(words[0], topic: topic)),
        environment: environment,
      )

    default:
      throw UsageError("worktrees needs: list, add, show, rename, remove or select", topic: topic)
    }
  }

  private static func worktreeOrder(
    branch: String,
    project: String,
    _ arguments: ArraySlice<String>,
  ) throws -> NewWorktreeOrder {
    let topic = "worktrees"
    let options = try CommandOptions(
      arguments,
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
