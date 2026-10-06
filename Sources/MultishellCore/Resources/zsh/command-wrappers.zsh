# sudo and ssh wrapped where the user's shell-integration-features ask, as
# Ghostty's integration would; a function of the user's own is kept.

# sudo empties the environment, and root's terminfo has no xterm-ghostty. sudoedit
# refuses the flag, so an -e or --edit before the command goes on as typed.
if _multishell_has_feature sudo && [[ -n "${TERMINFO-}" ]] && (( ! ${+functions[sudo]} )); then
  function sudo {
    emulate -L zsh
    local word next_is_value=0
    for word in "$@"; do
      if (( next_is_value )); then next_is_value=0; continue; fi
      case "$word" in
        (-e|--edit) command sudo "$@"; return ;;
        (-[CDgpRrTtUu]|--(chdir|chroot|close-from|command-timeout|group|host|other-user|prompt|role|type|user))
          next_is_value=1 ;;
        (--) break ;;
        (-*|*=*) ;;
        (*) break ;;
      esac
    done
    command sudo --preserve-env=TERMINFO "$@"
  }
fi

# A host without xterm-ghostty gets a TERM it knows. ssh-terminfo would install
# the entry, through a Ghostty CLI this bundle lacks; terminals.md.
if { _multishell_has_feature ssh-env || _multishell_has_feature ssh-terminfo; } \
  && (( ! ${+functions[ssh]} )); then
  function ssh {
    emulate -L zsh
    local -a options
    _multishell_has_feature ssh-env \
      && options=(-o "SetEnv COLORTERM=truecolor" -o "SendEnv TERM_PROGRAM TERM_PROGRAM_VERSION")
    TERM=xterm-256color command ssh "${options[@]}" "$@"
  }
fi
