/// When the plugin's one-second bound on a lookup runs out under the driver:
/// never means only the lookup it waits on can end the wait.
enum OpenCodePluginBounds {
  case afterASecond
  case atOnce
  case never
}
