# sudo and ssh wrapped where the user's shell-integration-features ask, as
# Ghostty's integration would; a function of the user's own is kept.

# sudo empties the environment, and root's terminfo has no xterm-ghostty. sudoedit
# refuses the flag, so an -e or --edit before the command goes on as typed.
if _multishell_has_feature sudo; and test -n "$TERMINFO"; and not functions -q sudo
    function sudo --wraps sudo
        set -l next_is_value 0
        for word in $argv
            if test $next_is_value = 1
                set next_is_value 0
                continue
            end
            switch $word
                case --edit
                    command sudo $argv
                    return
                case --chdir --chroot --close-from --command-timeout --group --host \
                    --other-user --prompt --role --type --user
                    set next_is_value 1
                case --
                    break
                case '--*' '*=*'
                case '-*'
                    # Short flags bundle, `-ke`; the rest of the word after one taking a value is that value.
                    set -l flags (string sub -s 2 -- $word | string replace -r '[CDgpRrTtUu].*$' '')
                    if string match -q '*e*' -- "$flags"
                        command sudo $argv
                        return
                    end
                    test (string length -- $word) -eq (math (string length -- "$flags") + 2)
                    and set next_is_value 1
                case '*'
                    break
            end
        end
        command sudo --preserve-env=TERMINFO $argv
    end
end

# A host without xterm-ghostty gets a TERM it knows. ssh-terminfo would install
# the entry via a Ghostty CLI this bundle lacks; terminals/shell-integration.md.
if begin
        _multishell_has_feature ssh-env; or _multishell_has_feature ssh-terminfo
    end; and not functions -q ssh
    function ssh --wraps ssh
        # SendEnv: ssh keeps the first SetEnv it reads, and ours would drop the user's.
        if _multishell_has_feature ssh-env
            COLORTERM=truecolor TERM=xterm-256color command ssh \
                -o "SendEnv COLORTERM TERM_PROGRAM TERM_PROGRAM_VERSION" $argv
        else
            TERM=xterm-256color command ssh $argv
        end
    end
end
