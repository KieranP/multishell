# The functions init.zsh installs in a Ghostty pane, whose own integration is
# off. Why each is as it is: Docs/design/terminals.md.

# Zero where the user turned titles off, as a hook's status is err_exit's.
_multishell_title() {
  _multishell_has_feature title || return 0
  print -rn -- $'\e]2;'"$1"$'\a'
}

# A bar to type in, a block in vi command mode; steady where the user asked.
# A keymap widget of the user's own draws its own cursor, so ours stands back.
_multishell_keymap_cursor() {
  # zsh's options, not the user's: under ksh_arrays the list began at 0.
  emulate -L zsh
  _multishell_has_feature cursor || return 0

  local -a hooks others
  zstyle -a zle-keymap-select widgets hooks
  others=(${hooks:#*:_multishell_keymap_cursor})
  (( $#others )) && return 0

  local -i shape=5
  [[ "${KEYMAP-}" == vicmd ]] && shape=1
  _multishell_has_feature cursor:steady && (( shape++ ))
  print -n -- $'\e['"$shape"$' q'
}

# Raw, as percent-encoding overran Ghostty's 2 KB buffer; a control
# character could end the sequence early, so that path goes unreported.
_multishell_report_directory() {
  # Not from a subshell, whose output `$(cd x; pwd)` would capture.
  (( _multishell_prompted && ! ZSH_SUBSHELL )) || return 0
  [[ "$PWD" == *[[:cntrl:]]* ]] && return 0
  print -rn -u $_multishell_tty_fd -- $'\e]7;kitty-shell-cwd://'"${HOST-}$PWD"$'\a'
}

# Put back on every prompt, as a framework rebuilds PS1.
_multishell_prompt_click() {
  # A prompt that does not take `%{ %}` would show the escape instead.
  [[ -o prompt_percent ]] || return 0
  [[ "$PS1" == *"$_multishell_prompt_mark"* ]] || PS1="$_multishell_prompt_mark$PS1"
  [[ "$PS1" == *$'\e]133;B\a'* ]] && return 0
  # A trailing bare `%` would join the mark's `%{` into a literal percent.
  [[ "$PS1" == *[^%]% || "$PS1" == % ]] && PS1="$PS1%"
  PS1="$PS1$_multishell_input_mark"
}

_multishell_terminal_precmd() {
  local e=$?
  _multishell_prompted=1
  (( _multishell_owes_command_end )) && print -n -- $'\e]133;D;'"$e"$'\a'
  _multishell_owes_command_end=0

  _multishell_report_directory
  # A deep directory as `…/` and its last three parts, as Ghostty titles it.
  _multishell_title "${(%):-%(4~|…/%3~|%~)}"
  _multishell_keymap_cursor
}

# Not before a first prompt: `zsh -i script` runs this for every line.
_multishell_terminal_preexec() {
  (( _multishell_prompted )) || return 0
  _multishell_owes_command_end=1

  _multishell_has_feature cursor && print -n -- $'\e[0 q'
  local line="${1%%$'\n'*}"
  _multishell_title "${line//[[:cntrl:]]/}"
  print -n -- $'\e]133;C\a'
}
