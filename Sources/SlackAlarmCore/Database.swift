import Foundation
import SQLite3
import CryptoKit
import Darwin

public enum NotificationDatabase {
    public static func candidates() -> [String] {
        var paths = [FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Group Containers/group.com.apple.usernoted/db2/db").path]
        var buffer = [CChar](repeating: 0, count: 4096)
        if confstr(_CS_DARWIN_USER_DIR, &buffer, buffer.count) > 0 {
            paths.append(String(cString: buffer) + "com.apple.notificationcenter/db2/db")
        }
        // NSTemporaryDirectory is scoped to the current user; do not scan other users' folders.
        let legacy = URL(fileURLWithPath: NSTemporaryDirectory()).deletingLastPathComponent().appendingPathComponent("0/com.apple.notificationcenter/db2/db").path
        if !paths.contains(legacy) { paths.append(legacy) }
        return paths
    }
    public static func locate(override: String? = nil) throws -> String {
        if let override, !override.isEmpty { return override }
        var denied = false
        for path in candidates() {
            var info = stat()
            if stat(path, &info) == 0 { return path }
            if errno == EACCES || errno == EPERM { denied = true }
        }
        throw denied ? ReadFailure.permission : ReadFailure.missing
    }
    public static func read(path: String) throws -> Snapshot {
        var info = stat()
        if stat(path, &info) != 0 { throw (errno == EACCES || errno == EPERM) ? ReadFailure.permission : ReadFailure.missing }
        let generation = "\(info.st_dev):\(info.st_ino):\(info.st_birthtimespec.tv_sec):\(info.st_birthtimespec.tv_nsec)"
        var handle: OpaquePointer?
        let result = sqlite3_open_v2(path, &handle, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil)
        defer { if let handle { sqlite3_close(handle) } }
        func failure(_ code: Int32) -> ReadFailure {
            if let handle {
                let systemError = sqlite3_system_errno(handle)
                if systemError == EACCES || systemError == EPERM { return .permission }
            }
            switch code & 0xff {
            case SQLITE_AUTH, SQLITE_PERM: return .permission
            case SQLITE_BUSY, SQLITE_LOCKED: return .busy
            default: return .sqlite(code)
            }
        }
        guard result == SQLITE_OK, let db = handle else { throw failure(result) }
        sqlite3_busy_timeout(db, 500)
        func execute(_ sql: String) throws {
            let rc = sqlite3_exec(db, sql, nil, nil, nil); if rc != SQLITE_OK { throw failure(rc) }
        }
        try execute("PRAGMA query_only=ON")
        let capturedAt = Date().timeIntervalSinceReferenceDate
        try execute("BEGIN")
        defer { try? execute("ROLLBACK") }
        func columns(_ table: String) throws -> Set<String> {
            var statement: OpaquePointer?
            let rc = sqlite3_prepare_v2(db, "PRAGMA table_info(\(table))", -1, &statement, nil)
            guard rc == SQLITE_OK else { throw failure(rc) }
            defer { sqlite3_finalize(statement) }
            var found = Set<String>(); var step = sqlite3_step(statement)
            while step == SQLITE_ROW {
                if let text = sqlite3_column_text(statement, 1) { found.insert(String(cString: text)) }
                step = sqlite3_step(statement)
            }
            guard step == SQLITE_DONE else { throw failure(step) }; return found
        }
        let r = try columns("record"), a = try columns("app")
        guard Set(["rec_id", "app_id", "uuid", "data", "delivered_date"]).isSubset(of: r), Set(["app_id", "identifier"]).isSubset(of: a) else {
            throw ReadFailure.unsupported("需要 record(rec_id,app_id,uuid,data,delivered_date) 与 app(app_id,identifier)；未猜测未知表结构")
        }
        var statement: OpaquePointer?
        // All IDs are retained for baseline/rebuild detection; only Slack payloads are decoded.
        let sql = "SELECT r.rec_id,a.identifier,r.uuid,r.delivered_date,CASE WHEN a.identifier='com.tinyspeck.slackmacgap' THEN r.data ELSE NULL END FROM record r LEFT JOIN app a ON r.app_id=a.app_id ORDER BY r.rec_id"
        let rc = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
        guard rc == SQLITE_OK else { throw failure(rc) }
        defer { sqlite3_finalize(statement) }
        var records: [Notice] = []; var maximum: Int64 = 0; var unsupported = 0
        var step = sqlite3_step(statement)
        while step == SQLITE_ROW {
            let id = sqlite3_column_int64(statement, 0); maximum = max(maximum, id)
            let app = sqlite3_column_text(statement, 1).map { String(cString: $0) } ?? ""
            if app == "com.tinyspeck.slackmacgap" {
                let bytes = sqlite3_column_bytes(statement, 4)
                guard let blob = sqlite3_column_blob(statement, 4), bytes > 0 else { unsupported += 1; step = sqlite3_step(statement); continue }
                let data = Data(bytes: blob, count: Int(bytes))
                let uuid = sqlite3_column_blob(statement, 2).map { Data(bytes: $0, count: Int(sqlite3_column_bytes(statement, 2))).base64EncodedString() } ?? ""
                do {
                    let parsed = try parse(data)
                    let identity = uuid.isEmpty ? SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() : uuid
                    records.append(Notice(id: id, identity: identity, delivered: sqlite3_column_double(statement, 3), app: app, title: parsed.0, subtitle: parsed.1, body: parsed.2))
                } catch { unsupported += 1 }
            }
            step = sqlite3_step(statement)
        }
        guard step == SQLITE_DONE else { throw failure(step) }
        try execute("COMMIT")
        if unsupported > 0 { throw ReadFailure.unsupported("\(unsupported) 条 Slack 记录的 plist/req 或文本字段无法解析；未跳过后显示正常") }
        return Snapshot(generation: generation, records: records, maximumID: maximum, capturedAt: capturedAt)
    }
    public static func parse(_ data: Data) throws -> (String, String, String) {
        guard let root = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any], let req = root["req"] as? [String: Any] else { throw ReadFailure.unsupported("plist.req") }
        guard ["titl", "subt", "body"].contains(where: { req[$0] != nil }) else {
            throw ReadFailure.unsupported("plist.req 缺少已知文本字段 titl/subt/body")
        }
        func text(_ key: String) throws -> String {
            guard let value = req[key] else { return "" }
            guard let string = value as? String else { throw ReadFailure.unsupported("req.\(key) 不是字符串") }
            return string
        }
        return try (text("titl"), text("subt"), text("body"))
    }
}
