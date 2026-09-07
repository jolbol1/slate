import AVFoundation

/// Plays bundled sounds only. No recording, microphone access or network request is used.
final class SlateAudioPlayer {
    private var players: [SlateSound: AVAudioPlayer] = [:]

    init(bundle: Bundle = .main) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])

        for sound in SlateSound.allCases {
            guard let url = bundle.url(forResource: sound.rawValue, withExtension: "wav"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.prepareToPlay()
            players[sound] = player
        }
    }

    func play(_ sound: SlateSound, volume: Float) {
        guard let player = players[sound] else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        player.stop()
        player.currentTime = 0
        player.volume = min(1, max(0, volume))
        player.play()
    }
}
