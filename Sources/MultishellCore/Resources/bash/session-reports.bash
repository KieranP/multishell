# The functions init.bash installs in a session: what the app is told of each
# command through the helper. Docs/design/agents.md.

# A line the relay would carry, `kind first second`, as the helper's own argv.
_multishell_run_helper() {
  case "$1" in
    command-started) "$_multishell_bin" command-started --pid "$2" --command "$3" ;;
    command-finished) "$_multishell_bin" command-finished --exit "$2" --duration "$3" ;;
  esac
}

# A relay that fails, an older helper or a crash, leaves its lines in the
# pipe, so they go a helper each from here; see Docs/design/terminals.md.
_multishell_relay_or_inline() {
  "$_multishell_bin" relay --pid $$ && return
  trap '' HUP TSTP TTIN TTOU
  local kind first second began
  while :; do
    began=$SECONDS
    if IFS=' ' read -r -t 1 kind first second; then
      _multishell_run_helper "$kind" "$first" "$second"
    # bash 3.2 gives a timeout EOF's status; only a timeout lets a second pass.
    elif [ "$SECONDS" = "$began" ] || ! kill -0 $$ 2>/dev/null; then
      return
    fi
  done
}

# bash 5.3 captures output without a fork; older ones pay one per report.
if (( BASH_VERSINFO[0] > 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 3) )); then
  _multishell_read_pipe_trap='theirs=${ trap -p PIPE; }'
else
  _multishell_read_pipe_trap='theirs="$(trap -p PIPE)"'
fi

# SIGPIPE from a gone relay would kill the shell, so it is ignored around the
# write and the trap standing then is put back; a failure sends the rest inline.
_multishell_relayed() {
  [ "$_multishell_relay" = 1 ] || return 1
  local sent=0 theirs
  eval "$_multishell_read_pipe_trap"
  trap '' PIPE
  printf '%s\n' "$1" 2>/dev/null >&62 || sent=1
  eval "${theirs:-trap - PIPE}"
  [ "$sent" = 0 ] && return 0

  _multishell_relay=0
  exec 62>&-
  return 1
}

# Down one pipe or inline, never in the background: session-reports.zsh says why.
_multishell_command_started() {
  _multishell_ran=1
  _multishell_started=${EPOCHREALTIME:-$SECONDS}
  _multishell_output_mark

  # The program being started, sent only where it is an agent: the words
  # of the line, past any prefix. Docs/design/agents.md.
  local line="$1" cmd=""
  while [ -n "$line" ]; do
    cmd="${line%% *}"
    case "$cmd" in
      ""|*=*|command|env|exec) ;;
      *) break ;;
    esac
    cmd=""
    case "$line" in
      *" "*) line="${line#* }" ;;
      *) line="" ;;
    esac
  done
  cmd="${cmd##*/}"
  case " $_multishell_agents " in
    (*" $cmd "*) ;;
    (*) cmd="" ;;
  esac

  _multishell_relayed "command-started $$ $cmd" ||
    _multishell_run_helper command-started $$ "$cmd" >/dev/null 2>&1
}

# A bare `trap ... DEBUG` replaces the one .bashrc installed, silencing
# Atuin and bash-preexec. Theirs is kept, quoted as `trap -p` prints it.
_multishell_capture_debug() {
  local body
  case "$1" in
    "trap -- "*" DEBUG")
      body="${1#trap -- }"
      body="${body% DEBUG}"
      # `trap -p` prints the body quoted for re-input. The quotes come off
      # here, or `eval` runs the whole of it as one word and finds nothing.
      eval "_multishell_prior_debug=$body" ;;
    *) _multishell_prior_debug="" ;;
  esac
}

# bash-preexec, which Atuin ships, installs its trap at the first prompt,
# long after this file ran. Whether ours still stands is asked at each one.
_multishell_owns_debug() {
  case "$_multishell_seen_debug" in
    *_multishell_debug*) return 0 ;;
  esac
  _multishell_capture_debug "$_multishell_seen_debug"
  return 1
}

_multishell_debug() {
  # Before theirs is called, so their trap never sees our own prompt
  # functions: without us it would not have.
  case "$BASH_COMMAND" in _multishell_*) return 0 ;; esac
  if [ -n "$_multishell_prior_debug" ]; then eval "$_multishell_prior_debug"; fi

  [ "$_multishell_armed" = 1 ] || return 0
  [ -n "${COMP_LINE-}" ] && return 0
  _multishell_armed=0
  _multishell_command_started "$BASH_COMMAND"
}

_multishell_precmd() {
  local e=$?
  # An empty Enter runs nothing, so the arm would live on into the user's
  # own PROMPT_COMMAND entry and report it as a command.
  _multishell_armed=0

  if [ "$_multishell_ran" = 1 ]; then
    _multishell_ran=0
    # bash 3.2 has no EPOCHREALTIME; SECONDS is enough. Cut at either
    # separator: EPOCHREALTIME writes the locale's, and a comma broke this.
    local now=${EPOCHREALTIME:-$SECONDS}
    now=${now%%[.,]*}
    local began=${_multishell_started%%[.,]*}
    local d=$(( now - began ))
    [ "$d" -ge 0 ] || d=0
    _multishell_relayed "command-finished $e $d" ||
      _multishell_run_helper command-finished "$e" "$d" >/dev/null 2>&1
  fi

  # bash does not restore $? between PROMPT_COMMAND entries, and a prompt
  # showing the last exit code reads whatever we left.
  return $e
}

_multishell_arm() { _multishell_armed=1; }
