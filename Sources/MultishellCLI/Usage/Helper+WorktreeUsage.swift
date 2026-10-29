extension Helper {
  static let worktreeUsage = """
    usage: multishell worktrees list [PROJECT_ID]
        Print every worktree, or one project's, as JSON: its id, its
        project's, its name and path.
    usage: multishell worktrees add PROJECT_ID BRANCH [--from REF] [--existing]
                                  [--agent ID] [--prompt TEXT]
        Create a worktree on a new branch, as the New Worktree sheet does,
        and print its id once it exists, however long the hooks take.
        --from REF   start the branch at REF rather than HEAD
        --existing   check out BRANCH, which already exists, instead
        --agent ID   start that agent in the first tab, by catalogue id
        --prompt     give the agent TEXT as its task; without --agent, the
                     project's own agent
        With neither, the first tab follows the project's create settings.
    usage: multishell worktrees remove WORKTREE_ID [--delete-branch]
                                       [--force-delete-branch] [--force]
        Remove it as its row's Remove does, without the dialog, to the Trash
        where the settings say. Refused while an agent in it is working,
        unless --force. --delete-branch deletes its branch too, as
        git branch -d; --force-delete-branch deletes one holding commits no
        other branch has, as git branch -D.
    usage: multishell worktrees show WORKTREE_ID
        Print the worktree as `worktrees list` does, with what its row shows:
        git's status counts and tooltip, read afresh (isStatusFresh false
        where that read failed), the merge badge and the
        branch it landed in, the last commit, and any create or remove stage
        under way or failed, with what the hook or git said.
    usage: multishell worktrees rename WORKTREE_ID [--] [NAME]
        Name its row; no NAME hands the name back to the branch.
    usage: multishell worktrees select WORKTREE_ID
        Select it, as a click on its row does.
    usage: multishell worktrees auto-rename WORKTREE_ID
        Start Auto Rename, as its menu item does, and return once it starts.
        `sidebar list` says while it runs and why it left the name where it
        did. Refused where the item is greyed out.
    usage: multishell worktrees clear-status WORKTREE_ID
        Clear the dots of all its panes, as its Clear Status does.
    usage: multishell worktrees resize-groups WORKTREE_ID SHARE...
        Set its tab groups' shares of the width, left to right, as dragging
        the dividers between them does: one SHARE a group, relative.
        `tabs list` prints them as groupShares.

    """
}
