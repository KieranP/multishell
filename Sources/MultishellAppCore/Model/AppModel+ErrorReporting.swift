extension AppModel {
  func present(_ error: any Error) {
    presentedError = PresentedError(error)
  }
}
