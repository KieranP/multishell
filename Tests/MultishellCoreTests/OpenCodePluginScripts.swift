@testable import MultishellCore

/// The node modules OpenCodePluginDriver writes beside the plugin.
enum OpenCodePluginScripts {
  static let register = """
    import { register } from "node:module"
    register("./hooks.mjs", import.meta.url)

    """

  static let hooks = """
    export async function resolve(specifier, context, next) {
      if (specifier === "node:child_process") {
        return { url: new URL("./stub.mjs", import.meta.url).href, shortCircuit: true }
      }
      return next(specifier, context)
    }

    """

  /// Helpers exit only once every step has run, so what the plugin queues behind the
  /// first does not hang on a race. The plugin spawns the next from an exit's callback.
  static let stub = """
    let started = 0
    let exited = 0
    let released = false
    let drained
    const held = []
    const settle = () => { if (drained && exited === started) drained() }
    globalThis.releaseHelpers = () => new Promise((resolve) => {
      released = true
      drained = resolve
      for (const exit of held.splice(0)) exit()
      settle()
    })
    export const spawn = (command, args, options) => {
      const id = ++started
      process.stdout.write(JSON.stringify(args) + "\\n")
      if (options && options.env) {
        const { MULTISHELL_SESSION, MULTISHELL_WORKTREE, MULTISHELL_SOCKET, MULTISHELL_APP_PID } = options.env
        const handed = {
          session: MULTISHELL_SESSION || null, worktree: MULTISHELL_WORKTREE || null,
          socket: MULTISHELL_SOCKET || null, app: MULTISHELL_APP_PID || null,
        }
        process.stdout.write(JSON.stringify(handed) + "\\n")
      }
      const exits = []
      const exit = () => setTimeout(() => {
        process.stdout.write(JSON.stringify({ exited: id }) + "\\n")
        exited += 1
        for (const callback of exits) callback(0)
        settle()
      }, 1)
      if (released) exit()
      else held.push(exit)
      return { on: (event, callback) => { if (event === "exit") exits.push(callback) }, unref: () => {} }
    }

    """

  /// Runs the plugin's `setup` against a fake context: hooks are kept to be called,
  /// and the bus queues each event, the next step waiting one turn of the loop.
  static let driver = """
    // A step may run the plugin as the background service does, before it loads.
    const flags = JSON.parse(process.argv[4])
    if (flags.service) process.argv.push("serve", "--service")
    process.env.MULTISHELL_SESSION = "TAB"
    process.env.MULTISHELL_WORKTREE = "/first/tab/worktree"
    process.env.MULTISHELL_SOCKET = "/first/tab/multishell.sock"
    process.env.MULTISHELL_APP_PID = "1"
    const { default: plugin } = await import("./multishell.js")

    // The plugin's one-second bound fires at once, after its second under `realBounds`,
    // or never under `heldBounds`, holding node open while it runs.
    const timeout = globalThis.setTimeout
    globalThis.setTimeout = (callback, delay) => {
      if (delay !== \(OpenCodePlugin.lookupBoundMilliseconds)) return timeout(callback, delay)
      if (flags.heldBounds) return { unref: () => {} }
      const timer = timeout(callback, flags.realBounds ? delay : 0)
      timer.unref = () => timer
      return timer
    }
    const sessions = JSON.parse(process.argv[3])
    const info = (id) => {
      const known = sessions[id]
      if (!known) return undefined
      if (known.unplaced) return { ...known, location: {} }
      return { ...known, location: { directory: known.directory || "/w" } }
    }
    // A `late` answer waits for the step that lets it land.
    let lookups = 0
    const lateAnswers = []
    const get = async ({ sessionID }) => {
      lookups += 1
      const known = sessions[sessionID]
      if (known && known.throws) throw new Error("unreachable")
      if (known && known.hangs) return new Promise(() => {})
      if (known && known.late) return new Promise((resolve) => lateAnswers.push(() => resolve(info(sessionID))))
      return info(sessionID)
    }
    const hooks = {}
    const registered = (name, callback) => {
      hooks[name] = callback
      return { dispose: () => {} }
    }
    const hook = flags.toolHookThrows
      ? (name, callback) => {
        if (name === "execute.before") throw new Error("unknown hook")
        return Promise.resolve(registered(name, callback))
      }
      : async (name, callback) => {
        if (flags.toolHookRejects && name === "execute.before") throw new Error("renamed")
        return registered(name, callback)
      }
    // As OpenCode's: an event waits for the plugin to ask for it, and nothing
    // waits for the plugin to finish with one.
    const queued = []
    let deliver
    let busSignal
    const bus = {
      [Symbol.asyncIterator]() { return this },
      next() {
        if (busSignal && busSignal.aborted) return Promise.resolve({ done: true, value: undefined })
        if (queued.length > 0) return Promise.resolve({ value: queued.shift(), done: false })
        return new Promise((resolve) => { deliver = resolve })
      },
      async return() { return { done: true, value: undefined } },
    }
    const tick = () => new Promise((resolve) => timeout(resolve, 0))
    const publish = async (event) => {
      if (deliver) {
        const next = deliver
        deliver = undefined
        next({ value: event, done: false })
      } else queued.push(event)
      await tick()
    }
    // After the bounds already begun have run out, so the answer lands late.
    const answerLateLookups = async () => {
      await tick()
      for (const answer of lateAnswers.splice(0)) answer()
      await tick()
    }
    let cleanup
    try {
      cleanup = await plugin.setup({
        location: { directory: "/w", project: { directory: "/w" } },
        session: { hook, get },
        tool: { hook },
        event: { subscribe: ({ signal }) => { busSignal = signal; return bus } },
      })
    } catch {}
    for (const step of JSON.parse(process.argv[2])) {
      if (step.hook === "answerLateLookups") await answerLateLookups()
      else if (step.hook === "event") await publish(step.event)
      else if (step.isUnawaited) hooks[step.hook](step.input)
      else {
        await hooks[step.hook](step.input)
        await tick()
      }
    }
    await tick()
    await globalThis.releaseHelpers()
    if (cleanup) await cleanup()
    process.stdout.write(JSON.stringify({ lookups }) + "\\n")

    """
}
