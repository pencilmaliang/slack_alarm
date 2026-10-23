import Foundation
import CryptoKit

public struct Notice: Equatable {
    public let id: Int64
    public let identity: String
    public let delivered: Double
    public let app: String
    public let title: String
    public let subtitle: String
    public let body: String
    public init(id: Int64, identity: String, delivered: Double, app: String = "com.tinyspeck.slackmacgap", title: String, subtitle: String = "", body: String = "") {
        self.id = id; self.identity = identity; self.delivered = delivered; self.app = app
        self.title = title; self.subtitle = subtitle; self.body = body
    }
    public var isSlack: Bool { app == "com.tinyspeck.slackmacgap" }
    public var key: String { "\(id):\(identity)" }
}
public struct MentionSettings: Codable, Equatable {
    public var enabled: Bool
    public var text: String
    public init(enabled: Bool = false, text: String = "") { self.enabled = enabled; self.text = text }
    public var markers: [String] {
        text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.hasPrefix("@") && $0.count > 1 }
    }
}
public struct Matcher {
    // Literal notification text only: this does not prove a Slack semantic mention.
    public static func matchesMention(_ n: Notice, markers: [String]) -> Bool {
        guard n.isSlack else { return false }
        let body = n.body.precomposedStringWithCanonicalMapping
        for marker in markers {
            let text = marker.precomposedStringWithCanonicalMapping.trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.hasPrefix("@"), text.count > 1 else { continue }
            let literal = NSRegularExpression.escapedPattern(for: text)
            // Exclude emails, longer handles and dotted-name extensions. Allow sentence punctuation.
            let pattern = "(?<![\\p{L}\\p{N}_@.+-])" + literal + "(?![\\p{L}\\p{N}_-]|[.][\\p{L}\\p{N}_-])"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               regex.firstMatch(in: body, range: NSRange(body.startIndex..., in: body)) != nil { return true }
        }
        return false
    }

    public static func matches(_ n: Notice, targets: [String]) -> Bool {
        guard n.isSlack else { return false }
        func normalize(_ s: String) -> String {
            s.precomposedStringWithCanonicalMapping.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        let fields = [normalize(n.title), normalize(n.subtitle)]
        return targets.map(normalize).filter { !$0.isEmpty }.contains { name in
            fields.contains { $0.contains(name) }
        }
    }
}
public struct Snapshot {
    public let generation: String
    /// Lower time bound captured before the database snapshot is read.
    public let capturedAt: Double
    public let records: [Notice]
    public let maximumID: Int64
    public let unsupportedSlack: Int
    public init(generation: String, records: [Notice], maximumID: Int64? = nil, unsupportedSlack: Int = 0, capturedAt: Double = Date().timeIntervalSinceReferenceDate) {
        self.generation = generation; self.records = records; self.capturedAt = capturedAt
        self.maximumID = maximumID ?? records.map(\.id).max() ?? 0
        self.unsupportedSlack = unsupportedSlack
    }
}
// A complete snapshot is read in a single transaction. No high-water-only query:
// sparse IDs, batch arrivals, pruning, and updates with an existing ID are visible.
public struct MonitorState {
    public private(set) var listening = false
    public private(set) var alarming = false
    private var seen = Set<String>()
    private var generation = ""
    private var maximum: Int64 = 0
    private var started: Double = 0
    public init() {}
    public mutating func start(_ snapshot: Snapshot, now: Double? = nil) {
        listening = true; started = now ?? snapshot.capturedAt; baseline(snapshot)
    }
    private mutating func baseline(_ s: Snapshot) {
        generation = s.generation; maximum = s.maximumID; seen = Set(s.records.map(\.key))
    }
    public mutating func stopListening() { listening = false; seen.removeAll() }
    public mutating func stopAlarm() { alarming = false }
    @discardableResult public mutating func testAlarm() -> Bool {
        guard !alarming else { return false }; alarming = true; return true
    }
    public mutating func consume(_ snapshot: Snapshot, targets: [String], mentionMarkers: [String] = []) -> (startAlarm: Bool, reset: Bool, matches: Int) {
        guard listening else { return (false, false, 0) }
        // A rebuild or ID rollback establishes a fresh baseline, never replaying history.
        if generation != snapshot.generation || snapshot.maximumID < maximum {
            baseline(snapshot); return (false, true, 0)
        }
        let fresh = snapshot.records.filter { !seen.contains($0.key) && $0.delivered >= started }
        seen.formUnion(snapshot.records.map(\.key)); maximum = snapshot.maximumID
        let count = fresh.filter { Matcher.matches($0, targets: targets) || Matcher.matchesMention($0, markers: mentionMarkers) }.count
        let begin = count > 0 && !alarming
        if begin { alarming = true }
        return (begin, false, count)
    }
}
public enum ReadFailure: Error, LocalizedError {
    case missing, permission, busy, unsupported(String), sqlite(Int32), discovery
    public var errorDescription: String? {
        switch self {
        case .missing: return "未找到通知数据库。请打开通知中心后重试；也可能是权限隐藏了路径。"
        case .permission: return "读取被拒绝。请授予完全磁盘访问权限，退出并重开应用后重试。"
        case .busy: return "通知数据库正忙或被锁定；稍后重试。"
        case .unsupported(let detail): return "不支持的通知格式：\(detail)"
        case .sqlite(let code): return "数据库读取失败（SQLite \(code)）。可能是权限、WAL 访问或文件变化；闹铃已暂停。"
        case .discovery: return "无法获取当前用户的通知目录；请在诊断中选择数据库文件。"
        }
    }
}
