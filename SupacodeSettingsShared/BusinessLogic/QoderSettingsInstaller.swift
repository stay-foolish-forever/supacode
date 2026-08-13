import Foundation

nonisolated struct QoderSettingsInstaller {
  let homeDirectoryURL: URL
  let fileManager: FileManager

  init(
    homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser,
    fileManager: FileManager = .default
  ) {
    self.homeDirectoryURL = homeDirectoryURL
    self.fileManager = fileManager
  }

  func installState() throws -> ComponentInstallState {
    let groups: [String: [JSONValue]]
    do {
      groups = try QoderHookSettings.hooksByEvent()
    } catch {
      Self.reportInvalidHookConfiguration(error)
      return .notInstalled
    }
    return try fileInstaller.installState(settingsURL: settingsURL, hookGroupsByEvent: groups)
  }

  func installAllHooks() throws {
    try fileInstaller.install(
      settingsURL: settingsURL,
      hookGroupsByEvent: try QoderHookSettings.hooksByEvent()
    )
  }

  func uninstallAllHooks() throws {
    try fileInstaller.uninstall(
      settingsURL: settingsURL,
      hookGroupsByEvent: try QoderHookSettings.hooksByEvent()
    )
  }

  private static func reportInvalidHookConfiguration(_ error: Error) {
    #if DEBUG
      assertionFailure("Qoder hook configuration is invalid: \(error)")
    #endif
  }

  private var settingsURL: URL {
    Self.settingsURL(homeDirectoryURL: homeDirectoryURL)
  }

  static func settingsURL(homeDirectoryURL: URL) -> URL {
    homeDirectoryURL
      .appendingPathComponent(".qoder", isDirectory: true)
      .appendingPathComponent("settings.json", isDirectory: false)
  }

  private var fileInstaller: AgentHookSettingsFileInstaller {
    AgentHookSettingsFileInstaller(
      fileManager: fileManager,
      errors: .init(
        invalidEventHooks: { QoderSettingsInstallerError.invalidEventHooks($0) },
        invalidHooksObject: { QoderSettingsInstallerError.invalidHooksObject },
        invalidJSON: { QoderSettingsInstallerError.invalidJSON($0) },
        invalidRootObject: { QoderSettingsInstallerError.invalidRootObject }
      )
    )
  }
}

nonisolated enum QoderSettingsInstallerError: Error, Equatable, LocalizedError {
  case invalidEventHooks(String)
  case invalidHooksObject
  case invalidJSON(String)
  case invalidRootObject

  var errorDescription: String? {
    switch self {
    case .invalidEventHooks(let event):
      "Qoder settings use an unsupported hooks shape for \(event)."
    case .invalidHooksObject:
      "Qoder settings use an unsupported hooks shape."
    case .invalidJSON(let detail):
      "Qoder settings must be valid JSON before Supacode can install hooks (\(detail))."
    case .invalidRootObject:
      "Qoder settings must be a JSON object before Supacode can install hooks."
    }
  }
}
