import Foundation
import MultishellCore
import MultishellGitKit
import MultishellServices
import Observation

/// Fetches, pushes, pull requests and CI runs, runtime only; see services.md.
/// Its own observable, so each property is tracked alone.
@Observable
@MainActor
final class RemoteState {
  /// Projects with a `git fetch` running, which the sidebar shows and a
  /// second Fetch waits for.
  var fetchingProjects: Set<Project.ID> = []
  /// What the tools were last adopted from.
  @ObservationIgnored var adoption: ServiceToolAdoption?
  /// Which integrations' tools the login shell's PATH has.
  var toolDetection = ServiceToolDetection.empty
  /// A host or provider per integration detection found; tests stand fakes in.
  var connections = ServiceConnections.empty
  /// What each project's host and provider last answered. Rows read
  /// `worktrees`, made from these; the panel's pages and menus read these.
  var pullRequests: [Project.ID: ProjectPullRequests] = [:]
  var ciRuns: [Project.ID: ProjectCIRuns] = [:]
  /// What each worktree's row and the panel's pages draw.
  var worktrees: [Worktree.ID: WorktreeServices] = [:]
  /// Where each worktree's branch is published, from the branch scan: what its
  /// pull request and runs are filed under, and whose move re-reads them.
  var upstreams: [Worktree.ID: BranchUpstream] = [:]
  /// The merge form each worktree's pull request page shows in its place.
  var pendingMerges: [Worktree.ID: PendingMerge] = [:]
  var autoMergeCancellations: [Worktree.ID: AutoMergeCancellation] = [:]
  /// Each shown run's workflows, read as the CI page shows it.
  var ciWorkflows: [CIRun.ID: CIRunDetail<[CIWorkflow]>] = [:]
  /// What each branch was made from, by project, read once per branch.
  @ObservationIgnored var branchStartPoints: [Project.ID: [String: String?]] = [:]
  /// Providers found too old to read, which the reads and tabs pass over.
  var unreadableProviders: Set<ServiceIntegration> = []
  /// Whether an Integrations page has asked, so tools found later are asked too.
  @ObservationIgnored var wantsToolStatuses = false
  /// Bumped by each ask, so an older ask's answers never overwrite a newer one's.
  @ObservationIgnored var toolStatusAsk = 0
  /// What each tool said of itself when the Integrations page last opened.
  var toolStatuses: [ServiceIntegration: ServiceToolStatus] = [:]
  /// Worktrees whose branch Create Pull Request is pushing.
  var publishingWorktrees: Set<Worktree.ID> = []
  var pendingBranchPublish: PendingBranchPublish?
  /// The panel's pull request checks and run history, read only while it
  /// shows them, by worktree; and each failed run's report.
  var checks: [Worktree.ID: PullRequestChecks] = [:]
  var ciHistories: [Worktree.ID: CIRunHistory] = [:]
  var failureReports: [CIRun.ID: CIRunDetail<CIFailureReport>] = [:]
  /// When each project's list and runs last answered, kept apart so an answer
  /// that changed nothing redraws nothing; a failed read's tooltip reads them.
  @ObservationIgnored var pullRequestsAnsweredAt: [Project.ID: Date] = [:]
  @ObservationIgnored var ciRunsAnsweredAt: [Project.ID: Date] = [:]
  @ObservationIgnored var ciBranchesAnsweredAt: [Project.ID: [String: Date]] = [:]
  /// When each run's workflows and report were read, apart for the same reason.
  @ObservationIgnored var workflowsReadAt: [CIRun.ID: Date] = [:]
  @ObservationIgnored var reportsReadAt: [CIRun.ID: Date] = [:]
  @ObservationIgnored var panelReadLog = ServiceReadLog<PanelRead>()
  @ObservationIgnored var readLog = ServiceReadLog<Project.ID>()
  /// The poll's service reads, run beside git's rounds rather than in them.
  @ObservationIgnored var servicePoll: Task<Void, Never>?
  /// A poll asked for while one ran, at the shortest interval asked.
  @ObservationIgnored var nextPollInterval: Duration?
  /// The page the panel last read for, which a change of page or of tools is
  /// measured against.
  @ObservationIgnored var lastReadPanelPage: FilesPanelMode?
  /// The panel's read for the row the selection rests on, once it settles.
  @ObservationIgnored var pendingPanelRead: Task<Void, Never>?
  /// Runs whose workflows are being read, which a second ask leaves to that read.
  @ObservationIgnored var workflowReads: Set<CIRun.ID> = []
  @ObservationIgnored var reportReads: Set<CIRun.ID> = []
  /// Bumped as a project's integrations change, so a read spanning a change is
  /// not kept: it began from what was read before.
  @ObservationIgnored var integrationChanges: [Project.ID: Int] = [:]
  /// Whether each row's tip has a change its merged pull request's head lacks,
  /// and the questions git is being asked, per project: two clones answer apart.
  @ObservationIgnored var changesPastHead: [Project.ID: [ChangesPastHead: Bool]] = [:]
  @ObservationIgnored var changesPastHeadReads: [Project.ID: Set<ChangesPastHead>] = [:]
  /// Questions git could not answer, as for a head not fetched: a branch scan
  /// leaves them to the services' next read, which a fetch schedules.
  @ObservationIgnored var unanswerableChangesPastHead: [Project.ID: Set<ChangesPastHead>] = [:]
  /// The branch scans begun per project: one landing after a newer one began
  /// records no upstreams, its refs being older.
  @ObservationIgnored var branchScansBegun: [Project.ID: Int] = [:]
  /// Projects asked to read during a read, which may have missed what moved,
  /// and whether any ask wanted the pull requests too.
  @ObservationIgnored var rereads: [Project.ID: Bool] = [:]
  /// One settled read per project after its upstreams move.
  @ObservationIgnored var pendingReads: [Project.ID: Task<Void, Never>] = [:]
}
