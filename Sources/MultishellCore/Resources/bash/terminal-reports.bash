# The marks init.bash writes in a Ghostty pane, which writes none for bash,
# so all three come from here and ride with the session's hooks. terminals.md.

# Output start, as a command begins.
_multishell_output_mark() {
  if [ "$_multishell_marks" = 1 ]; then printf '\033]133;C\007'; fi
}

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
