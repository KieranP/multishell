import Foundation

/// Who is in a process group, for the kill that follows a hangup: the pid
/// may have been handed on by then, and only our own group's members are old.
enum ProcessGroup {
  /// Whether the group is still the one hung up at `instant`. A stranger's
  /// has a leader younger than that; ours has an old leader or none.
  static func isStillOurs(hungUpAt instant: timeval, group: pid_t) -> Bool {
    // A child the hangup started is young too, so the leader decides. A leaderless
    // stranger needs a pid wrap and its own leader gone within the grace.
    guard let leader = KernelProcessTable.record(of: group), leader.kp_eproc.e_pgid == group else {
      return kill(-group, 0) == 0
    }
    let started = leader.kp_proc.p_un.__p_starttime
    return (started.tv_sec, started.tv_usec) < (instant.tv_sec, instant.tv_usec)
  }
}
