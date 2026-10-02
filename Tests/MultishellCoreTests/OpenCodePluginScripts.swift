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

  /// Helpers exit only once every step has run, so what the plugin queues
  /// behind the first does not hang on a race; each says when it exits.
  static let stub = """
    let started = 0
    let released = false
    const held = []
    globalThis.releaseHelpers = () => {
      released = true
      for (const exit of held.splice(0)) exit()
    }
    export const spawn = (command, args) => {
      const id = ++started
      process.stdout.write(JSON.stringify(args) + "\\n")
      const exits = []
      const exit = () => setTimeout(() => {
        process.stdout.write(JSON.stringify({ exited: id }) + "\\n")
        for (const callback of exits) callback(0)
      }, 1)
      if (released) exit()
      else held.push(exit)
      return { on: (event, callback) => { if (event === "exit") exits.push(callback) }, unref: () => {} }
    }

    """

  static let driver = """
    import { MultishellPlugin } from "./multishell.js"

    // The plugin's one-second bound fires at once and holds node open, a hung
    // lookup leaving nothing else pending; each one begun is counted.
    let waits = 0
    const timeout = globalThis.setTimeout
    globalThis.setTimeout = (callback, delay) => {
      if (delay !== 1000) return timeout(callback, delay)
      waits += 1
      const timer = timeout(callback, 0)
      timer.unref = () => timer
      return timer
    }
    const sessions = JSON.parse(process.argv[3])
    const get = async ({ path }) => {
      if (sessions[path.id] && sessions[path.id].throws) throw new Error("unreachable")
      if (sessions[path.id] && sessions[path.id].hangs) return new Promise(() => {})
      if (sessions[path.id] && sessions[path.id].late) {
        return new Promise((resolve) => timeout(() => resolve({ data: sessions[path.id] }), 20))
      }
      return { data: sessions[path.id] }
    }
    const client = { session: { get } }
    const plugin = await MultishellPlugin({ directory: "/w", worktree: "/w", client })
    for (const step of JSON.parse(process.argv[2])) {
      if (step.hook === "pause") await new Promise((resolve) => timeout(resolve, 100))
      else if (step.hook === "event") await plugin.event({ event: step.event })
      else await plugin[step.hook](step.input, step.output)
    }
    globalThis.releaseHelpers()
    // Long enough for every report the plugin queued to be sent.
    await new Promise((resolve) => timeout(resolve, 300))
    process.stdout.write(JSON.stringify({ waits }) + "\\n")

    """
}
