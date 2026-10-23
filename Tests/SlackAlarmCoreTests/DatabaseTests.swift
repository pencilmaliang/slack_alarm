import XCTest
import SQLite3
@testable import SlackAlarmCore

final class DatabaseTests: XCTestCase {
    func testLiveWALAndUnsupportedSchema() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("db").path
        var writer: OpaquePointer?
        XCTAssertEqual(sqlite3_open(path, &writer), SQLITE_OK)
        defer { sqlite3_close(writer) }
        func exec(_ sql: String) throws { guard sqlite3_exec(writer, sql, nil, nil, nil) == SQLITE_OK else { throw ReadFailure.sqlite(sqlite3_errcode(writer)) } }
        try exec("PRAGMA journal_mode=WAL")
        try exec("PRAGMA wal_autocheckpoint=0")
        try exec("CREATE TABLE app(app_id INTEGER PRIMARY KEY,identifier TEXT)")
        try exec("CREATE TABLE record(rec_id INTEGER PRIMARY KEY,app_id INTEGER,uuid BLOB,data BLOB,delivered_date REAL)")
        try exec("INSERT INTO app VALUES(1,'com.tinyspeck.slackmacgap')")
        let data = try PropertyListSerialization.data(fromPropertyList: ["req": ["titl": "Alice", "body": "test"]], format: .binary, options: 0)
        let hex = data.map { String(format: "%02x", $0) }.joined()
        try exec("INSERT INTO record VALUES(1,1,X'01',X'\(hex)',100)")
        let beforeRead = Date().timeIntervalSinceReferenceDate
        let first = try NotificationDatabase.read(path: path)
        XCTAssertGreaterThanOrEqual(first.capturedAt, beforeRead)
        XCTAssertLessThanOrEqual(first.capturedAt, Date().timeIntervalSinceReferenceDate)
        XCTAssertEqual(first.records.count, 1)
        try exec("BEGIN IMMEDIATE")
        try exec("INSERT INTO record VALUES(2,1,X'02',X'\(hex)',101)")
        // The read snapshot excludes an uncommitted notification, even while a writer holds WAL.
        XCTAssertEqual(try NotificationDatabase.read(path: path).records.count, 1)
        try exec("COMMIT")
        XCTAssertEqual(try NotificationDatabase.read(path: path).records.map(\.id), [1, 2])
        try exec("DROP TABLE record")
        XCTAssertThrowsError(try NotificationDatabase.read(path: path)) { error in
            guard case ReadFailure.unsupported = error else { return XCTFail("Expected unsupported schema") }
        }
    }
}
