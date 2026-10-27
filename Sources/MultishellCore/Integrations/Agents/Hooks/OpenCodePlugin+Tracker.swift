extension OpenCodePlugin {
  /// The sessions reported here, and the ended children, the tracker remembers,
  /// the service running for days.
  private static let reportedSessionLimit = 512
  static let endedChildLimit = 64

  /// What a session is doing, as the plugin's hooks and events tell it.
  static let tracker = """
    // What this directory's sessions are doing, from plain calls the hooks and
    // events make, sent through `send`.
    const tracker = ({ cwd, send }) => {
      // A subagent is a child session, so its events are told by its id.
      // What each runs as is kept from its creation.
      const workers = new Map()
      // `session` is the session a Done is its own for, which lists its own out.
      const report = (state, message, worker, newTurn, session) => {
        const args = ["state", state, "--agent", "\(AgentCatalogue.openCodeID)"]
        if (cwd) args.push("--cwd", cwd)
        if (message) args.push("--message", message)
        if (newTurn) args.push("--new-turn", "true")
        // A child ending wakes the parent for a turn, so its Done says what is
        // still out; a report can overtake another, and the list outranks them.
        if (!worker && state === "done") args.push("--resumes", "true", "--out", out(session).join(","))
        if (worker) {
          args.push("--subagent", worker.id, "--subagent-phase", worker.phase)
          if (worker.type) args.push("--subagent-type", worker.type)
          if (worker.parent) args.push("--subagent-parent", worker.parent)
        }
        send(args)
      }
      // The sessions that have reported here and their last state and message, which a
      // move away must end, a run's start reads and a late answer making one a child reads.
      const reported = latestMap(\(reportedSessionLimit))
      const runEndStates = { succeeded: "done", failed: "error", stopped: "idle" }
      const reportOwn = (id, state, message, newTurn) => {
        if (id) reported.add(id, { state, message })
        report(state, message, undefined, newTurn, id)
      }
      const isAnySessionAsking = () => reported.entries().some(([, own]) => own.state === "attention")
      const lastOwnState = (id) => {
        const own = reported.get(id)
        return own && own.state
      }
      // A session's workers still running, its children's children among them. Under
      // the service every session reports to one worktree roster, so a Done lists all.
      const out = (session) =>
        [...workers]
          .filter(([id, entry]) => !entry.hasEnded && (runsUnderTheService || topLevelSessionOf(id) === session))
          .map(([id]) => id)
      const worker = (id, phase) => {
        const entry = workers.get(id)
        if (!entry || entry.hasEnded) return undefined
        return { id, phase, type: entry.type, parent: parentWorkerID(entry.parentID) }
      }
      // An ended child's id is kept, so its late event is not read as the parent's; one
      // forgotten leaves the roster unless run again, its children passed to its parent.
      const ended = latestMap(\(endedChildLimit), (id) => {
        const entry = workers.get(id)
        if (!entry || !entry.hasEnded) return
        workers.delete(id)
        for (const child of workers.values()) if (child.parentID === id) child.parentID = entry.parentID
      })
      // A child of a child is listed under it; a child of this session is not.
      const parentWorkerID = (parentID) => (workers.has(parentID) ? parentID : undefined)
      const endsRun = (state) => Object.values(runEndStates).includes(state)
      // A child created here, or one a lookup found that its creation did not
      // announce, as a task resumed by its id reuses its session.
      const onChild = (id, parentID, type) => {
        if (!parentID || workers.has(id)) return
        const own = reported.get(id) || {}
        workers.set(id, { type, parentID })
        reported.delete(id)
        const sessionState = lastOwnState(topLevelSessionOf(id))
        // Its run's end, read as its own before an answer past the bound: a session's
        // turn still running is woken by it, a session already Done has had it.
        if (endsRun(own.state) && endsRun(sessionState)) return markEnded(id)
        // A prompt it raised as its own moves to the worker; another still asking keeps
        // the agent's prompt up, as every session's own share it.
        if (own.state === "attention" && !isAnySessionAsking()) report("running")
        report("running", undefined, worker(id, "started"))
        if (endsRun(own.state)) endChild(id)
        else if (own.state === "attention") report("attention", own.message, worker(id, "working"))
      }
      // The session's own report, or a live child's; an ended child's says nothing.
      const reportFor = (id, state, message, newTurn) => {
        if (!workers.has(id)) return reportOwn(id, state, message, newTurn)
        const child = worker(id, "working")
        if (child) report(state, message, child)
      }
      // A child's end, as many ways as OpenCode spells one. It wakes the parent,
      // whom OpenCode tells, a cancelled one too, so no end says it wakes nobody.
      const endChild = (id) => {
        if (reportEnd(id)) markEnded(id)
      }
      const reportEnd = (id) => {
        const child = worker(id, "ended")
        if (child) report("running", undefined, child)
        return !!child
      }
      const markEnded = (id) => {
        workers.get(id).hasEnded = true
        ended.add(id)
      }
      // A parent's prompt starts a turn, OpenCode sending none over a child's end,
      // and one naming no session starts none; a child's is its work (agents.md).
      const onPrompt = (id) => reportFor(id, "running", undefined, !!id)
      // No prompt hook stands for the turn a child's end wakes, so its start
      // says Working where the prompt has not.
      const onRunStarted = (id) => {
        if (workers.has(id)) {
          workers.get(id).hasEnded = false
          reportFor(id, "running")
        } else if (lastOwnState(id) !== "running") reportOwn(id, "running")
      }
      // A run's end: a child's is its worker's end, however the run ended.
      const runEnded = (state) => (id, message) => {
        if (workers.has(id)) endChild(id)
        else reportOwn(id, state, message)
      }
      const parentOf = (id) => (workers.has(id) ? workers.get(id).parentID : undefined)
      const topLevelSessionOf = (id) => topLevelOf(id, parentOf)
      const descendantsOf = (id) => [...workers.keys()].filter((child) => ancestorsOf(child, parentOf).includes(id))
      // A session moved to another worktree ends here, however it last stood, and it
      // leaves the roster with its descendants, by the roster or `recordedDescendants`.
      const onMovedAway = (id, hasParent, recordedDescendants) => {
        const recordedOnRoster = recordedDescendants.filter((session) => workers.has(session))
        const leaving = new Set([...descendantsOf(id), ...recordedOnRoster])
        // A top-level session unseen here reported nothing, but the end of any session
        // under it woke its turn; one with a parent woke only its parent's.
        const needsIdle = reported.has(id) || (!hasParent && leaving.size > 0)
        // Dropped outright, a leaving session takes no place among the ended.
        for (const session of [...leaving, id]) {
          reportEnd(session)
          workers.delete(session)
          ended.delete(session)
        }
        reported.delete(id)
        if (needsIdle) report("idle")
      }
      // A child's permission is a prompt of that worker's.
      const onAsked = (id, text) => reportFor(id, "attention", text)
      return {
        isWorker: (id) => workers.has(id),
        hasReported: (id) => reported.has(id),
        parentOf,
        onChild,
        onPrompt,
        onTool: (id) => reportFor(id, "running"),
        onRunStarted,
        onSucceeded: runEnded(runEndStates.succeeded),
        onFailed: runEnded(runEndStates.failed),
        onStopped: runEnded(runEndStates.stopped),
        onAsked,
        onMovedAway,
        onReplied: (id) => reportFor(id, "running"),
      }
    }

    """
}
