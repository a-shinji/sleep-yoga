import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var audio: AudioManager

    var body: some View {
        ZStack {
            background

            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.yellow.opacity(0.85))

                VStack(spacing: 8) {
                    Text(AudioManager.appName)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("寝たまま聴くだけのリラクセーション")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }

                sessionCard

                Spacer()

                playButton

                statusText
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - 部品

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.06, green: 0.07, blue: 0.20),
                Color(red: 0.10, green: 0.05, blue: 0.16),
                Color(red: 0.02, green: 0.02, blue: 0.08),
            ],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var sessionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "waveform")
                    .foregroundStyle(.cyan.opacity(0.8))
                Text(AudioManager.sessionTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(format(audio.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))
            }

            Text("体の各部位に力を入れて、ふっとゆるめる動作を繰り返し、深いリラックスへ導きます。そのまま眠ってしまってもかまいません。")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.55))
                .lineSpacing(4)

            ProgressView(value: progress)
                .tint(.cyan.opacity(0.8))

            HStack {
                Text(format(audio.currentTime))
                Spacer()
                Text("-" + format(max(audio.duration - audio.currentTime, 0)))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.white.opacity(0.4))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white.opacity(0.07))
        )
    }

    private var playButton: some View {
        Button {
            audio.togglePlayPause()
        } label: {
            Image(systemName: audio.state == .playing ? "pause.fill" : "play.fill")
                .font(.system(size: 32))
                .foregroundStyle(.black.opacity(0.8))
                .frame(width: 88, height: 88)
                .background(Circle().fill(.white.opacity(0.9)))
                .shadow(color: .cyan.opacity(0.35), radius: 24)
        }
        .buttonStyle(.plain)
    }

    private var statusText: some View {
        Group {
            switch audio.state {
            case .playing:
                Text("画面を消しても再生は続きます")
            case .finished:
                Text("おやすみなさい")
            case .paused:
                Text("一時停止中")
            case .idle:
                Text("再生ボタンで始めましょう")
            }
        }
        .font(.caption)
        .foregroundStyle(.white.opacity(0.45))
    }

    // MARK: - ヘルパー

    private var progress: Double {
        guard audio.duration > 0 else { return 0 }
        return min(audio.currentTime / audio.duration, 1)
    }

    private func format(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

#Preview {
    ContentView()
        .environmentObject(AudioManager())
}
