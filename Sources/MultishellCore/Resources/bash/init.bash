# Multishell's bash integration, read through --init-file: a login shell's
# startup, then the hooks, whose included files the app joins as it writes.
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

if [ "${TERM_PROGRAM-}" = ghostty ]; then
  # Ghostty exports the user's shell-integration-features, `cursor:blink` and all.
  _multishell_has_feature() {
    case ",${GHOSTTY_SHELL_FEATURES-}," in *",$1,"* | *",$1:"*) return 0 ;; esac
    return 1
  }

  # include command-wrappers.bash
fi

if [ -n "${MULTISHELL_SESSION-}" ] && [ -x "__MULTISHELL_HELPER__" ]; then
  _multishell_bin="__MULTISHELL_HELPER__"
  _multishell_agents="__MULTISHELL_AGENTS__"
  _multishell_ran=0
  _multishell_armed=0
  _multishell_started=0
  # The marks are written only in a Ghostty pane; terminal-reports.bash.
  if [ "${TERM_PROGRAM-}" = ghostty ]; then _multishell_marks=1; else _multishell_marks=0; fi

  # include terminal-reports.bash
  # include session-reports.bash

  # One resident relay rather than the helper launched per report, which
  # cost 9.4 ms a command under bash 3.2; see Docs/design/terminals.md.
  _multishell_relay=0
  # Started in the background of the substitution, which then exits: bash 4.4+
  # sets $! to it, and a bare `wait` would wait on a relay that never ends.
  if { exec 62> >(_multishell_relay_or_inline <&0 >/dev/null 2>&1 &); } 2>/dev/null; then
    _multishell_relay=1
  fi

  # Both halves at the top level of PROMPT_COMMAND: inside a function bash
  # reports no DEBUG trap and puts back the one set, functrace being off.
  _multishell_claim_debug='_multishell_seen_debug="$(trap -p DEBUG)"
_multishell_owns_debug || trap "_multishell_debug" DEBUG'
  _multishell_seen_debug=""
  _multishell_capture_debug "$(trap -p DEBUG)"

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
