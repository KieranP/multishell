# Multishell bash integration, for this app's terminals only: --init-file
# points here, so reproduce a login shell's startup, then add the hooks.
if [ -f /etc/profile ]; then . /etc/profile; fi
_multishell_profiled=0
for _multishell_profile in "$HOME/.bash_profile" "$HOME/.bash_login" "$HOME/.profile"; do
  if [ -f "$_multishell_profile" ]; then . "$_multishell_profile"; _multishell_profiled=1; break; fi
done
unset _multishell_profile
# A login shell reads no .bashrc of its own; the usual profile ends by sourcing
# it. Reading it here as well ran it twice, doubling anything prepended.
if [ "$_multishell_profiled" = 0 ] && [ -f "$HOME/.bashrc" ]; then . "$HOME/.bashrc"; fi
unset _multishell_profiled

if [ -n "${MULTISHELL_SESSION-}" ] && [ -x "__MULTISHELL_HELPER__" ]; then
  _multishell_bin="__MULTISHELL_HELPER__"
  _multishell_agents="__MULTISHELL_AGENTS__"
  _multishell_ran=0
  _multishell_armed=0
  _multishell_started=0
  # Ghostty writes no marks for bash, so all three come from here and ride
  # with the hooks; see Docs/design/terminals.md.
  if [ "${TERM_PROGRAM-}" = ghostty ]; then _multishell_marks=1; else _multishell_marks=0; fi
  # One resident relay rather than the helper launched per report, which
  # cost 9.4 ms a command under bash 3.2; see Docs/design/terminals.md.
  _multishell_relay=0
  # A relay that fails, an older helper or a crash, leaves its lines in the
  # pipe, so they go a helper each from here; see Docs/design/terminals.md.
  _multishell_relay_or_inline() {
    "$_multishell_bin" relay --pid $$ && return
    trap '' HUP TSTP TTIN TTOU
    local kind first second began
    while :; do
      began=$SECONDS
      if IFS=' ' read -r -t 1 kind first second; then
        case "$kind" in
          command-started) "$_multishell_bin" command-started --pid "$first" --command "$second" ;;
          command-finished) "$_multishell_bin" command-finished --exit "$first" --duration "$second" ;;
        esac
      # bash 3.2 gives a timeout EOF's status; only a timeout lets a second pass.
      elif [ "$SECONDS" = "$began" ] || ! kill -0 $$ 2>/dev/null; then
        return
      fi
    done
  }
  # Started in the background of the substitution, which then exits: bash 4.4+
  # sets $! to it, and a bare `wait` would wait on a relay that never ends.
  if { exec 62> >(_multishell_relay_or_inline <&0 >/dev/null 2>&1 &); } 2>/dev/null; then
    _multishell_relay=1
  fi
  # SIGPIPE from a gone relay would kill the shell, so it is ignored around the
  # write and the trap standing then is put back; a failure sends the rest inline.
  _multishell_relayed() {
    [ "$_multishell_relay" = 1 ] || return 1
    local sent=0 theirs
    theirs="$(trap -p PIPE)"
    trap '' PIPE
    printf '%s\n' "$1" 2>/dev/null >&62 || sent=1
    eval "${theirs:-trap - PIPE}"
    [ "$sent" = 0 ] && return 0
    _multishell_relay=0
    exec 62>&-
    return 1
  }
  # Down one pipe or inline, never in the background: the zsh body says why.
  _multishell_command_started() {
    _multishell_ran=1
    _multishell_started=${EPOCHREALTIME:-$SECONDS}
    if [ "$_multishell_marks" = 1 ]; then printf '\033]133;C\007'; fi
    # The program being started, sent only where it is an agent: the words
    # of the line, past any prefix. Docs/design/terminals.md.
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
      "$_multishell_bin" command-started --pid $$ --command "$cmd" >/dev/null 2>&1
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
  # Both halves at the top level of PROMPT_COMMAND: inside a function bash
  # reports no DEBUG trap and puts back the one set, functrace being off.
  _multishell_claim_debug='_multishell_seen_debug="$(trap -p DEBUG)"
_multishell_owns_debug || trap "_multishell_debug" DEBUG'
  _multishell_seen_debug=""
  _multishell_capture_debug "$(trap -p DEBUG)"
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
        "$_multishell_bin" command-finished --exit "$e" --duration "$d" >/dev/null 2>&1
    fi
    # bash does not restore $? between PROMPT_COMMAND entries, and a prompt
    # showing the last exit code reads whatever we left.
    return $e
  }
  _multishell_arm() { _multishell_armed=1; }
  # Prompt start printed, input start on the end of PS1, which is why this
  # runs last of all; see Docs/design/terminals.md.
  _multishell_prompt_marks() {
    [ "$_multishell_marks" = 1 ] || return 0
    printf '\033]133;A;cl=line\007'
    [ -n "${PS1-}" ] || return 0
    case "$PS1" in
      *'133;B'*) ;;
      *) PS1="$PS1"'\[\e]133;B\a\]' ;;
    esac
  }
  trap '_multishell_debug' DEBUG
  case "${PROMPT_COMMAND-}" in
    *_multishell_precmd*) ;;
    *)
      # Before 5.1 bash runs only element 0 of an array, so the scalar form
      # below, which writes element 0, is the one that runs there.
      if [[ "$(declare -p PROMPT_COMMAND 2>/dev/null)" == "declare -a"* ]] &&
        (( BASH_VERSINFO[0] > 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 1) )); then
        PROMPT_COMMAND=(
          _multishell_precmd "${PROMPT_COMMAND[@]}" "$_multishell_claim_debug"
          _multishell_prompt_marks _multishell_arm)
      else
        # Newlines, not `;`: a user value ending in a separator composed to
        # `;;`, which bash refuses, so none of the three ran.
        PROMPT_COMMAND="_multishell_precmd
${PROMPT_COMMAND-}
$_multishell_claim_debug
_multishell_prompt_marks
_multishell_arm"
      fi ;;
  esac
fi
