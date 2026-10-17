import Foundation
import Testing

@testable import MultishellCore

@MainActor
@Suite
struct WorkspaceDisplayNamesTests {
  @Test func aFileTabIsTitledByItsNameAloneWhereNoOtherOpenFileSharesIt() throws {
    let (store, _, worktree) = demoStore()
    let tab = try #require(store.openFileTab(path: "Sources/App/main.swift", in: worktree.id))

    #expect(store.workspace.title(of: tab) == "main.swift")
  }

  @Test func twoOpenFilesOfOneNameAreTitledByTheShortestPathThatTellsThemApart() throws {
    let (store, _, worktree) = demoStore()
    let models = try #require(store.openFileTab(path: "app/models/user.rb", in: worktree.id))
    let lib = try #require(store.openFileTab(path: "lib/user.rb", in: worktree.id))
    let top = try #require(store.openFileTab(path: "user.rb", in: worktree.id))
    let deep = try #require(store.openFileTab(path: "spec/models/user.rb", in: worktree.id))

    #expect(store.workspace.title(of: models) == "app/models/user.rb")
    #expect(store.workspace.title(of: deep) == "spec/models/user.rb")
    #expect(store.workspace.title(of: lib) == "lib/user.rb")
    #expect(store.workspace.title(of: top) == "user.rb")
  }

  @Test func aNamesakeInAnotherWorktreeDoesNotLengthenTheTitle() throws {
    let (store, main, other) = twoWorktreeStore()
    let here = try #require(store.openFileTab(path: "a/user.rb", in: main.id))
    store.openFileTab(path: "b/user.rb", in: other.id)

    #expect(store.workspace.title(of: here) == "user.rb")
  }
}
