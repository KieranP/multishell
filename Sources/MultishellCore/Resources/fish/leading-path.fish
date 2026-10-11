# fish's own path_helper read put /etc/paths ahead of the helper's directory,
# so `multishell` reached another build's; ours go back in front. terminals.md.
if test -n "$MULTISHELL_LEADING_PATH"
    set -l _multishell_lead (string split : -- $MULTISHELL_LEADING_PATH)
    set -l _multishell_rest
    for _multishell_entry in $PATH
        contains -- $_multishell_entry $_multishell_lead
        or set -a _multishell_rest $_multishell_entry
    end
    set -gx PATH $_multishell_lead $_multishell_rest
end
