import AppKit
import GhosttyKit

/// What a surface's shell starts with. libghostty copies it during
/// `ghostty_surface_new`, so the C strings need live only for that call.
struct GhosttySurfaceLaunch {
  var workingDirectory: String
  var environment: [String: String]
  /// One shell command line, which libghostty hands to the login shell.
  var command: String?

  func withCConfig<Result>(
    view: NSView, scale: Double, _ body: (inout ghostty_surface_config_s) -> Result
  ) -> Result {
    let variables = environment.sorted { $0.key < $1.key }
    let strings =
      [workingDirectory] + variables.flatMap { [$0.key, $0.value] } + [command].compactMap(\.self)
    return CStrings.with(strings) { pointers in
      let view = Unmanaged.passUnretained(view).toOpaque()
      var config = ghostty_surface_config_new()
      config.platform_tag = GHOSTTY_PLATFORM_MACOS
      config.platform = ghostty_platform_u(macos: ghostty_platform_macos_s(nsview: view))
      config.userdata = view
      config.scale_factor = scale
      config.context = GHOSTTY_SURFACE_CONTEXT_WINDOW
      config.working_directory = pointers[0]
      config.command = command == nil ? nil : pointers.last
      var pairs = variables.indices.map {
        ghostty_env_var_s(key: pointers[1 + 2 * $0], value: pointers[2 + 2 * $0])
      }
      return pairs.withUnsafeMutableBufferPointer { buffer in
        config.env_vars = buffer.baseAddress
        config.env_var_count = buffer.count
        return body(&config)
      }
    }
  }
}
