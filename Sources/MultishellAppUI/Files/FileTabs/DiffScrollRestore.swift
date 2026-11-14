import MultishellCore

/// Where a rebuilt view returns to: a file tab's by the file's line, the All
/// changes tab's by the row its document puts that file's line on.
enum DiffScrollRestore {
  case line(FileTabScroll)
  case row(Double, x: Double)
}
