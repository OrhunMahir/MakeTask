import XCTest
@testable import MakeTask

@MainActor
final class AppearanceSettingsTests: XCTestCase {
    func testTypographyDefaultsToSystemAndPersistsSelection() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }

        XCTAssertEqual(environment.settings.typography, .system)

        environment.settings.typography = .avenirNext
        let restoredSettings = AppSettings(defaults: environment.defaults)

        XCTAssertEqual(restoredSettings.typography, .avenirNext)
    }

    func testNativeFontFamiliesResolveForAppKitSurfaces() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }

        let expectedFamilies: [(AppSettings.Typography, String)] = [
            (.avenirNext, "Avenir Next"),
            (.helveticaNeue, "Helvetica Neue"),
            (.georgia, "Georgia"),
            (.palatino, "Palatino")
        ]

        for (typography, expectedFamily) in expectedFamilies {
            environment.settings.typography = typography
            XCTAssertEqual(
                environment.settings.nsFont(size: 14).familyName,
                expectedFamily
            )
        }
    }
}
