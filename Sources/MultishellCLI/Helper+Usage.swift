import MultishellCore

extension Helper {
  static let usage = """
    usage:
      multishell state <running|attention|done|error|idle> [--session ID] [--cwd PATH]
                       [--pid PID] [--message TEXT] [--agent ID]
                       [--subagent ID --subagent-phase <started|working|ended>
                        [--subagent-type NAME] [--subagent-parent ID]
                        [--subagent-wakes false]]
                       [--new-turn true] [--shell true] [--resumes true]
                       [--out ID,ID...]
          Report a state for the terminal this runs in. Defaults come from the
          environment the app sets: MULTISHELL_SESSION, MULTISHELL_WORKTREE,
          MULTISHELL_SOCKET, MULTISHELL_APP_PID. The pid defaults to the
          nearest ancestor that is not a shell: the program that ran this, or
          the shell itself when the next ancestor is the app. --agent names
          the agent at the prompt, by catalogue id, so the app can tell an
          agent's pane from a plain shell; the agents' own hooks set it.
          --subagent names a worker the agent has out, so the app can list
          it: started and ended are its ends, working a tool call inside it.
          --subagent-parent names the worker that launched it, which the app
          lists it under.
          --subagent-wakes false marks an end the agent takes no turn over,
          such as a cancelled worker's. --resumes true on a done says the
          agent takes a turn when the work it left out ends, and --out
          lists every worker still out at it, empty for none.
          --new-turn marks the prompt starting a turn, after which no worker
          of the last one is still out. --shell says the injected shell
          integration sent this, which is what may take back the mark a
          command put on a pane; nothing else sets it.
      multishell command-started [--pid N] [--command WORD]
          Report that a foreground command has started (running). For a shell
          preexec hook; pass the shell's pid so the state clears if the shell
          exits without a prompt. --command names the program it runs, its
          first word without a path, which marks the pane where that program
          is an agent nobody has installed hooks for.
      multishell command-finished --exit N [--duration S]
          Report that it finished: done when N is 0 or a signal, failed
          otherwise. For a shell precmd hook; a short duration posts no
          notification.
      multishell relay [--pid N]
          Read `command-started PID WORD` and `command-finished EXIT SECONDS`
          lines from stdin until it closes or process N exits, reporting each
          as the two commands above do. One per bash shell, whose pid is N, so
          a command costs no process launch.
      multishell agent-hook --agent ID
          Read that agent's hook payload from stdin and report the state its
          event stands for. Always exits 0. Known agents:
          \(knownAgentList).
      multishell install-agent-hooks --agent ID [--print]
          Write the hooks into that agent's own file, or print them.
      multishell remove-agent-hooks --agent ID
      multishell --version

    """

  static let knownAgentList = AgentHookCatalogue.integrations.map(\.id).joined(separator: ", ")
}
