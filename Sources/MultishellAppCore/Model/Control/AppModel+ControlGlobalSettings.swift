import MultishellCore

extension AppModel {
  func replyToReadGlobalSettings(key: String?) -> ControlReply {
    let settings = globalSettings
    guard let key else {
      return .jsonObject(Dictionary(uniqueKeysWithValues: settings.map { ($0.key, $0.read()) }))
    }
    guard let setting = settings.first(where: { $0.key == key }) else {
      return .refused(.noSetting(key: key))
    }
    return .jsonObject(setting.read())
  }

  func replyToWriteGlobalSetting(_ key: String, _ value: String) -> ControlReply {
    guard let setting = globalSettings.first(where: { $0.key == key }) else {
      return .refused(.noSetting(key: key))
    }
    return setting.write(value) ? .done : .refused(.invalidValue(key: key, value: value))
  }
}
