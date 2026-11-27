import MultishellCore

/// What the trust section says on the page it heads, naming what that page shows.
struct SharedSettingsTrustLines {
  static var hooks: Self {
    Self(
      trusted: t("hooks.shared-run"),
      untrusted: t("hooks.shared-ignored"),
      info: t("hooks.shared-info", SharedProjectSettings.fileName),
    )
  }

  static var actions: Self {
    Self(
      trusted: t("actions.shared-run"),
      untrusted: t("actions.shared-ignored"),
      info: t("actions.shared-info", SharedProjectSettings.fileName),
    )
  }

  let trusted: String
  let untrusted: String
  let info: String
}
