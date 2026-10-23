# Install Slack Alarm — beta

**Apple Silicon only · macOS 13+ deployment target · ad-hoc signed · not Apple-notarized.**
This experimental app uses an undocumented notification database. Compatibility with every macOS/Slack version is not guaranteed. Build/test environment: macOS 15.7.7 arm64. Real notification access and end-to-end behavior still need testing on your Mac.

## English

1. Download `SlackAlarm-1.1.2-beta.1-macOS-arm64.zip` from this project's GitHub Release assets. The automatically generated “Source code” downloads are not the app.
2. Unzip, quit any older Slack Alarm / Slack Wake instance, and move `Slack Alarm.app` into a fixed, non-synced Applications folder. Launch it there. It is a menu bar app, with no Dock icon.
3. This beta has no Developer ID signature or Apple notarization. macOS may block it. Only if you trust the source, follow Apple's per-app **System Settings → Privacy & Security → Open Anyway** procedure, when offered. Do not disable Gatekeeper or SIP. If macOS reports malware or damage, stop and report the exact warning rather than bypassing it. [Apple's official instructions](https://support.apple.com/102445).
4. In the app's **Diagnostics**, click **Open System Settings**. Add the actual `Slack Alarm.app` to **Full Disk Access**, enable it, then quit and reopen the app. The app needs this to read the local notification database; it can expose other apps' notifications, although this app only decodes Slack payloads.
5. In **Settings**, enter names, one per line. Enable Slack desktop notifications and message previews, and ensure they appear in macOS Notification Center. Turn off Focus for testing and switch away from the target Slack conversation.
6. Click **Test alarm**, then **Stop ringing**. Click **Enable alarm** and have a colleague send a new message. Names match substrings in either notification title or subtitle. Message bodies are excluded unless you separately enable literal @mentions.
7. Stop ringing silences the current sound; future messages may ring again. Disable alarm prevents new triggers, but does not silence an existing sound. Quit stops everything.

English is the default; choose 中文 in Settings. No global stop shortcut is registered. Volume changes only the app. Mute, headphones and sleep affect audibility. Replacing/re-signing/moving the app may require removing and re-adding Full Disk Access.

If no alarm triggers: use Diagnostics to view recent samples, check permissions after restarting, confirm Slack produced a system notification, and check whether the name appears in a title/subtitle. Do not post private sample contents in a public issue.

Optional checksum verification (place both files in the same directory):

```bash
shasum -a 256 -c SHA256SUMS.txt
```

A matching checksum detects file changes; it does not replace developer signing or Apple notarization.

## 中文

1. 从本项目 GitHub Release 的附件下载 `SlackAlarm-1.1.2-beta.1-macOS-arm64.zip`。自动生成的 Source code 是源码，不是应用。
2. 解压，退出旧版 Slack Alarm / Slack Wake，将 `Slack Alarm.app` 放到固定的非同步 Applications 目录再打开。应用只显示在菜单栏，没有 Dock 图标。
3. 此测试版只有临时签名，没有 Developer ID 签名或 Apple 公证，系统可能阻止打开。仅在信任来源时，按照 [Apple 官方说明](https://support.apple.com/102445)，使用系统设置 → 隐私与安全性中提供的「仍要打开」。不要关闭 Gatekeeper 或 SIP。若提示恶意软件或文件损坏，请停止并反馈原始错误，不要绕过。
4. 在应用「诊断」中打开系统设置，为实际运行的 `.app` 开启完全磁盘访问权限，再退出并重开。此权限可以接触其他应用通知，但本程序只解析 Slack 数据，不联网、不保存正文。
5. 在设置中每行填写一个名字。开启 Slack 桌面通知和消息预览，确认通知进入 macOS 通知中心；测试时关闭勿扰并切到其他对话。
6. 先测试闹铃并停止，再开启闹铃，让同事发送新消息。名字匹配标题或副标题中包含的文字；正文仅在单独启用 @ 提醒时参与对应规则。
7. 停止当前闹铃后，新消息仍可触发；关闭闹铃仅阻止新触发，当前声音需单独停止。退出应用会停止全部活动。

仅提供 Apple Silicon 包。macOS 13 是最低部署目标，不代表所有系统通知数据库均已验证。默认英文，可在设置切换中文。没有全局快捷键。系统静音、耳机和休眠影响出声；升级或移动路径后可能需要重新授权。

无法触发时检查权限、系统通知和诊断中的样本；不要把私密消息样本贴到公开 Issue。可使用上面的 SHA-256 命令校验下载文件，但它不等于 Apple 签名或公证。
