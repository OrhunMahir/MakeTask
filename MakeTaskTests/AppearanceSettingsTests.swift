import XCTest
@testable import MakeTask

@MainActor
final class AppearanceSettingsTests: XCTestCase {
    func testTypographyDefaultsToSystemAndPersistsSelection() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }

        XCTAssertEqual(environment.settings.typography, .system)

        environment.settings.typography = .serif
        let restoredSettings = AppSettings(defaults: environment.defaults)

        XCTAssertEqual(restoredSettings.typography, .serif)
    }
}
