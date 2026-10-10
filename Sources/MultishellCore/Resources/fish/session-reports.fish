# The functions init.fish installs where the app gave the session its id:
# what it is told of each command. Docs/design/agents.md.

# Inline, so a finished never overtakes its started; agents.md. Checked per
# send: fish names a missing helper on stderr past any redirect.
function _multishell_send
    test -x $_multishell_bin; and $_multishell_bin $argv >/dev/null 2>&1
end

function _multishell_preexec --on-event fish_preexec
    # The program being started, sent only where it is an agent: the line's
    # words as fish splits them, past any prefix. Docs/design/agents.md.
    set -l words
    printf '%s' $argv[1] | read --null --tokenize --list --local words
    set -l cmd ""
    for word in $words
        switch $word
            case '*=*' command env exec
                continue
        end
        set cmd (string replace --regex '.*/' '' -- $word)
        break
    end
    contains -- "$cmd" $_multishell_agents; or set cmd ""

    _multishell_send command-started --pid $fish_pid --command "$cmd"
end

function _multishell_postexec --on-event fish_postexec
    set -l e $status
    # The helper takes seconds, and fish counts whole milliseconds.
    set -l ms (string pad --char 0 --width 4 -- $CMD_DURATION)
    set -l duration (string sub --end -3 -- $ms).(string sub --start -3 -- $ms)

    _multishell_send command-finished --exit $e --duration $duration
end

# Idle on the way out, as zsh ends: `exit 3` reports a failure first.
function _multishell_exit --on-event fish_exit
    _multishell_send state idle --shell true
end
