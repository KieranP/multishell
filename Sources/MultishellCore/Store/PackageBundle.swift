import Foundation

/// Where a target's resources are at runtime: `Bundle.module` never looks in
/// `Contents/Resources`. Named by argument, each frontend having its own.
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
