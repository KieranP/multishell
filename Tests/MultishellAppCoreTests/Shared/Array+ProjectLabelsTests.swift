import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite
struct ArrayProjectLabelsTests {
  @Test func pickerLabelsUseThePathOnlyWhenNamesCollide() {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let projects = [
      Project(path: URL(fileURLWithPath: "\(home)/Work/api")),
      Project(path: URL(fileURLWithPath: "/srv/clients/acme/api")),
      Project(path: URL(fileURLWithPath: "\(home)/Work/web")),
    ]

    let labels = projects.pickerLabels

    #expect(labels[projects[0].id] == "api  (~/Work/api)")
    #expect(labels[projects[1].id] == "api  (/srv/clients/acme/api)")
    #expect(labels[projects[2].id] == "web")
  }

  @Test func aRepeatedProjectDoesNotTrapTheLabels() {
    let project = Project(path: URL(fileURLWithPath: "/repos/demo"))
    let labels = [project, project].pickerLabels
    #expect(labels == [project.id: "demo  (/repos/demo)"])
  }
}
