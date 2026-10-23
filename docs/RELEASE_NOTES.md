# Slack Alarm 1.1.2 Beta 1

**Pre-release · Apple Silicon (arm64) · no Developer ID signature or Apple notarization**

A local macOS menu bar alarm for selected Slack notifications. No Slack API, token, external server, or network requests.

### Download and install

Download **SlackAlarm-1.1.2-beta.1-macOS-arm64.zip** below. It contains the app, bilingual installation instructions, and MIT license. The GitHub “Source code” archives are for developers.

Quit older versions, extract the ZIP, and move the app into a fixed, non-synced Applications folder. Grant **Full Disk Access**, then quit and reopen it. This is an ad-hoc-signed beta: macOS may block launch. Read the included `INSTALL.md` and [Apple's instructions](https://support.apple.com/102445). Do not disable Gatekeeper or SIP.

### Features

- Names match text in either notification title or subtitle.
- Optional literal @mentions in message text.
- Continuous app-local audio until stopped; no global shortcut.
- English / 中文 settings; compact menu bar icon.
- Diagnostics for permissions and recent Slack message samples.
- Optional idle-sleep prevention while alarms are enabled.

### Tested and limited

Debug/Release builds and 14 automated tests passed on macOS 15.7.7 arm64 / Swift 6.2.4. The ZIP-extracted app passes local signature-integrity verification; this is **not** Gatekeeper approval or Apple notarization.

macOS 13+ is the deployment target, not a promise of database compatibility. Intel is not included. The private notification database may change. New real Slack notifications, desktop UI, audio, permission changes and sleep/wake have not been independently verified end-to-end in the current build environment. Missing previews, Focus, Slack suppressing a notification, or database delays/cleanup may cause missed alarms. Substring name matching can cause false positives. Do not rely on this as a guaranteed emergency alert.

Full Disk Access can expose other apps' notifications. This app only decodes Slack and does not save message bodies or send data online. Share only redacted reports in Issues.

App version: **1.1.2 (build 8)**. Release tag: **v1.1.2-beta.1**. MIT licensed; not affiliated with or endorsed by Slack.

---

## 中文

这是首个公开 **Pre-release 测试版**，仅支持 Apple Silicon，尚无 Developer ID 签名或 Apple 公证。

下载下方 `SlackAlarm-1.1.2-beta.1-macOS-arm64.zip`，退出旧版后解压并将应用放到固定的非同步目录。开启完全磁盘访问权限后退出重开，按照包内 `INSTALL.md` 完成设置。GitHub 自动提供的 Source code 是源码，不是可运行应用。

支持标题／副标题名字匹配、可选正文 @ 提醒、持续闹铃、中英文界面、诊断与消息样本，以及防闲置休眠。没有停止快捷键。停止当前声音后，新消息仍可再次触发；关闭闹铃阻止新触发，但不自动停止当前声音。

构建和 14 项测试通过；未完成当前环境下真实 Slack 通知、桌面交互、出声、权限变化及睡眠恢复的端到端验收。macOS 13 仅是最低部署目标。通知数据库变化、通知缺失和预览隐藏可能导致漏报，名字包含匹配也可能误报。

应用仅在本机处理通知，不保存正文、不联网。反馈时请勿公开私密通知内容。MIT 许可；本项目与 Slack 官方无关联。
