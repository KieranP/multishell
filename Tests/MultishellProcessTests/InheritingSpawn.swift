import Darwin

/// Starts a program as libghostty starts a pane's shell, with no descriptor
/// sweep, so it inherits every descriptor not marked close-on-exec.
final class InheritingSpawn: Sendable {
  private let pid: pid_t

  init?(_ arguments: [String]) {
    var pid: pid_t = 0
    let argv = arguments.map { strdup($0) } + [nil]
    defer { for argument in argv { free(argument) } }
    guard posix_spawn(&pid, arguments[0], nil, nil, argv, environ) == 0 else { return nil }
    self.pid = pid
  }

  deinit {
    kill(pid, SIGKILL)
    waitpid(pid, nil, 0)
  }
}
