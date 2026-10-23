import AppKit
import AVFoundation
import IOKit.pwr_mgt

@MainActor final class AlarmAudio {
    private var player: AVAudioPlayer?
    var volume: Float = 0.7 { didSet { player?.volume = volume } }
    func start() throws {
        guard player?.isPlaying != true else { return }
        // Generated bundled PCM tone: no shell, system volume changes, or external audio dependencies.
        let url = Bundle.main.url(forResource: "Alarm", withExtension: "wav")
        guard let url else { throw NSError(domain: "SlackAlarm", code: 1, userInfo: [NSLocalizedDescriptionKey: "内置闹铃文件缺失；请使用构建脚本生成 .app。 "]) }
        let p = try AVAudioPlayer(contentsOf: url); p.numberOfLoops = -1; p.volume = volume
        guard p.prepareToPlay(), p.play() else { throw NSError(domain: "SlackAlarm", code: 2, userInfo: [NSLocalizedDescriptionKey: "音频输出无法启动，请检查输出设备。 "]) }
        player = p
    }
    func stop() { player?.stop(); player = nil }
}
@MainActor final class IdleSleepAssertion {
    private var id: IOPMAssertionID = 0
    func update(active: Bool) -> Bool {
        if !active { release(); return true }
        if id != 0 { return true }
        return IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleSystemSleep as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), "Slack Alarm enabled" as CFString, &id) == kIOReturnSuccess
    }
    func release() { if id != 0 { IOPMAssertionRelease(id); id = 0 } }
}
