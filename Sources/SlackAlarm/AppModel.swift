import SwiftUI
import AppKit
import SlackAlarmCore

struct Preferences: Codable {
    var names = ""
    var volume: Float = 0.7
    var preventSleep = false
    var database = ""
    var mentions: MentionSettings? = nil
    // Optional so existing Slack Wake settings decode without losing names or volume.
    var language: String? = nil
}
struct AppMessage {
    let english: String
    let chinese: String
    init(_ english: String, _ chinese: String) { self.english = english; self.chinese = chinese }
}
@MainActor final class AppModel: ObservableObject {
    @Published var preferences: Preferences {
        didSet {
            if let data = try? JSONEncoder().encode(preferences) { UserDefaults.standard.set(data, forKey: "preferences") }
            if oldValue.names != preferences.names || oldValue.database != preferences.database || oldValue.mentions != preferences.mentions {
                stopListening()
            }
            audio.volume = preferences.volume
            refreshPower()
            refreshWindowTitles()
        }
    }
    @Published var state = MonitorState()
    @Published private var issueMessage: AppMessage?
    @Published var samples: [Notice] = []
    @Published var sampleMessage: AppMessage?
    @Published private var starting = false
    @Published private(set) var inspecting = false
    private let queue = DispatchQueue(label: "SlackAlarm.database", qos: .utility)
    private let audio = AlarmAudio()
    private let power = IdleSleepAssertion()
    private var timer: Timer?
    private var inFlight = false
    private var epoch = 0
    private var sampleEpoch = 0
    private var alarmWindow: NSWindow?
    private var windows: [String: NSWindow] = [:]
    private var wakeObserver: NSObjectProtocol?
    var working: Bool { starting }
    var language: String {
        get { preferences.language ?? "en" }
        set { preferences.language = newValue }
    }
    func l(_ english: String, _ chinese: String) -> String { language == "zh" ? chinese : english }
    func text(_ message: AppMessage) -> String { l(message.english, message.chinese) }
    var issue: String { issueMessage.map(text) ?? "" }
    var targets: [String] { preferences.names.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
    var mentionEnabled: Bool {
        get { preferences.mentions?.enabled ?? false }
        set { var rule = preferences.mentions ?? MentionSettings(); rule.enabled = newValue; preferences.mentions = rule }
    }
    var mentionText: String {
        get { preferences.mentions?.text ?? "" }
        set { var rule = preferences.mentions ?? MentionSettings(); rule.text = newValue; preferences.mentions = rule }
    }
    var mentionMarkers: [String] { mentionEnabled ? (preferences.mentions?.markers ?? []) : [] }
    var status: String {
        if !issue.isEmpty { return l("Needs attention", "需要处理") }
        if state.alarming { return l("Ringing", "报警中") }
        return state.listening ? l("Alarm enabled", "闹铃已开启") : l("Alarm disabled", "闹铃未开启")
    }
    init() {
        preferences = UserDefaults.standard.data(forKey: "preferences").flatMap { try? JSONDecoder().decode(Preferences.self, from: $0) } ?? Preferences()
        audio.volume = preferences.volume
        let pollingTimer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(pollingTimer, forMode: .common)
        timer = pollingTimer
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }
    private func read(_ completion: @escaping (Result<Snapshot, Error>) -> Void) {
        let override = preferences.database
        queue.async {
            let result = Result { try NotificationDatabase.read(path: NotificationDatabase.locate(override: override)) }
            DispatchQueue.main.async { completion(result) }
        }
    }
    func startListening() {
        guard !starting, !state.listening else { return }
        guard !targets.isEmpty || !mentionMarkers.isEmpty else {
            issueMessage = AppMessage("Add a name for the alarm.", "请先添加触发闹铃的名字。")
            showSettings(); return
        }
        if mentionEnabled && mentionMarkers.isEmpty {
            issueMessage = AppMessage("Enter an @name or turn off mentions.", "请填写 @名字，或关闭 @ 提醒。")
            showSettings(); return
        }
        epoch += 1; let token = epoch; starting = true; issueMessage = nil
        read { [weak self] result in
            guard let self, self.epoch == token else { return }
            self.starting = false
            switch result {
            case .success(let snapshot): self.state.start(snapshot); self.refreshPower()
            case .failure(let error): self.issueMessage = self.readError(error)
            }
        }
    }
    func stopListening() { epoch += 1; starting = false; inFlight = false; state.stopListening(); refreshPower() }
    func tick() {
        guard state.listening, !inFlight else { return }
        inFlight = true; let token = epoch
        read { [weak self] result in
            guard let self, self.epoch == token else { return }
            self.inFlight = false
            switch result {
            case .success(let snapshot):
                let change = self.state.consume(snapshot, targets: self.targets, mentionMarkers: self.mentionMarkers)
                if change.startAlarm { self.playAlarm() }
            case .failure(let error): self.stopListening(); self.issueMessage = self.readError(error)
            }
        }
    }
    func testAlarm() { if state.testAlarm() { playAlarm() } }
    private func playAlarm() {
        do { try audio.start(); showAlarm() }
        catch {
            state.stopAlarm()
            issueMessage = AppMessage("Cannot play the alarm. Check the app bundle and audio output.", "无法播放闹铃，请检查应用文件和音频输出。")
        }
    }
    func stopAlarm() { audio.stop(); state.stopAlarm(); alarmWindow?.orderOut(nil) }
    func clearIssue() { issueMessage = nil }
    private func refreshPower() {
        if !power.update(active: state.listening && preferences.preventSleep) {
            issueMessage = AppMessage("Could not prevent idle sleep.", "无法阻止闲置休眠。")
        }
    }
    func inspect() {
        guard !inspecting else { return }
        sampleEpoch += 1; let token = sampleEpoch; inspecting = true
        samples = []; sampleMessage = nil
        read { [weak self] result in
            guard let self, self.sampleEpoch == token else { return }
            self.inspecting = false
            switch result {
            case .success(let snapshot):
                self.samples = snapshot.records.suffix(3).map {
                    Notice(id: $0.id, identity: "", delivered: $0.delivered, app: $0.app,
                           title: String($0.title.prefix(160)), subtitle: String($0.subtitle.prefix(160)), body: String($0.body.prefix(300)))
                }
                self.sampleMessage = self.samples.isEmpty
                    ? AppMessage("No Slack samples yet. Receive a desktop notification, then refresh.", "暂无 Slack 样本。收到桌面通知后刷新。")
                    : AppMessage("Latest 3 at most · kept in memory only", "最多显示最近 3 条，仅保留在内存中")
            case .failure(let error):
                self.sampleMessage = self.readError(error)
                self.issueMessage = self.readError(error)
                self.stopListening()
            }
        }
    }
    func clearSamples() { sampleEpoch += 1; inspecting = false; samples = []; sampleMessage = nil }
    private func readError(_ error: Error) -> AppMessage {
        guard let failure = error as? ReadFailure else {
            return AppMessage("Cannot read notifications. Restart and try again.", "无法读取通知，请重启后重试。")
        }
        switch failure {
        case .permission: return AppMessage("Access denied. Enable Full Disk Access, then quit and reopen the app.", "访问被拒绝。请开启完全磁盘访问权限，再退出并重开应用。")
        case .missing: return AppMessage("Notification database not found. Check Full Disk Access and receive a Slack notification.", "未找到通知数据库。请检查完全磁盘访问权限，并接收一条 Slack 通知。")
        case .busy: return AppMessage("Notification database is busy. Try again shortly.", "通知数据库正忙，请稍后重试。")
        case .unsupported: return AppMessage("This notification format is not supported.", "暂不支持此通知格式。")
        case .sqlite(let code): return AppMessage("Notification read failed (SQLite \(code)). Check access and restart.", "通知读取失败（SQLite \(code)），请检查权限并重启。")
        case .discovery: return AppMessage("Cannot locate the notification database.", "无法定位通知数据库。")
        }
    }
    func openPrivacy() { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!) }
    func showSettings() { showWindow("settings", view: SettingsView(model: self), size: NSSize(width: 500, height: 570)) }
    func showDiagnostics() { showWindow("diagnostics", view: DiagnosticsView(model: self), size: NSSize(width: 520, height: 490)) }
    private func refreshWindowTitles() {
        windows["settings"]?.title = "Slack Alarm · " + l("Settings", "设置")
        windows["diagnostics"]?.title = "Slack Alarm · " + l("Diagnostics", "诊断")
        alarmWindow?.title = "Slack Alarm · " + l("Alarm", "闹铃")
    }
    private func showWindow<V: View>(_ key: String, view: V, size: NSSize) {
        if let window = windows[key] { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: view); window.center(); windows[key] = window
        refreshWindowTitles()
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    private func showAlarm() {
        if alarmWindow == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 260), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.level = .floating; w.isReleasedWhenClosed = false
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            w.contentView = NSHostingView(rootView: AlarmView(model: self)); w.center(); alarmWindow = w
            refreshWindowTitles()
        }
        alarmWindow?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func shutdown() {
        stopListening(); stopAlarm(); clearSamples(); power.release(); timer?.invalidate()
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
    }
}
