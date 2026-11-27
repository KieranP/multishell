import SwiftUI

extension View {
  /// A confirmation dialog shown while `pending` is set. Any dismissal, a button's
  /// included, also answers `dismiss`, so it must be safe beside a button's answer.
  func questionDialog<Pending, Buttons: View>(
    _ pending: Pending?,
    title: (Pending) -> String,
    message: @escaping (Pending) -> String,
    dismiss: @escaping (Pending) -> Void,
    @ViewBuilder buttons: @escaping (Pending) -> Buttons,
  ) -> some View {
    confirmationDialog(
      pending.map(title) ?? "",
      isPresented: Binding(
        get: { pending != nil },
        set: { isPresented in
          if !isPresented, let pending { dismiss(pending) }
        },
      ),
      titleVisibility: .visible,
      presenting: pending,
      actions: buttons,
      message: { Text(message($0)) },
    )
  }
}
