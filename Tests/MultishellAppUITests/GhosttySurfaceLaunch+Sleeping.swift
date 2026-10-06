import Foundation

@testable import MultishellAppUI

extension GhosttySurfaceLaunch {
  static let sleeping = GhosttySurfaceLaunch(
    workingDirectory: NSTemporaryDirectory(), environment: [:], command: "/bin/sleep 60")
}
