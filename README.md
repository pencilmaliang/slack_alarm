# Slack Alarm

A native macOS menu bar alarm for Slack notifications. Everything runs locally: no Slack API, token, server, or network requests.

[中文说明](README.zh-CN.md)

**Public preview: v1.1.2-beta.1 · Apple Silicon only · MIT license**

This beta is ad-hoc signed, **not Developer ID signed or Apple-notarized**. It may be blocked by macOS. Minimum deployment is macOS 13; real notification compatibility is not verified on every OS release.

Download the app ZIP from this repository's **Releases**, not the “Source code” archives. See [installation](docs/INSTALL.md), [release notes](docs/RELEASE_NOTES.md), [changelog](CHANGELOG.md), and [publishing guide](docs/PUBLISH.zh-CN.md).


## Version 1.1.2

- Renamed from Slack Wake to **Slack Alarm**.
- Smaller menu bar icon: drawing area capped at 17 pt, with a 25 pt menu bar slot.
- Names automatically match text contained in either notification title or subtitle, ignoring case and surrounding whitespace. Message bodies are excluded from this name rule.
- No matching modes, sender-field selection, or validation prerequisite.
- Simplified **Settings** and **Diagnostics** windows.
- English by default; switch to 中文 in Settings. The choice persists, and menus, windows, and status messages update immediately.
- Body `@mentions` are always visible, with an enable switch; existing mention preferences are retained.
- Removed stop shortcuts; stop using the window, settings, or menu. The alarm window uses the app logo.

## Start

1. Quit the old app. Put the downloaded `Slack Alarm.app` in a fixed, non-synced location such as your local Applications folder, then open it.
2. In **Diagnostics**, open System Settings and grant **Full Disk Access** to the actual app. Quit and reopen after granting access.
3. Add names in **Settings**, one per line. Click **Enable alarm**. No sample check or validation is required.
4. Use **Test alarm** to check sound. Stop via the alarm window, settings, or menu.
5. **View / refresh** optionally shows up to three recent Slack notifications, including limited message text. Samples remain in memory only; Clear removes them.

Alarms are disabled at launch. Historical notifications do not trigger. Stop ringing silences the current alarm; new messages can trigger it again. Disable alarm prevents new triggers but does not silence an already ringing alarm. Quit stops audio and releases resources. Editing name or mention rules disables the alarm; enable it again to use the new rules. Changing language or volume does not disable it.

The red center of the menu icon means the alarm is enabled. Hover or open the menu for detailed state.

## Slack setup and matching

Enable desktop notifications, direct messages, @mentions, and message previews in Slack and macOS. Verify that Slack notifications reach macOS Notification Center. Disable Focus / Do Not Disturb when testing, and switch away from the target conversation.

A name in **either title or subtitle** is enough to match. This is a substring rule, so a longer name, channel, or workspace containing the target name can also trigger. Names do not identify Slack user IDs. Plain mentions of a name in the message body do not trigger the name rule.

Optional `@mentions` match literal body text, not Slack's semantic mention metadata. Enter the exact `@text` visible in a sample. Quoted mentions can trigger; hidden/truncated previews can miss matches. The mention rule is independent of the name rule.

No system notification means nothing to detect. Delivery and database writes can be delayed; records can disappear between checks. This is not a guaranteed emergency alert channel. Mute, headphones, output changes, and sleep affect sound. Volume only changes this app. Idle-sleep prevention does not override closing the lid or deliberate sleep.

## Build and test

macOS 13+ deployment target, Swift tools 5.9+. Version 1.1.2 was built on macOS 15.7.7 arm64 with Swift 6.2.4. Notification database compatibility is separate from the deployment target; Intel and other OS versions are not verified for this release.

Requires an Xcode / Command Line Tools Swift toolchain, Python 3 standard library, and system signing tools. No third-party dependencies.

```bash
./scripts/build.sh
# Default output: dist/Slack Alarm.app

export CLANG_MODULE_CACHE_PATH="$PWD/.build-local/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"
swift test --disable-sandbox --scratch-path .build-local/swift
```

`--disable-sandbox` applies to SwiftPM's build process, not system security. The app itself is not App Sandbox enabled.

If the project is in a cloud-synced folder, use a non-synced output directory. On the development machine, the Documents file provider re-added Finder metadata after signing, invalidating later signature checks:

```bash
DIST_ROOT=/private/tmp/SlackAlarm-local ./scripts/build.sh
codesign --verify --strict '/private/tmp/SlackAlarm-local/Slack Alarm.app'
```

`BUILD_ROOT` overrides the build-cache location. `DIST_ROOT` overrides the output folder. The script removes only signing-incompatible FinderInfo/ResourceFork metadata from its new staged bundle. It does not modify source attributes or disable Gatekeeper.

Default signing is ad hoc, not Developer ID, and the app is not notarized. macOS may block or warn about downloaded applications. Use `SIGN_IDENTITY="Your Certificate" ./scripts/build.sh` for a stable local signing identity. Rebuilding, moving, or re-signing can require adding the app to Full Disk Access again.

The bundle identifier remains `local.slackwake.app` so existing preferences survive the rename. Old mode, sender-confirmation, and shortcut values are ignored; old names, volume, and optional mentions are kept. Do not run the old and new apps together.

## Privacy and implementation

Full Disk Access can expose other apps' notification data. Slack Alarm only decodes Slack payloads and never saves message bodies or sends data online. Settings are stored in local UserDefaults. Samples are limited to three records with 160-character titles/subtitles and 300-character bodies, shown only on request.

The reader discovers the current user's Group Containers or DARWIN_USER_DIR notification database, validates the schema, and reads through a SQLite read-only transaction with WAL support on a background queue. It never copies only the main database file or edits the system database. The private database layout can change across OS releases; unsupported formats and permission failures are visible and disable the alarm.

Snapshots are checked about every second, including during menu tracking. Identity-based deduplication, a baseline timestamp captured before reading, and conservative resets on database replacement/ID rollback prevent history replay. A rebuild snapshot may be skipped; sleep-time notifications already removed cannot be recovered. No accessibility fallback or simulated notification reader is used.

Developer-only read diagnostics remain available as `dist/SlackAlarmProbe`; `--watch 60` observes arrivals without ringing. `--show-sample` explicitly prints limited notification metadata; avoid sharing it unredacted. CLI access does not prove the GUI app has Full Disk Access.

## Verification

For 1.1.2 on macOS 15.7.7 / Swift 6.2.4:

- Debug and Release builds passed.
- **14 XCTest tests passed**, covering header-only matching, both header layouts, history isolation, batch/deduplication, single-alarm state, stopping/restarting, database rebuilds, timestamp boundaries, unsupported formats, SQLite WAL, optional mentions, old settings migration, and language persistence.
- The packaged app passed `codesign --verify --strict`, including after ZIP extraction.
- Desktop UI inspection was blocked by Computer Use permissions. Actual icon appearance, English/Chinese layout and switching, sound, Full Disk Access changes, and sleep/wake remain manual checks.
- The migration review's real database read was denied both inside and outside the execution sandbox. No new real Slack notification or end-to-end alarm validation is claimed for this machine.

Manual checks: receive a target notification, stop its alarm, receive another; confirm non-target messages and body-only name mentions do not ring; hold the menu open during arrival; switch language and relaunch; revoke/regrant access; sleep and wake. Test optional @mentions separately.

## License

[MIT](LICENSE). Not affiliated with or endorsed by Slack.

## Repository layout

`Sources/SlackAlarmCore` contains reading, parsing, matching and state; `Sources/SlackAlarm` contains UI/audio/power services; `Tests` contains the core and settings tests. `scripts/build.sh` packages the app.

Use this folder as the repository root. Keep build caches and `dist/` out of Git (already covered by `.gitignore`); publish application ZIPs as GitHub Release assets.
