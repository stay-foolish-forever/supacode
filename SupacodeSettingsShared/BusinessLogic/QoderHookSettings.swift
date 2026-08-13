import Foundation

nonisolated enum QoderHookSettings {
  /// Canonical hook map for Qoder. Qoder uses the same grouped hook schema as
  /// Claude, so one composite command per (event, matcher) slot keeps install,
  /// state checks, and uninstall idempotent.
  static func hooksByEvent() throws -> [String: [JSONValue]] {
    try AgentHookPayloadSupport.extractHookGroups(
      from: QoderHooksPayload(),
      invalidConfiguration: QoderHookSettingsError.invalidConfiguration
    )
  }
}

nonisolated enum QoderHookSettingsError: Error {
  case invalidConfiguration
}

// MARK: - Hook payload.

// Qoder's Claude-compatible tool events provide tool-level activity. Unlike
// Claude, Qoder exposes StopFailure directly, so Stop only resets to idle and
// forwards its notification payload while StopFailure handles fatal errors.
private nonisolated struct QoderHooksPayload: Encodable {
  static let awaitingInputToolMatcher = "AskUserQuestion|ExitPlanMode"

  private static let busy = AgentHookSettingsCommand.compositeCommand(
    events: [.busy], forwardStdinAsNotification: false, agent: .qoder)
  private static let idle = AgentHookSettingsCommand.compositeCommand(
    events: [.idle], forwardStdinAsNotification: false, agent: .qoder)
  private static let awaitingInputAndNotify = AgentHookSettingsCommand.compositeCommand(
    events: [.awaitingInput], forwardStdinAsNotification: true, agent: .qoder)
  private static let awaitingInput = AgentHookSettingsCommand.compositeCommand(
    events: [.awaitingInput], forwardStdinAsNotification: false, agent: .qoder)
  private static let stop = AgentHookSettingsCommand.compositeCommand(
    events: [.idle], forwardStdinAsNotification: true, agent: .qoder)
  private static let stopFailure = AgentHookSettingsCommand.qoderStopFailureCommand(agent: .qoder)
  private static let compacting = AgentHookSettingsCommand.compositeCommand(
    events: [.compacting], forwardStdinAsNotification: false, agent: .qoder)
  private static let sessionStart = AgentHookSettingsCommand.compositeCommand(
    events: [.sessionStart], forwardStdinAsNotification: false, agent: .qoder)
  private static let sessionEndAndIdle = AgentHookSettingsCommand.compositeCommand(
    events: [.sessionEnd, .idle], forwardStdinAsNotification: false, agent: .qoder)

  let hooks: [String: [AgentHookGroup]] = [
    "SessionStart": [
      .init(hooks: [.init(command: Self.sessionStart, timeout: AgentHookSettingsCommand.timeoutSeconds)])
    ],
    "UserPromptSubmit": [
      .init(hooks: [.init(command: Self.busy, timeout: AgentHookSettingsCommand.timeoutSeconds)])
    ],
    "PreToolUse": [
      .init(matcher: "", hooks: [.init(command: Self.busy, timeout: AgentHookSettingsCommand.timeoutSeconds)]),
      // Array-order: matched-by-name fires AFTER matcher-"", so awaiting wins.
      .init(
        matcher: Self.awaitingInputToolMatcher,
        hooks: [.init(command: Self.awaitingInput, timeout: AgentHookSettingsCommand.timeoutSeconds)]
      ),
    ],
    "PostToolUse": [
      .init(matcher: "", hooks: [.init(command: Self.idle, timeout: AgentHookSettingsCommand.timeoutSeconds)])
    ],
    "Notification": [
      .init(
        matcher: "",
        hooks: [.init(command: Self.awaitingInputAndNotify, timeout: AgentHookSettingsCommand.timeoutSeconds)])
    ],
    "PreCompact": [
      .init(hooks: [.init(command: Self.compacting, timeout: AgentHookSettingsCommand.timeoutSeconds)])
    ],
    "Stop": [
      .init(hooks: [.init(command: Self.stop, timeout: AgentHookSettingsCommand.timeoutSeconds)])
    ],
    "StopFailure": [
      .init(hooks: [.init(command: Self.stopFailure, timeout: AgentHookSettingsCommand.timeoutSeconds)])
    ],
    "SessionEnd": [
      .init(
        matcher: "", hooks: [.init(command: Self.sessionEndAndIdle, timeout: AgentHookSettingsCommand.timeoutSeconds)])
    ],
  ]
}
