import Foundation
import MultishellCore

extension [Project] {
  /// What a menu of projects lists: a folder name alone, unless another project
  /// shares it, when the path tells them apart.
  public var pickerLabels: [Project.ID: String] {
    var count: [String: Int] = [:]
    for project in self { count[project.name, default: 0] += 1 }
    // Repair keeps identities unique; a repeat here must still not trap.
    return Dictionary(
      keepingFirst:
        map { project in
          let label =
            count[project.name] == 1
            ? project.name
            : "\(project.name)  (\(project.path.path.abbreviatingHomeDirectory()))"
          return (project.id, label)
        }
    )
  }
}
