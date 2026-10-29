extension OpenCodePlugin {
  /// Hooks registered on the context's domains, and the bus read through a
  /// subscription.
  static let setup = """
    // What is being asked for: the action and what it would touch.
    const permissionText = (data) => {
      const resources = Array.isArray(data.resources) ? data.resources.join(" ") : data.resources
      const action = typeof data.action === "string" ? data.action : undefined
      return [action, resources].filter(Boolean).join(" ") || undefined
    }

    // A hook that throws fails the user's prompt or tool call, so none may.
    const quietly = (body) => async (input) => {
      try { await body(input || {}) } catch {}
    }

    const setup = async ({ location, session, tool, event }) => {
      // Not the project's directory, which for a linked worktree may be the
      // main checkout; the app finds the worktree holding this one.
      const directory = location.directory
      const track = tracker({ cwd: directory, send: reporter() })
      const sessions = directorySessions({ directory, get: (query) => session.get(query), track })
      // A superseded run's prompt carries on in the next, and a shutdown is the
      // service going, whose pid the app sees gone.
      const interrupted = (id, data) => {
        if (data.reason === "user") track.onStopped(id)
        else if (data.reason === "inactivity") track.onFailed(id)
      }
      const handlers = new Map([
        ["session.execution.started", (id) => track.onRunStarted(id)],
        ["session.execution.succeeded", (id) => track.onSucceeded(id)],
        ["session.execution.failed", (id, data) => track.onFailed(id, data.error && data.error.message)],
        ["session.execution.interrupted", interrupted],
        ["permission.asked", (id, data) => track.onAsked(id, permissionText(data))],
        ["permission.replied", (id) => track.onReplied(id)],
      ])
      const onEvent = async ({ type, data, location: envelope }) => {
        if (type === "session.created") return sessions.onCreated(data)
        if (type === "session.moved") return sessions.onMoved(data)
        const id = data.sessionID
        if (id && (await sessions.locate(id, envelope))) handlers.get(type)(id, data)
      }
      // Each session's hooks and events in the order they came, and none held
      // behind another session's lookup.
      const chains = new Map()
      const enqueue = (id, work) => {
        const handled = (chains.get(id) || Promise.resolve()).then(work).catch(() => {})
        chains.set(id, handled)
        handled.then(() => { if (chains.get(id) === handled) chains.delete(id) })
        return handled
      }
      // Streamed parts and the rest read nothing, so they queue nothing either.
      const placing = new Set(["session.created", "session.moved"])
      const dispatch = (item) => {
        if (!item.data || !(placing.has(item.type) || handlers.has(item.type))) return
        enqueue(item.data.sessionID, () => onEvent(item))
      }
      // Subscribed before the hooks, as the bus replays nothing.
      const controller = new AbortController()
      const stream = event.subscribe({ signal: controller.signal })
      ;(async () => {
        try {
          for await (const item of stream) {
            if (controller.signal.aborted) break
            dispatch(item || {})
          }
        } catch {}
      })()
      // Through a promise, so a registration that throws at once is a rejection too.
      const register = (domain, name, body) => Promise.resolve().then(() => domain.hook(name, quietly(body)))
      // Waited for at most a second, so the report keeps its place among the
      // other sessions' and no slow lookup holds OpenCode's prompt or tool call.
      const hooked = (report) => async ({ sessionID }) => {
        const firedAt = sessions.now()
        await within(enqueue(sessionID, async () => {
          if (await sessions.onNamed(sessionID, firedAt)) report(sessionID)
        }))
      }
      const settled = await Promise.allSettled([
        register(session, "prompt", hooked(track.onPrompt)),
        register(tool, "execute.before", hooked(track.onTool)),
      ])
      const cleanup = () => {
        controller.abort()
        for (const registration of settled) {
          try { if (registration.value && registration.value.dispose) registration.value.dispose() } catch {}
        }
      }
      // OpenCode counts a setup that throws as a failed plugin, so nothing of
      // it may go on reading the bus.
      const failure = settled.find((registration) => registration.status === "rejected")
      if (failure) {
        cleanup()
        throw failure.reason
      }
      return cleanup
    }

    """
}
