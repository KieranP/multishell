@testable import MultishellCore

extension ProjectAction {
  static let serve = ProjectAction(name: "Start Server", command: "npm run dev")
  static let migrate = ProjectAction(name: "Run Migrations", command: "bin/rails db:migrate")
  static let seed = ProjectAction(name: "Seed Database", command: "bin/rails db:seed")
}
