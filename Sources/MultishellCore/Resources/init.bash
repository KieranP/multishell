# Multishell bash integration, for this app's terminals only. bash was
# launched with --init-file pointing here, so reproduce a login shell's
# startup, then add the command-status hooks.
if [ -f /etc/profile ]; then . /etc/profile; fi
for _multishell_profile in "$HOME/.bash_profile" "$HOME/.bash_login" "$HOME/.profile"; do
  if [ -f "$_multishell_profile" ]; then . "$_multishell_profile"; break; fi
done
unset _multishell_profile
# In case the profile did not already source it.
if [ -f "$HOME/.bashrc" ]; then . "$HOME/.bashrc"; fi

if [ -n "${MULTISHELL_SESSION-}" ] && [ -x "__MULTISHELL_HELPER__" ]; then
  _multishell_bin="__MULTISHELL_HELPER__"
  _multishell_ran=0
  _multishell_armed=0
  _multishell_started=0
  # Ghostty writes no OSC 133 marks for bash — it refuses Apple's bash 3.2
  # outright, and our launch through `sh` hides the rest — so a click in the
  # prompt has nothing to land in unless they are written here. They ride with
  # the hooks because C comes off the same DEBUG trap, and a prompt marked
  # without C would answer a click while a program was still running.
  if [ "${TERM_PROGRAM-}" = ghostty ]; then _multishell_marks=1; else _multishell_marks=0; fi
  # Inline, not in the background, for the same reasons as the zsh body.
  _multishell_command_started() {
    _multishell_ran=1
    _multishell_started=${EPOCHREALTIME:-$SECONDS}
    if [ "$_multishell_marks" = 1 ]; then printf '\033]133;C\007'; fi
    "$_multishell_bin" command-started --pid $$ >/dev/null 2>&1
  }
  _multishell_debug() {
    [ "$_multishell_armed" = 1 ] || return 0
    [ -n "${COMP_LINE-}" ] && return 0
    _multishell_armed=0
    case "$BASH_COMMAND" in _multishell_*) return 0 ;; esac
    _multishell_command_started
  }
  _multishell_precmd() {
    local e=$?
    if [ "$_multishell_ran" = 1 ]; then
      _multishell_ran=0
      # bash 3.2 has no EPOCHREALTIME; SECONDS is whole seconds, enough.
      # The fraction is cut at either separator: EPOCHREALTIME writes the
      # locale's, so a comma region left the whole string in the arithmetic.
      local now=${EPOCHREALTIME:-$SECONDS}
      now=${now%%[.,]*}
      local began=${_multishell_started%%[.,]*}
      local d=$(( now - began ))
      [ "$d" -ge 0 ] || d=0
      "$_multishell_bin" command-finished --exit "$e" --duration "$d" >/dev/null 2>&1
    fi
  }
  _multishell_arm() { _multishell_armed=1; }
  # The prompt says a click in it may be answered with arrow keys: `cl=line`
  # is one per cell, which readline honours. Prompt start is printed rather
  # than put in PS1, because it moves to a fresh line when a command left the
  # cursor mid-line, and inside PS1 that would be a line readline had been
  # told costs nothing, leaving it editing at the wrong column. Input start
  # rides on the end of PS1 instead, where a redraw writes it again, and is
  # put back after any framework has rebuilt PS1 from a PROMPT_COMMAND of its
  # own, which is why this runs last of all.
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
      if [[ "$(declare -p PROMPT_COMMAND 2>/dev/null)" == "declare -a"* ]]; then
        PROMPT_COMMAND=(
          _multishell_precmd "${PROMPT_COMMAND[@]}" _multishell_prompt_marks _multishell_arm)
      else
        PROMPT_COMMAND="_multishell_precmd${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
        PROMPT_COMMAND="$PROMPT_COMMAND; _multishell_prompt_marks; _multishell_arm"
      fi ;;
  esac
fi
