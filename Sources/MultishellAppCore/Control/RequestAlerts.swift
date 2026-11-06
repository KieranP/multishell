/// A running request's newest alert, its answer even once taken down, and what
/// its alerts went up over; see Docs/design/agents/command-line.md.
struct RequestAlerts {
  var newest: PresentedError
  var covered: PresentedError?
}
