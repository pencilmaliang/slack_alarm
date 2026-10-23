# 上传 GitHub 并发布测试版

## 1. 上传源码

使用 `SlackAlarm-1.1.2-beta.1-source.zip` 解压出的 `Slack Alarm` 文件夹作为仓库根目录。源码包不含应用、缓存、历史版本或本机通知。

在 GitHub 创建名为 `SlackAlarm` 的 Public 仓库。上传解压后的内容（不要上传源码 ZIP 本身，不要多套一层文件夹）；根目录应直接看到 `Package.swift`、`Sources`、`README.md`、`LICENSE` 等。`.gitignore` 和 `.github` 是隐藏项，Finder 可按 ⌘⇧. 显示后一起上传。不要上传 `dist/`、`work/`、旧版本或发布包。建议从独立目录上传，不要误用迁移项目外层的 Git 仓库。

如通过 Git 推送，先在独立源码目录初始化并提交，再按 GitHub 新仓库页面提供的 remote/push 命令操作。不要把证书、私钥或账号凭据提交到仓库。

## 2. 创建 Release

进入仓库 **Releases → Draft a new release**：

- Tag：`v1.1.2-beta.1`，选择创建新标签，目标为刚上传源码的分支。
- Title：`Slack Alarm 1.1.2 Beta 1`。
- Description：复制 `docs/RELEASE_NOTES.md` 的内容。
- 附件：`SlackAlarm-1.1.2-beta.1-macOS-arm64.zip` 和 `SHA256SUMS.txt`。
- 勾选 **This is a pre-release**。不要设为正式 Latest Release。
- 检查附件完整后点击 **Publish release**。

源码 ZIP 用来上传仓库，不需要重复放在 Release；GitHub 会提供标签对应的 Source code。不要上传之前包含源码的混合安装包，也不要直接上传 `.app` 目录。

应用内部仍显示 1.1.2 / build 8；beta.1 表示 GitHub 发布渠道，不修改功能版本。

## 3. 发布后验收

从公开 Release 页面重新下载应用 ZIP，在非同步目录解压；核对校验值。最好在另一台 Mac 或新用户账户测试首次打开、完全磁盘访问权限和真实 Slack 通知。下载前的本机签名校验不能代替该验收。

逐项记录：

- [ ] 首次下载和打开的系统提示符合安装说明。
- [ ] 授权、退出重开后能查看 Slack 样本。
- [ ] 旧通知不触发；新目标消息持续响铃。
- [ ] 点击停止后，下条新消息可再触发。
- [ ] 非目标和仅正文提及名字不触发；@ 规则单独验证。
- [ ] 中英文切换、菜单栏、音量及退出正常。
- [ ] 权限撤销／重新授予、睡眠恢复后的状态正确。

发现问题后保留原 Release，用新 beta 标签发布修复，不要无说明地替换相同名称的二进制。

## 4. 下次重新制作发布包

在 macOS、Python 3 和 Swift 工具链可用时：

```bash
./scripts/package-prerelease.sh
```

脚本在临时目录构建并验证临时签名，再生成应用 ZIP、源码 ZIP 和应用校验文件；输出到项目 `release-assets/`（被 Git 忽略）。可用 `RELEASE_OUTPUT=/absolute/path` 改变输出位置。没有联网上传、Developer ID 签名或公证步骤。

[GitHub 官方发布步骤](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository?tool=webui)
