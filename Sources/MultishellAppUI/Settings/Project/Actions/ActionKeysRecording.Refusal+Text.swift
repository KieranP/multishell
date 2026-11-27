import MultishellAppCore
import MultishellCore

extension ActionKeysRecording.Refusal {
  var text: String {
    switch self {
    case .refused(let refusal): refusal.text
    case .heldBy(let keys, let holder): t("actions.keys-held", keys.glyphs, holder.menuTitle)
    }
  }
}
