extension Workspace {
  /// Worktrees with shells but no port, which the app warns about.
  public var worktreesWithoutPorts: [Worktree] {
    worktrees.filter { !$0.isBare && port(of: $0.id) == nil }
  }

  /// What `MULTISHELL_PORT` says in the worktree, its block's first port, or
  /// `nil` with no block or one the settings moved past the last port.
  public func port(of worktree: Worktree.ID) -> Int? {
    portBlocks[worktree].flatMap { index in
      PortBlock.firstPort(ofBlock: index, start: portBlockStart, size: portBlockSize)
    }
  }

  /// Takes a bare repository's block, having no shells to give a port to, and moves
  /// every other worktree without a port to the lowest free block not `avoiding`.
  mutating func settlePortBlocks(avoiding reserved: Set<Int> = []) {
    for worktree in worktrees where worktree.isBare { portBlocks[worktree.id] = nil }
    var taken = Set(portBlocks.values).union(reserved)
    var next = 0
    for worktree in worktreesWithoutPorts {
      while taken.contains(next) { next += 1 }
      // Each later block ends further on, so none of them fits either.
      guard PortBlock.firstPort(ofBlock: next, start: portBlockStart, size: portBlockSize) != nil
      else { return }
      portBlocks[worktree.id] = next
      taken.insert(next)
    }
  }
}
