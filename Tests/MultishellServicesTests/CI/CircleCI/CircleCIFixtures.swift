/// What `circleci` 1.11 and 1.13 print: real output from a work project,
/// scrubbed, and `run(…)` varying one record of that shape.
enum CircleCIFixtures {
  static let runList = """
    [
      {"id":"58596572-0000-4000-8000-000000000001","phase":"ended","current_outcome":"succeeded",\
    "branch":"issue-8","revision":"aaa1111","repository_url":"https://github.com/acme/app",\
    "commit":{"subject":"Read the pull request","url":"https://github.com/acme/app/commit/aaa1111000",\
    "author_name":"Someone","author_login":"someone"},"created_at":"2026-10-27 01:05 UTC"},
      {"id":"58596572-0000-4000-8000-000000000002","phase":"ended","current_outcome":"failed",\
    "branch":"main","revision":"bbb2222","repository_url":"https://github.com/acme/app",\
    "commit":{"subject":"Fix the build","url":"https://github.com/acme/app/commit/bbb2222000",\
    "author_name":"Someone","author_login":"someone"},"created_at":"2026-10-26 21:32 UTC"},
      {"id":"58596572-0000-4000-8000-000000000003","phase":"ended","current_outcome":"canceled",\
    "branch":"spike/kitty-keys","revision":"ccc3333","repository_url":"https://github.com/acme/app",\
    "commit":{"subject":"Try the keys","url":"https://github.com/acme/app/commit/ccc3333000",\
    "author_name":"Someone","author_login":"someone"},"created_at":"2026-10-26 21:06 UTC"}
    ]
    """

  /// 1.13's shape for a run under way: `started`, with no outcome keys at all.
  static let startedRun = """
    [{"id":"started","phase":"started","branch":"feat","revision":"ddd4444",\
    "repository_url":"https://github.com/acme/app","commit":{"subject":"Fix the test"},\
    "created_at":"2026-11-02 19:04 UTC"}]
    """

  static let startedThenFailedRunList = """
    [{"id":"started","phase":"started","branch":"feat","revision":"ddd4444",\
    "repository_url":"https://github.com/acme/app","commit":{"subject":"Fix the test"},\
    "created_at":"2026-11-02 19:04 UTC"},
    {"id":"failed","phase":"ended","current_outcome":"failed","branch":"feat","revision":"eee5555",\
    "repository_url":"https://github.com/acme/app","commit":{"subject":"Break the test"},\
    "created_at":"2026-11-02 18:10 UTC"}]
    """

  static let runGet = """
    {"id":"58596572-0000-4000-8000-000000000002","phase":"ended","current_outcome":"failed",\
    "branch":"main","revision":"bbb2222","repository_url":"https://github.com/acme/app",\
    "commit":{"subject":"Fix the build"},"created_at":"2026-10-26 21:32 UTC",\
    "workflows":[{"id":"c9cf4fb1-0000-4000-8000-000000000001","name":"prep_and_test","phase":"ended",\
    "outcome":"failed","duration":"26m37s","jobs":[\
    {"id":"eb605493-0000-4000-8000-000000000001","name":"prep","phase":"ended","outcome":"succeeded","type":"build"},\
    {"id":"0c137413-0000-4000-8000-000000000002","name":"playwright","phase":"ended","outcome":"failed","type":"build"},\
    {"id":"63084dd4-0000-4000-8000-000000000003","name":"vitest","phase":"ended","outcome":"succeeded","type":"build"},\
    {"id":"6a7b3e89-0000-4000-8000-000000000004","phase":"ended","outcome":"succeeded","type":"build"}]}]}
    """

  static let failureReport = """
    ## workflow: prep_and_test

    ### job: playwright (execution 0, 1 of 2 failed)

    #### step 104: Playwright [exit: 1]

    Installing circleci-tests-plugin-cli plugin.
    1) [chromium] › journeys.spec.ts:121:3 › a swipe scrolls the page

    Test timeout of 30000ms exceeded.

    ### job: vitest (execution 0)

    #### step 12: Vitest [exit: 1]

    FAIL src/theme.test.ts
    """

  /// What a failed call prints on stderr, its exit code beside it.
  static let projectNotFound = """
    {
      "error": true,
      "code": "project.not_found",
      "message": "No project found for \\"gh/acme/app\\".\\nAPI: {\\"message\\":\\"Project not found\\"}",
      "suggestions": ["Run 'circleci project link' to bind this repository to a CircleCI project"],
      "exit_code": 5
    }
    """

  static func run(
    id: String,
    branch: String? = "main",
    phase: String = "ended",
    currentOutcome: String? = "succeeded",
    createdAt: String = "2026-10-27 05:20 UTC",
  ) -> String {
    func json(_ value: String?) -> String { value.map { "\"\($0)\"" } ?? "null" }
    return """
      {"id":"\(id)","phase":"\(phase)","outcome":null,"current_outcome":\(json(currentOutcome)),\
      "branch":\(json(branch)),"revision":"abc1234","repository_url":"https://github.com/acme/app",\
      "commit":{"subject":"work","author_name":"Someone"},"created_at":"\(createdAt)"}
      """
  }
}
