import XCTest
@testable import SlackAlarm

final class PreferencesTests: XCTestCase {
    func testOldPreferencesKeepNamesAndDefaultToEnglish() throws {
        let legacy = Data(#"{"names":"Alice\nBob","mode":"strict","senderField":"subtitle","senderConfirmed":false,"volume":0.4,"preventSleep":true,"key":1,"command":true,"option":true,"control":true,"shift":false,"database":"","mentions":{"enabled":true,"text":"@me"}}"#.utf8)
        let prefs = try JSONDecoder().decode(Preferences.self, from: legacy)
        XCTAssertEqual(prefs.names, "Alice\nBob")
        XCTAssertEqual(prefs.volume, 0.4)
        XCTAssertTrue(prefs.preventSleep)
        XCTAssertEqual(prefs.mentions?.text, "@me")
        XCTAssertEqual(prefs.language ?? "en", "en")
    }
    func testLanguageSelectionPersists() throws {
        var prefs = Preferences()
        XCTAssertEqual(prefs.language ?? "en", "en")
        prefs.language = "zh"
        let restored = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(prefs))
        XCTAssertEqual(restored.language, "zh")
    }
}
