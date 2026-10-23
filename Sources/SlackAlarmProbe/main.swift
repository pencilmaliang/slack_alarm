import Foundation
import SlackAlarmCore

let args = CommandLine.arguments
func option(_ name: String) -> String? { guard let index = args.firstIndex(of: name), index + 1 < args.count else { return nil }; return args[index + 1] }
let seconds = Int(option("--watch") ?? "0") ?? 0
let reveal = args.contains("--show-sample")
do {
    let path = try NotificationDatabase.locate(override: option("--database"))
    let initial = try NotificationDatabase.read(path: path)
    print("可读；Slack 历史记录 \(initial.records.count)。历史记录不作为新通知。")
    var state = MonitorState(); state.start(initial)
    if reveal {
        for n in initial.records.suffix(3) { print("样本 ID=\(n.id) app=\(n.app) date=\(Date(timeIntervalSinceReferenceDate:n.delivered)) title=\(n.title) subtitle=\(n.subtitle) body长度=\(n.body.count)") }
    }
    var seen = Set(initial.records.map(\.key)); var count = 0
    for _ in 0..<max(0, seconds) {
        Thread.sleep(forTimeInterval: 1)
        let snapshot = try NotificationDatabase.read(path: path)
        let change = state.consume(snapshot, targets: [])
        if change.reset { seen = Set(snapshot.records.map(\.key)); print("数据库重建/回退；重新建立基线"); continue }
        let fresh = snapshot.records.filter { !seen.contains($0.key) }
        seen.formUnion(snapshot.records.map(\.key))
        for n in fresh {
            count += 1
            print("新 Slack 通知：title长度=\(n.title.count)，subtitle长度=\(n.subtitle.count)，body长度=\(n.body.count)")
            if reveal { print("title=\(n.title) subtitle=\(n.subtitle)") }
        }
    }
    if seconds > 0 && count == 0 { print("尚无新 Slack 通知；不等于发送人验证通过。") }
} catch { fputs("诊断失败：\(error.localizedDescription)\n", stderr); exit(1) }
