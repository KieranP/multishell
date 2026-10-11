import Foundation

/// The command-line request whose task is running, so an alert made in it is
/// known as that request's rather than guessed from what is on screen after.
enum ControlRequestScope {
  @TaskLocal static var id: UUID?
}
