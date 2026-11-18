/// The button beside a notice in the All changes tab: the file's own tab where
/// that shows what the notice cannot, else the editor, as a file tab offers it.
public enum AllChangesNoticeAction: Hashable, Sendable {
  case openFile
  case openInEditor
}
