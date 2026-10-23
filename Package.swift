// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "SlackAlarm", platforms: [.macOS(.v13)], products: [
    .executable(name: "SlackAlarm", targets: ["SlackAlarm"]),
    .executable(name: "SlackAlarmProbe", targets: ["SlackAlarmProbe"])
], targets: [
    .target(name: "SlackAlarmCore", linkerSettings: [.linkedLibrary("sqlite3")]),
    .executableTarget(name: "SlackAlarm", dependencies: ["SlackAlarmCore"], linkerSettings: [.linkedFramework("IOKit")]),
    .executableTarget(name: "SlackAlarmProbe", dependencies: ["SlackAlarmCore"]),
    .testTarget(name: "SlackAlarmCoreTests", dependencies: ["SlackAlarmCore"]),
    .testTarget(name: "SlackAlarmAppTests", dependencies: ["SlackAlarm"])
])
