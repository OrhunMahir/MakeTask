import AppKit
import Carbon

enum AppRuntime {
    private static let uiTestingKey = "MAKETASK_UI_TESTING"

    static func shouldRevealNotes(for event: NSAppleEventDescriptor) -> Bool {
        guard event.eventClass == AEEventClass(kCoreEventClass) else { return false }
        if event.eventID == AEEventID(kAEReopenApplication) { return true }
        guard event.eventID == AEEventID(kAEOpenApplication) else { return false }
        let launchReason = event.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue
        return launchReason != OSType(keyAELaunchedAsLogInItem)
            && launchReason != OSType(keyAELaunchedAsServiceItem)
    }

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

    static func supportsGlobalShortcuts(bundleIdentifier: String? = Bundle.main.bundleIdentifier) -> Bool {
        // Preview copies have separate data stores, but Carbon shortcuts are system-wide.
        // Only the main app should respond when both copies are running.
        bundleIdentifier == "dev.orhun.MakeTask"
    }

    static func makeSettingsDefaults() -> UserDefaults {
        guard isRunningTests else { return .standard }

        let suiteName = "dev.orhun.MakeTask.test-runtime.\(ProcessInfo.processInfo.processIdentifier)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
