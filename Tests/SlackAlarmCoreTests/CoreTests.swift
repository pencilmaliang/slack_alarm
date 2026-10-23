import XCTest
@testable import SlackAlarmCore

final class CoreTests: XCTestCase {
    func n(_ id: Int64, title: String = "Alice", body: String = "", time: Double = 101, identity: String? = nil) -> Notice {
        Notice(id: id, identity: identity ?? "uuid-\(id)", delivered: time, title: title, body: body)
    }
    func snapshot(_ ns: [Notice], generation: String = "a") -> Snapshot { Snapshot(generation: generation, records: ns) }
    func testHistoricalBaselineDoesNotTrigger() {
        var s = MonitorState(); let old = n(1, time: 99)
        s.start(snapshot([old]), now: 100)
        XCTAssertFalse(s.consume(snapshot([old]), targets: ["Alice"]).startAlarm)
        XCTAssertFalse(s.consume(snapshot([old, n(2, time: 98)]), targets: ["Alice"]).startAlarm)
    }
    func testSnapshotTimeSurvivesDelayedStartCallback() {
        // Snapshot starts at 100; a new notification arrives after the read but
        // before the UI processes its completion. Starting must not use UI time.
        var state = MonitorState()
        let baseline = Snapshot(generation: "a", records: [n(1, time: 99)], capturedAt: 100)
        state.start(baseline)
        let next = Snapshot(generation: "a", records: [n(1, time: 99), n(2, time: 101), n(3, time: 98)])
        let result = state.consume(next, targets: ["Alice"])
        XCTAssertTrue(result.startAlarm)
        XCTAssertEqual(result.matches, 1)
        state.stopAlarm()
        XCTAssertFalse(state.consume(next, targets: ["Alice"]).startAlarm)
    }
    func testParserRejectsUnknownTextKeysButAllowsOptionalFields() throws {
        for req: [String: String] in [[:], ["new_title": "Alice"]] {
            let data = try PropertyListSerialization.data(fromPropertyList: ["req": req], format: .binary, options: 0)
            XCTAssertThrowsError(try NotificationDatabase.parse(data))
        }
        let data = try PropertyListSerialization.data(fromPropertyList: ["req": ["subt": "Alice"]], format: .binary, options: 0)
        let parsed = try NotificationDatabase.parse(data)
        XCTAssertEqual(parsed.0, "")
        XCTAssertEqual(parsed.1, "Alice")
        XCTAssertEqual(parsed.2, "")
        let empty = try PropertyListSerialization.data(fromPropertyList: ["req": ["body": ""]], format: .binary, options: 0)
        XCTAssertNoThrow(try NotificationDatabase.parse(empty))
    }
    func testBatchDedupAndSingleAlarm() {
        var s = MonitorState(); s.start(snapshot([]), now: 100)
        let batch = snapshot([n(1), n(2), n(3, title: "Bob")])
        let first = s.consume(batch, targets: ["Alice"])
        XCTAssertEqual(first.matches, 2); XCTAssertTrue(first.startAlarm)
        XCTAssertFalse(s.consume(batch, targets: ["Alice"]).startAlarm)
        XCTAssertFalse(s.consume(snapshot(batch.records + [n(4)]), targets: ["Alice"]).startAlarm)
        XCTAssertFalse(s.testAlarm())
        s.stopAlarm(); XCTAssertFalse(s.alarming); XCTAssertTrue(s.listening)
        XCTAssertTrue(s.consume(snapshot(batch.records + [n(4), n(5)]), targets: ["Alice"]).startAlarm)
    }
    func testNamesMatchEitherHeaderButNeverBody() {
        let bodyOnly = n(1, title: "Bob", body: "Alice asked for this")
        XCTAssertFalse(Matcher.matches(bodyOnly, targets: ["Alice"]))
        XCTAssertTrue(Matcher.matches(n(2, title: " ALICE in #general "), targets: [" alice "]))
        let sub = Notice(id: 3, identity: "3", delivered: 101, title: "Workspace", subtitle: "Alice (DM)")
        XCTAssertTrue(Matcher.matches(sub, targets: ["Bob", "Alice"]))
        XCTAssertFalse(Matcher.matches(sub, targets: ["   "]))
        let other = Notice(id: 4, identity: "4", delivered: 101, app: "other", title: "Alice")
        XCTAssertFalse(Matcher.matches(other, targets: ["Alice"]))
        // Header fields are searched independently, never across their boundary.
        let split = Notice(id: 5, identity: "5", delivered: 101, title: "Ali", subtitle: "ce")
        XCTAssertFalse(Matcher.matches(split, targets: ["Alice"]))
    }
    func testBothHeaderLayoutsTriggerWithoutConfirmation() {
        var state = MonitorState()
        state.start(snapshot([]), now: 100)
        let title = n(1, title: "Alice in #general")
        XCTAssertTrue(state.consume(snapshot([title]), targets: ["Alice"]).startAlarm)
        state.stopAlarm()
        let subtitle = Notice(id: 2, identity: "2", delivered: 102, title: "Workspace", subtitle: "Alice")
        XCTAssertTrue(state.consume(snapshot([title, subtitle]), targets: ["Alice"]).startAlarm)
        state.stopAlarm()
        XCTAssertFalse(state.consume(snapshot([title, subtitle, n(3, title: "Bob", body: "Alice")]), targets: ["Alice"]).startAlarm)
    }
    func testStopListeningAndRestart() {
        var s = MonitorState(); s.start(snapshot([]), now: 100); XCTAssertTrue(s.testAlarm())
        s.stopListening(); XCTAssertTrue(s.alarming) // explicitly stop current alarm separately
        XCTAssertFalse(s.consume(snapshot([n(1)]), targets: ["Alice"]).startAlarm)
        s.stopAlarm(); XCTAssertFalse(s.alarming)
        s.start(snapshot([n(1)]), now: 102)
        XCTAssertFalse(s.consume(snapshot([n(1)]), targets: ["Alice"]).startAlarm)
    }
    func testRebuildRollbackAndWake() {
        var s = MonitorState(); s.start(snapshot([n(10, time: 99)]), now: 100)
        let reset = s.consume(snapshot([n(1)], generation: "b"), targets: ["Alice"])
        XCTAssertTrue(reset.reset); XCTAssertFalse(reset.startAlarm)
        XCTAssertTrue(s.consume(snapshot([n(1), n(2, time: 500)], generation: "b"), targets: ["Alice"]).startAlarm)
        s.stopAlarm()
        XCTAssertTrue(s.consume(snapshot([], generation: "b"), targets: ["Alice"]).reset)
    }
    func testParserRejectsUnsupportedAndReadsFields() throws {
        let data = try PropertyListSerialization.data(fromPropertyList: ["req": ["titl": "Alice", "subt": "Workspace", "body": "hello"]], format: .binary, options: 0)
        let parsed = try NotificationDatabase.parse(data)
        XCTAssertEqual(parsed.0, "Alice"); XCTAssertEqual(parsed.1, "Workspace"); XCTAssertEqual(parsed.2, "hello")
        XCTAssertThrowsError(try NotificationDatabase.parse(Data("invalid".utf8)))
        let unknown = try PropertyListSerialization.data(fromPropertyList: ["req": ["titl": ["localized", "args"]]], format: .binary, options: 0)
        XCTAssertThrowsError(try NotificationDatabase.parse(unknown))
    }
}

final class MentionTests: XCTestCase {
    func notice(_ body: String, app: String = "com.tinyspeck.slackmacgap") -> Notice {
        Notice(id: 1, identity: "new", delivered: 101, app: app, title: "Bob", body: body)
    }
    func testLiteralMentionBoundaries() {
        for text in ["hello @me", "(@ME)", "@me.", "please @me!", "<@me>"] {
            XCTAssertTrue(Matcher.matchesMention(notice(text), markers: ["@me"]), text)
        }
        for text in ["me", "@member", "mail@me.com", "@me.other", "@@me", "@me-other"] {
            XCTAssertFalse(Matcher.matchesMention(notice(text), markers: ["@me"]), text)
        }
        XCTAssertTrue(Matcher.matchesMention(notice("hi @first.last!"), markers: ["@first.last"]))
        XCTAssertFalse(Matcher.matchesMention(notice("@firstXlast"), markers: ["@first.last"]))
        XCTAssertFalse(Matcher.matchesMention(notice("@me", app: "other"), markers: ["@me"]))
        XCTAssertFalse(Matcher.matchesMention(notice("@me"), markers: []))
    }
    func testMentionRuleIsIndependentAndUsesExistingDedup() {
        let n = notice("hello @me")
        XCTAssertFalse(Matcher.matches(n, targets: ["me"]))
        var s = MonitorState()
        s.start(Snapshot(generation: "a", records: []), now: 100)
        let snapshot = Snapshot(generation: "a", records: [n])
        XCTAssertTrue(s.consume(snapshot, targets: [], mentionMarkers: ["@me"]).startAlarm)
        s.stopAlarm()
        XCTAssertFalse(s.consume(snapshot, targets: [], mentionMarkers: ["@me"]).startAlarm)
        s.stopListening()
        let next = Notice(id: 2, identity: "next", delivered: 102, title: "Bob", body: "@me")
        XCTAssertFalse(s.consume(Snapshot(generation: "a", records: [n, next]), targets: [], mentionMarkers: ["@me"]).startAlarm)
    }
}
