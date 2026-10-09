// One string literal, the plugin's whole source.
// swiftlint:disable function_body_length
extension OpenCodePlugin {
  /// The plugin's source, `helperPath` being a JavaScript expression.
  static func javaScript(helperPath: String) -> String {
    """
    // Written by Multishell so its tabs can show what a session is doing.
    // Remove it from Settings > Agents, or delete this file.
    import { spawn } from "node:child_process"
    import { homedir } from "node:os"

    const helper = \(helperPath)

    // What is being asked for, from v2's PermissionRequest: its `tool` is the
    // call's ids, and the permission names the tool.
    const asked = (properties) => {
      if (!properties) return undefined
      const patterns = properties.patterns
      const detail = Array.isArray(patterns) ? patterns.join(" ") : patterns
      const name = typeof properties.permission === "string" ? properties.permission : undefined
      return [name, detail].filter(Boolean).join(" ") || undefined
    }

    export const MultishellPlugin = async ({ directory, worktree, client }) => {
      const cwd = worktree || directory
      // A subagent is a child session, so its events are told by its id.
      // What each runs as is kept from its creation.
      const workers = new Map()
      // The parent's idle arrives in both spellings, so its second Done is no news.
      let lastOwn
      const report = (state, message, worker, newTurn) => {
        if (!worker) {
          if (state === "done" && lastOwn === "done") return
          lastOwn = state
        }
        const args = ["state", state, "--agent", "\(AgentCatalogue.openCodeID)"]
        if (cwd) args.push("--cwd", cwd)
        if (message) args.push("--message", message)
        if (newTurn) args.push("--new-turn", "true")
        // A child ending wakes the parent for a turn, so its Done says what is
        // still out; a report can overtake another, and the list outranks them.
        if (!worker && state === "done") args.push("--resumes", "true", "--out", busy().join(","))
        if (worker) {
          args.push("--subagent", worker.id, "--subagent-phase", worker.phase)
          if (worker.type) args.push("--subagent-type", worker.type)
          if (worker.parent) args.push("--subagent-parent", worker.parent)
          if (worker.wakes === false) args.push("--subagent-wakes", "false")
        }
        send(args)
      }
      // One helper at a time, each once the last has exited: started together
      // they land in either order; see Docs/design/agents.md.
      const pending = []
      let sending = false
      const plain = (args) =>
        args[1] === "running" && !["--subagent", "--new-turn", "--message"].some((flag) => args.includes(flag))
      const send = (args) => {
        // A plain Working behind another says nothing the first will not.
        const last = pending[pending.length - 1]
        if (last && plain(last) && plain(args)) return
        pending.push(args)
        if (!sending) pump()
      }
      const pump = () => {
        const args = pending.shift()
        sending = args !== undefined
        if (!sending) return
        let finished = false
        const next = () => {
          if (finished) return
          finished = true
          clearTimeout(timer)
          pump()
        }
        // A helper that never exits holds the rest no longer than this.
        const timer = setTimeout(next, 2000)
        if (timer.unref) timer.unref()
        try {
          const child = spawn(helper, args, { stdio: "ignore", detached: true })
          child.on("error", next)
          child.on("exit", next)
          child.unref()
        } catch { next() }
      }
      const busy = () => [...workers].filter(([, entry]) => !entry.done).map(([id]) => id)
      const worker = (id, phase) => {
        const entry = workers.get(id)
        return entry && !entry.done ? { id, phase, type: entry.type, parent: entry.parent } : undefined
      }
      // A child's id is kept past its end, so a late event of its own is not
      // read as the parent's; only a busy status puts it back on the roster.
      const ended = []
      const finish = (id) => {
        const entry = workers.get(id)
        if (!entry || entry.done) return
        entry.done = true
        // One place per child, so a child going busy and idle over and over
        // neither grows the list nor pushes other children's ids out of it.
        const seen = ended.indexOf(id)
        if (seen >= 0) ended.splice(seen, 1)
        ended.push(id)
        while (ended.length > 64) {
          const old = ended.shift()
          const value = workers.get(old)
          // Busy again since it ended: it stays in the map, and it is off the
          // list until its next end puts it back.
          if (value && value.done) workers.delete(old)
        }
      }
      // A task resumed by its id reuses its session and announces nothing, so
      // an id the map lacks is asked about once. Any failure leaves it the parent's.
      const lookups = new Map()
      // Bounded, so a server slow to answer holds no hook of OpenCode's.
      const within = (promise) => new Promise((resolve) => {
        const timer = setTimeout(() => resolve(null), 1000)
        if (timer.unref) timer.unref()
        promise.then((value) => { clearTimeout(timer); resolve(value) })
      })
      // A child of a child is listed under it; a child of this session is not.
      const parentWorkerID = (parentID) => (workers.has(parentID) ? parentID : undefined)
      const adopt = (id, session, agent) => {
        if (!session || !session.parentID || workers.has(id)) return
        lookups.delete(id)
        const type = agent || session.agent
        const parent = parentWorkerID(session.parentID)
        workers.set(id, { type, parent })
        report("running", undefined, { id, phase: "started", type, parent })
      }
      // Every hook shares the first one's bound, so a lookup that never settles
      // holds only that second; one landing after it still puts a child back.
      const recognise = async (id, agent) => {
        if (!id || workers.has(id)) return
        if (!lookups.has(id)) {
          const asked = Promise.resolve()
            .then(() => client.session.get({ path: { id } }))
            .then((answer) => (answer && answer.data) || null, () => null)
          asked.then((session) => adopt(id, session, agent))
          lookups.set(id, within(asked))
        }
        await lookups.get(id)
      }
      const under = (id, newTurn) => {
        const child = worker(id, "working")
        if (child) report("running", undefined, child)
        else if (!workers.has(id)) report("running", undefined, undefined, newTurn)
      }
      return {
        // A parent's prompt starts a turn unless OpenCode sent it over a child's end,
        // and one naming no session starts none; a child's is its work (agents.md).
        "chat.message": async (input, output) => {
          const message = output && output.message
          const id = (input && input.sessionID) || (message && message.sessionID)
          if (!id) return report("running")
          await recognise(id, input && input.agent)
          const parts = (output && output.parts) || []
          under(id, !(parts.length > 0 && parts.every((part) => part && part.synthetic)))
        },
        "tool.execute.before": async (input) => {
          const id = input && input.sessionID
          await recognise(id)
          under(id, false)
        },
        // Not permission.ask: uncalled since the 1.1 permissions rewrite,
        // and it would report a prompt the bus already reports.
        event: async ({ event }) => {
          const properties = event.properties || {}
          const info = properties.info
          // session.idle is deprecated in favour of session.status, so an end
          // is taken from either, in the parent as in a child.
          const status = event.type === "session.status" && properties.status && properties.status.type
          const idle = event.type === "session.idle" || status === "idle"
          if (event.type !== "session.created") await recognise(properties.sessionID)
          // Not a second start for a child a lookup already put back.
          if (event.type === "session.created" && info && info.parentID && !workers.has(info.id)) {
            const parent = parentWorkerID(info.parentID)
            workers.set(info.id, { type: info.agent, parent })
            report("running", undefined, { id: info.id, phase: "started", type: info.agent, parent })
          } else if (workers.has(properties.sessionID)) {
            const id = properties.sessionID
            if (idle || event.type === "session.error") {
              const child = worker(id, "ended")
              if (child) {
                // A cancelled background child is reported to nobody, so no turn follows.
                const error = properties.error
                if (error && error.name === "MessageAbortedError") child.wakes = false
                report("running", undefined, child)
                finish(id)
              }
              return
            }
            if (status === "busy") workers.get(id).done = false
            const child = worker(id, "working")
            if (!child) return
            if (status === "busy") report("running", undefined, child)
            // A child's permission is a prompt of that worker's.
            else if (event.type === "permission.asked") report("attention", asked(properties), child)
            else if (event.type === "permission.replied") report("running", undefined, child)
          } else if (idle) report("done")
          // A turn that never passed chat.message still ends in a Done of its own.
          else if (status === "busy") lastOwn = undefined
          else if (event.type === "session.error") report("error")
          else if (event.type === "permission.asked") report("attention", asked(properties))
          else if (event.type === "permission.replied") report("running")
        },
      }
    }

    """
  }
}
// swiftlint:enable function_body_length
