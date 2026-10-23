# Changelog

## v1.1.2-beta.1 — first public preview

App version 1.1.2, build 8. Packaging/documentation release; no new application behavior.

- MIT license; English and Chinese installation guidance.
- App-only Apple Silicon ZIP, SHA-256 checksum, clean source ZIP.
- Reproducible local pre-release packaging; no Developer ID signing or notarization.
- GitHub release notes, publishing guide, and redaction-aware issue template.
- Compatibility and unverified end-to-end behavior explicitly documented.

## 1.1.2

- Reworded enable/disable state around “alarm” rather than “listening”.
- Distinguished disabling new alarms from stopping the current sound.

## 1.1.1

- Removed stop shortcuts and Carbon hotkey registration.
- Kept @mention settings expanded.
- Unified the Diagnostics label; used the app logo in the ringing window.

## 1.1.0

- Renamed Slack Wake to Slack Alarm; smaller menu bar logo.
- Automatic name substring matching in either title or subtitle, excluding body text.
- Removed strict/loose modes and sender validation prerequisite.
- English default with persistent Chinese language selection; simplified settings.

## 1.0.4

- Fixed snapshot/start-time race, menu-mode polling, unknown payload-field handling,
  and packaging metadata issues.
