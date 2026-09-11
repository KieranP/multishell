import Foundation

/// Where a package target's own resources are at runtime.
///
/// SwiftPM's `Bundle.module` looks beside the executable and in the build
/// directory, not in an app bundle's `Contents/Resources`, which is where
/// `make-app.sh` puts the resource bundles. Try there first; the generated
/// accessor covers `swift test`, the helper and Linux.
///
/// `named` is the bundle SwiftPM writes for the target, `<package>_<target>`,
/// and is checked for `resource` so another bundle of that name is not
/// mistaken for it. A frontend has a catalogue of its own and calls this
/// with its own two names, which is why they are arguments.
public enum PackageBundle {
  public static func holding(
    _ resource: String, withExtension extension: String, named: String, or fallback: Bundle
  ) -> Bundle {
    if let resources = Bundle.main.resourceURL {
      let inApp = resources.appendingPathComponent(named, isDirectory: true)
      if let bundle = Bundle(url: inApp),
        bundle.url(forResource: resource, withExtension: `extension`) != nil
      {
        return bundle
      }
    }
    return fallback
  }
}
