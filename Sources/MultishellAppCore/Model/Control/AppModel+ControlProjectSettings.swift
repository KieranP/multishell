import Foundation
import MultishellCore

extension AppModel {
  /// Every key the project's own settings have but the trust answers, which
  /// only the app's own question may give; null follows the global.
  private static var projectSettingKeys: [String] {
    ProjectSettings.CodingKeys.allCases.filter { $0 != .trustDecisions }.map(\.rawValue)
  }

  func replyToReadProjectSettings(of id: String, key: String?) -> ControlReply {
    guard let project = project(withControlID: id) else { return .refused(.noProject(id: id)) }
    let fields = encodedFields(of: ownSettings(of: project))
    guard let key else {
      return .jsonObject(
        Dictionary(
          uniqueKeysWithValues: Self.projectSettingKeys.map { ($0, fields[$0] ?? NSNull()) }
        )
      )
    }
    guard Self.projectSettingKeys.contains(key) else { return .refused(.noSetting(key: key)) }
    return .jsonObject(fields[key] ?? NSNull())
  }

  /// `null` follows the global; else the text as typed where the key takes text,
  /// quotes and all, or as JSON, so `true` and `12` are what they say.
  func replyToWriteProjectSetting(of id: String, _ key: String, _ value: String) -> ControlReply {
    guard let project = project(withControlID: id) else { return .refused(.noProject(id: id)) }
    guard Self.projectSettingKeys.contains(key) else { return .refused(.noSetting(key: key)) }
    let parsed = try? JSONSerialization.jsonObject(
      with: Data(value.utf8),
      options: .fragmentsAllowed,
    )
    let candidates: [Any] = value == "null" ? [NSNull()] : [value, parsed].compactMap(\.self)
    for candidate in candidates {
      if let settings = settings(of: project, with: key, setTo: candidate) {
        setSettings(settings, for: project)
        return .done
      }
    }
    return .refused(.invalidValue(key: key, value: value))
  }

  /// `nil` where decoding dropped or changed the value, a tolerant field
  /// reading a wrong type as unset.
  private func settings(
    of project: Project,
    with key: String,
    setTo value: Any,
  ) -> ProjectSettings? {
    var fields = encodedFields(of: ownSettings(of: project))
    fields[key] = value is NSNull ? nil : value
    guard let data = try? JSONSerialization.data(withJSONObject: fields),
      let settings = try? JSONDecoder().decode(ProjectSettings.self, from: data)
    else { return nil }
    let kept = encodedFields(of: settings)[key]
    let isKept = value is NSNull ? kept == nil : (kept as? NSObject)?.isEqual(value) == true
    return isKept ? settings : nil
  }

  private func encodedFields(of settings: ProjectSettings) -> [String: Any] {
    guard let data = try? JSONEncoder().encode(settings),
      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return [:] }
    return object
  }
}
