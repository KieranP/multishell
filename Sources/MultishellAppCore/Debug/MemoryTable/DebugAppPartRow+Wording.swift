import MultishellCore

extension DebugAppPartRow {
  public var title: String {
    switch part {
    case .gpu: t("debug.app-part.gpu")
    case .heapInUse: t("debug.app-part.heap-in-use")
    case .fileTabs: t("debug.app-part.file-tabs", fileTabCount)
    case .freedHeap: t("debug.app-part.freed-heap")
    case .librariesAndOther: t("debug.app-part.libraries-and-other")
    }
  }
}
