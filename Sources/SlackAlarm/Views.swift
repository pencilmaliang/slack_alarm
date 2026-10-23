import SwiftUI
import SlackAlarmCore

struct SettingsView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Slack Alarm").font(.title2.bold())
                    Spacer()
                    Picker(model.l("Language", "语言"), selection: Binding(get: { model.language }, set: { model.language = $0 })) {
                        Text("English").tag("en")
                        Text("中文").tag("zh")
                    }.frame(width: 200)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.l("Names that trigger the alarm", "触发闹铃的名字")).font(.headline)
                    TextEditor(text: $model.preferences.names)
                        .font(.body).frame(height: 76).padding(5)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.secondary.opacity(0.3)))
                        .accessibilityLabel(model.l("Names, one per line", "名字，每行一个"))
                    Text(model.l("One per line · matches text in the title or subtitle.", "每行一个，匹配通知标题或副标题中包含的名字。"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(model.l("@ mentions", "@ 提醒"), isOn: Binding(get: { model.mentionEnabled }, set: { model.mentionEnabled = $0 }))
                    TextEditor(text: Binding(get: { model.mentionText }, set: { model.mentionText = $0 }))
                        .font(.body).frame(height: 45).padding(5)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.secondary.opacity(0.3)))
                        .disabled(!model.mentionEnabled)
                        .accessibilityLabel(model.l("Mention text, one per line", "@ 文字，每行一个"))
                    Text(model.l("Use the exact @text in a sample, one per line.", "填写样本中实际显示的 @文字，每行一个。"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Divider()
                HStack {
                    Text(model.l("Volume", "音量"))
                    Slider(value: $model.preferences.volume, in: 0...1)
                    Text("\(Int(model.preferences.volume * 100))%").monospacedDigit().frame(width: 42)
                }
                Toggle(model.l("Prevent idle sleep while alarm is enabled", "闹铃开启时阻止闲置休眠"), isOn: $model.preferences.preventSleep)
                Divider()
                HStack {
                    Button(model.state.listening ? model.l("Disable alarm", "关闭闹铃") : model.l("Enable alarm", "开启闹铃")) {
                        if model.state.listening { model.stopListening() } else { model.startListening() }
                    }.buttonStyle(.borderedProminent).disabled(model.working)
                    Button(model.state.alarming ? model.l("Stop ringing", "停止当前闹铃") : model.l("Test alarm", "测试闹铃")) {
                        if model.state.alarming { model.stopAlarm() } else { model.testAlarm() }
                    }
                    Spacer()
                    Button(model.l("Diagnostics", "诊断")) { model.showDiagnostics() }
                }
                Text(model.l("Mute, headphones and sleep affect the alarm.", "静音、耳机输出和休眠会影响闹铃。"))
                    .font(.caption).foregroundStyle(.secondary)
                if !model.issue.isEmpty { Text(model.issue).font(.callout).foregroundStyle(.red) }
            }.padding(22)
        }.frame(minWidth: 480, minHeight: 540)
    }
}
struct DiagnosticsView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(model.l("Full Disk Access", "完全磁盘访问权限")).font(.title2.bold())
                Text(model.l("Needed to read Slack notifications locally. Enable access, then quit and reopen Slack Alarm.", "用于在本机读取 Slack 通知。开启权限后，请退出并重新打开 Slack Alarm。"))
                Button(model.l("Open System Settings", "打开系统设置")) { model.openPrivacy() }
                Text(model.l("This permission covers other apps’ notifications. Slack Alarm only decodes Slack messages and sends nothing online.", "此权限可访问其他应用的通知。Slack Alarm 仅解析 Slack 消息，不联网发送数据。"))
                    .font(.caption).foregroundStyle(.secondary)
                Divider()
                HStack {
                    Text(model.l("Slack message samples", "Slack 消息样本")).font(.headline)
                    Spacer()
                    Button(model.l("View / refresh", "查看 / 刷新")) { model.inspect() }.disabled(model.inspecting)
                    Button(model.l("Clear", "清除")) { model.clearSamples() }
                }
                if model.inspecting { ProgressView().controlSize(.small) }
                if let message = model.sampleMessage { Text(model.text(message)).font(.caption).foregroundStyle(.secondary) }
                ForEach(model.samples, id: \.id) { sample in
                    VStack(alignment: .leading, spacing: 6) {
                        sampleField(model.l("Title", "标题"), sample.title)
                        sampleField(model.l("Subtitle", "副标题"), sample.subtitle)
                        sampleField(model.l("Message", "正文"), sample.body)
                    }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                }
                if model.sampleMessage == nil && !model.inspecting {
                    Text(model.l("View a recent notification to check how names appear.", "查看最近的通知，了解名字的显示方式。"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !model.issue.isEmpty {
                    Text(model.issue).font(.callout).foregroundStyle(.red)
                    Button(model.l("Dismiss", "清除提示")) { model.clearIssue() }
                }
            }.padding(22)
        }.frame(minWidth: 490, minHeight: 380)
    }
    private func sampleField(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title).foregroundStyle(.secondary).frame(width: 65, alignment: .leading)
            Text(value.isEmpty ? "—" : value).textSelection(.enabled)
        }.font(.callout)
    }
}
struct AlarmView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(spacing: 20) {
            AlarmLogo().frame(width: 72, height: 72).accessibilityLabel("Slack Alarm")
            Text(model.l("Slack Alarm is ringing", "Slack Alarm 正在响铃")).font(.title2.bold())
            Button(model.l("Stop ringing", "停止当前闹铃")) { model.stopAlarm() }
                .buttonStyle(.borderedProminent).controlSize(.large)
            Text(model.state.listening ? model.l("New messages can trigger the alarm again.", "停止后，新消息仍可再次触发闹铃。") : model.l("Alarms for new messages are disabled.", "新消息闹铃已关闭。"))
                .font(.caption).foregroundStyle(.secondary)
        }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct AlarmLogo: NSViewRepresentable {
    func makeNSView(context: Context) -> AlarmLogoView { AlarmLogoView() }
    func updateNSView(_ nsView: AlarmLogoView, context: Context) {}
}
private final class AlarmLogoView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.scaleBy(x: bounds.width / 1024, y: bounds.height / 1024)
        IconArtwork.applicationIcon(context)
    }
}
