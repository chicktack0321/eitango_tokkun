import SwiftUI
import SwiftData
import AVFoundation

struct ListeningView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ListeningViewModel()
    // 画面ごとに生成するとオーディオセッションを奪い合うため、アプリ全体で1つを共有する。
    // 速度スライダーのBindingを得るために @State で保持している（実体は常に同じインスタンス）。
    @State private var audioManager = AudioPlaybackManager.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                categoryPicker

                nowPlayingCard

                controls

                speedControl

                Spacer()
            }
            .padding()
            .navigationTitle("聞き流し")
            .task { viewModel.configure(context: modelContext) }
            .onChange(of: viewModel.selectedCategory) { _, _ in
                audioManager.stop()
                viewModel.reload()
            }
        }
    }

    private var categoryPicker: some View {
        Picker("頻出度", selection: $viewModel.selectedCategory) {
            Text("すべて").tag(FrequencyRank?.none)
            ForEach(FrequencyRank.allCases) { rank in
                Text(rank.displayName).tag(FrequencyRank?.some(rank))
            }
        }
        .pickerStyle(.segmented)
    }

    private var nowPlayingCard: some View {
        VStack(spacing: 8) {
            if let item = audioManager.currentItem {
                Text(item.word)
                    .font(.system(size: 34, weight: .bold))
                Text(item.meaning)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("\(currentPosition) / \(viewModel.words.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            } else {
                Text("再生を開始すると単語が表示されます")
                    .foregroundStyle(.secondary)
                Text("全\(viewModel.words.count)語")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 140)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private var currentPosition: Int {
        min(audioManager.currentIndex + 1, viewModel.words.count)
    }

    private var controls: some View {
        HStack(spacing: 24) {
            Button {
                audioManager.stop()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.title3)
            }
            .disabled(audioManager.state == .stopped)
            .accessibilityLabel("停止")

            Button {
                audioManager.skipToPrevious()
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.title2)
            }
            .disabled(audioManager.state == .stopped || audioManager.currentIndex == 0)
            .accessibilityLabel("前の単語")

            Button {
                togglePlayPause()
            } label: {
                Image(systemName: playPauseSymbolName)
                    .font(.system(size: 44))
            }
            .disabled(viewModel.words.isEmpty)
            .accessibilityLabel(audioManager.state == .playing ? "一時停止" : "再生")

            Button {
                audioManager.skipToNext()
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.title2)
            }
            .disabled(audioManager.state == .stopped)
            .accessibilityLabel("次の単語")
        }
    }

    private var playPauseSymbolName: String {
        switch audioManager.state {
        case .stopped: return "play.circle.fill"
        case .playing: return "pause.circle.fill"
        case .paused: return "play.circle.fill"
        }
    }

    private func togglePlayPause() {
        switch audioManager.state {
        case .stopped:
            audioManager.play(items: viewModel.listeningItems)
        case .playing:
            audioManager.pause()
        case .paused:
            audioManager.resume()
        }
    }

    private var speedControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("再生速度")
                .font(.caption)
                .foregroundStyle(.secondary)
            Slider(
                value: $audioManager.speechRate,
                in: AVSpeechUtteranceMinimumSpeechRate...AVSpeechUtteranceMaximumSpeechRate
            )
        }
    }
}

#Preview {
    ListeningView()
        .modelContainer(for: [WordMaster.self, UserProgress.self, StudyLog.self], inMemory: true)
}
