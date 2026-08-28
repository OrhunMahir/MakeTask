import Foundation

enum AppRuntime {
    private static let uiTestingKey = "MAKETASK_UI_TESTING"

    static var isRunningUITests: Bool {
        ProcessInfo.processInfo.environment[uiTestingKey] == "1"
    }

    static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            && !isRunningUITests
    }

    static var isRunningTests: Bool {
        isRunningUnitTests || isRunningUITests
    }

    static func makeSettingsDefaults() -> UserDefaults {
        guard isRunningTests else { return .standard }

        let suiteName = "dev.orhun.MakeTask.test-runtime.\(ProcessInfo.processInfo.processIdentifier)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
