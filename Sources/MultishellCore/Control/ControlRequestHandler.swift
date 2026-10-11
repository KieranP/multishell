/// A request's answer, `nil` for none. Its task is cancelled should the
/// helper hang up before it is answered.
public typealias ControlRequestHandler = @MainActor (ControlRequest) async -> ControlReply?
