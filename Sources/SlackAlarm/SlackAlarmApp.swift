import AppKit
import Combine

// AppKit owns startup and the status item. SwiftUI is used for the existing
// settings/diagnostics/alarm windows, without relying on MenuBarExtra onAppear.
@MainActor final class ApplicationDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var model: AppModel?
    private var statusItem: NSStatusItem?
    private var subscription: AnyCancellable?
    private var menuTracking = false
    private var logoView: StatusLogoView?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = AppModel()
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            statusItem?.length = 25
            let logo = StatusLogoView(frame: button.bounds)
            logo.autoresizingMask = [.width, .height]
            button.addSubview(logo); logoView = logo
            button.setAccessibilityLabel("Slack Alarm")
        }
        refreshMenu()
        subscription = model.objectWillChange.sink { [weak self] _ in
            // objectWillChange precedes the mutation; render on the next main turn.
            DispatchQueue.main.async { self?.refreshMenu() }
        }
        if !UserDefaults.standard.bool(forKey: "explainedPermission") {
            UserDefaults.standard.set(true, forKey: "explainedPermission")
            model.showDiagnostics()
        } else {
            model.showSettings()
        }
    }
    private func refreshMenu() {
        guard let model else { return }
        statusItem?.button?.title = ""
        logoView?.listening = model.state.listening
        statusItem?.button?.setAccessibilityValue(model.status)
        statusItem?.button?.toolTip = "Slack Alarm · \(model.status)"
        guard !menuTracking else { return }
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        func add(_ title: String, _ action: Selector?, enabled: Bool = true) {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self; item.isEnabled = enabled; menu.addItem(item)
        }
        add("Slack Alarm · \(model.status)", nil, enabled: false)
        if !model.issue.isEmpty { add(model.issue, nil, enabled: false) }
        menu.addItem(.separator())
        add(model.state.listening ? model.l("Disable alarm", "关闭闹铃") : model.l("Enable alarm", "开启闹铃"), #selector(toggleListening), enabled: !model.working)
        add(model.l("Stop alarm", "停止当前闹铃"), #selector(stopAlarm), enabled: model.state.alarming)
        add(model.l("Test alarm", "测试闹铃"), #selector(testAlarm))
        menu.addItem(.separator())
        add(model.l("Settings…", "设置…"), #selector(showSettings))
        add(model.l("Diagnostics…", "诊断…"), #selector(showDiagnostics))
        add(model.l("Quit Slack Alarm", "退出 Slack Alarm"), #selector(quit))
        statusItem?.menu = menu
    }
    func menuWillOpen(_ menu: NSMenu) { menuTracking = true }
    func menuDidClose(_ menu: NSMenu) {
        menuTracking = false
        DispatchQueue.main.async { [weak self] in self?.refreshMenu() }
    }
    @objc private func toggleListening() {
        guard let model else { return }
        if model.state.listening { model.stopListening() } else { model.startListening() }
    }
    @objc private func stopAlarm() { model?.stopAlarm() }
    @objc private func testAlarm() { model?.testAlarm() }
    @objc private func showSettings() { model?.showSettings() }
    @objc private func showDiagnostics() { model?.showDiagnostics() }
    @objc private func quit() { NSApp.terminate(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        model?.showSettings()
        return true
    }
    func applicationWillTerminate(_ notification: Notification) {
        model?.shutdown(); subscription?.cancel()
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
        statusItem = nil
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
@main enum SlackAlarmApp {
    @MainActor static func main() {
        let application = NSApplication.shared
        let delegate = ApplicationDelegate()
        application.setActivationPolicy(.accessory)
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}
