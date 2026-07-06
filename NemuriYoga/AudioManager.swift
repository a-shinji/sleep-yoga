import AVFoundation
import Combine
import MediaPlayer

/// BGMとガイド音声の2つのAVAudioPlayerを束ねて、1つのセッションとして再生する。
///
/// - BGMは無限ループ・小音量、ガイドは間(無音)を焼き込んだ1本の音声を等速再生
/// - Background Modes (audio) + .playbackカテゴリでバックグラウンド再生
/// - ロック画面/コントロールセンターの再生・一時停止に応答
final class AudioManager: NSObject, ObservableObject {

    enum PlaybackState {
        case idle
        case playing
        case paused
        case finished
    }

    static let sessionTitle = "筋弛緩リラクセーション"
    static let appName = "ねむりヨガ"

    @Published private(set) var state: PlaybackState = .idle
    @Published private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0

    private var bgmPlayer: AVAudioPlayer?
    private var guidePlayer: AVAudioPlayer?
    private var uiTimer: Timer?

    /// ガイドの声を邪魔しないBGM音量
    private let bgmVolume: Float = 0.35
    /// ガイド終了後にBGMをフェードアウトさせる秒数
    private let fadeOutSeconds: TimeInterval = 8

    override init() {
        super.init()
        loadPlayers()
        setUpRemoteCommands()
        observeNotifications()
    }

    // MARK: - セットアップ

    private func loadPlayers() {
        guard
            let bgmURL = Bundle.main.url(forResource: "bgm", withExtension: "m4a"),
            let guideURL = Bundle.main.url(forResource: "guide", withExtension: "m4a")
        else {
            assertionFailure("bgm.m4a / guide.m4a がバンドルに見つかりません")
            return
        }
        bgmPlayer = try? AVAudioPlayer(contentsOf: bgmURL)
        guidePlayer = try? AVAudioPlayer(contentsOf: guideURL)

        bgmPlayer?.numberOfLoops = -1
        bgmPlayer?.volume = bgmVolume
        guidePlayer?.delegate = self

        bgmPlayer?.prepareToPlay()
        guidePlayer?.prepareToPlay()
        duration = guidePlayer?.duration ?? 0
    }

    private func setUpRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.play() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.togglePlayPause() }
            return .success
        }
        center.changePlaybackPositionCommand.isEnabled = false
        center.nextTrackCommand.isEnabled = false
        center.previousTrackCommand.isEnabled = false
    }

    private func observeNotifications() {
        let nc = NotificationCenter.default
        nc.addObserver(
            self, selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification, object: nil)
        nc.addObserver(
            self, selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification, object: nil)
    }

    // MARK: - 再生操作

    func togglePlayPause() {
        state == .playing ? pause() : play()
    }

    func play() {
        guard let bgm = bgmPlayer, let guide = guidePlayer else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            return
        }

        if state == .finished {
            guide.currentTime = 0
            bgm.currentTime = 0
        }
        bgm.volume = bgmVolume

        // 同一ホスト時刻を基準に2プレイヤーを同期スタート
        let startAt = bgm.deviceCurrentTime + 0.1
        bgm.play(atTime: startAt)
        guide.play(atTime: startAt)

        state = .playing
        startUITimer()
        updateNowPlaying()
    }

    func pause() {
        guard state == .playing else { return }
        bgmPlayer?.pause()
        guidePlayer?.pause()
        state = .paused
        stopUITimer()
        updateNowPlaying()
    }

    /// ガイド終了後: BGMをゆっくりフェードアウトして停止
    private func finishSession() {
        state = .finished
        currentTime = duration
        stopUITimer()

        bgmPlayer?.setVolume(0, fadeDuration: fadeOutSeconds)
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeOutSeconds + 0.5) { [weak self] in
            guard let self, self.state == .finished else { return }
            self.bgmPlayer?.stop()
            self.bgmPlayer?.currentTime = 0
            self.bgmPlayer?.prepareToPlay()
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            try? AVAudioSession.sharedInstance().setActive(
                false, options: .notifyOthersOnDeactivation)
        }
    }

    // MARK: - ロック画面表示

    private func updateNowPlaying() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: Self.sessionTitle,
            MPMediaItemPropertyArtist: Self.appName,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: guidePlayer?.currentTime ?? 0,
        ]
        info[MPNowPlayingInfoPropertyPlaybackRate] = (state == .playing) ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - 割り込み・経路変更

    @objc private func handleInterruption(_ notification: Notification) {
        guard
            let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: raw)
        else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch type {
            case .began:
                if self.state == .playing { self.pause() }
            case .ended:
                let optRaw =
                    notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                let options = AVAudioSession.InterruptionOptions(rawValue: optRaw)
                if options.contains(.shouldResume), self.state == .paused {
                    self.play()
                }
            @unknown default:
                break
            }
        }
    }

    /// イヤホンが抜かれたら一時停止(スピーカーで鳴り出すのを防ぐ)
    @objc private func handleRouteChange(_ notification: Notification) {
        guard
            let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue: raw),
            reason == .oldDeviceUnavailable
        else { return }
        DispatchQueue.main.async { [weak self] in
            if self?.state == .playing { self?.pause() }
        }
    }

    // MARK: - 進捗表示用タイマー

    private func startUITimer() {
        stopUITimer()
        uiTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, let guide = self.guidePlayer else { return }
            self.currentTime = guide.currentTime
        }
    }

    private func stopUITimer() {
        uiTimer?.invalidate()
        uiTimer = nil
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.finishSession()
        }
    }
}
