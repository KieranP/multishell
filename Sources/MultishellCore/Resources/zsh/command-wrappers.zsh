# sudo and ssh wrapped where the user's shell-integration-features ask, as
# Ghostty's integration would; a function of the user's own is kept.

# sudo empties the environment, and root's terminfo has no xterm-ghostty. sudoedit
# refuses the flag, so an -e or --edit before the command goes on as typed.
if _multishell_has_feature sudo && [[ -n "${TERMINFO-}" ]] && (( ! ${+functions[sudo]} )); then
  function sudo {
    emulate -L zsh
    local word flags next_is_value=0
    for word in "$@"; do
      if (( next_is_value )); then next_is_value=0; continue; fi
      case "$word" in
        (--edit) command sudo "$@"; return ;;
        (--(chdir|chroot|close-from|command-timeout|group|host|other-user|prompt|role|type|user))
          next_is_value=1 ;;
        (--) break ;;
        (-[^-]*)
          # Short flags bundle, `-ke`; the rest of the word after one taking a value is that value.
          flags=${${word#-}%%[CDgpRrTtUu]*}
          if [[ $flags == *e* ]]; then command sudo "$@"; return; fi
          (( ${#word} == ${#flags} + 2 )) && next_is_value=1 ;;
        (-*|*=*) ;;
        (*) break ;;
      esac
    done
    command sudo --preserve-env=TERMINFO "$@"
  }
fi

# A host without xterm-ghostty gets a TERM it knows. ssh-terminfo would install
# the entry via a Ghostty CLI this bundle lacks; terminals/shell-integration.md.
if { _multishell_has_feature ssh-env || _multishell_has_feature ssh-terminfo; } \
  && (( ! ${+functions[ssh]} )); then
  function ssh {
    emulate -L zsh
    # SendEnv: ssh keeps the first SetEnv it reads, and ours would drop the user's.
    if _multishell_has_feature ssh-env; then
      COLORTERM=truecolor TERM=xterm-256color command ssh \
        -o "SendEnv COLORTERM TERM_PROGRAM TERM_PROGRAM_VERSION" "$@"
    else
      TERM=xterm-256color command ssh "$@"
    fi
  }
fi
