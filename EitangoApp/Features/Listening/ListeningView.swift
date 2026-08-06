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
            ScrollView {
                VStack(spacing: 16) {
                    filterCard
                    nowPlayingCard
                    controls
                    speedCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("聞き流し")
            .navigationBarTitleDisplayMode(.inline)
            .task { viewModel.configure(context: modelContext) }
            // 対象が変わったら再生を止める。今聞こえている語が一覧から消えた状態で
            // 再生が続くと、どこを流しているのか分からなくなるため。
            .onChange(of: viewModel.filter) { _, _ in
                audioManager.stop()
            }
        }
    }

    /// 単語帳と同じ軸で絞り込む。「要復習だけ流す」が聞き流しの主な使い道になる。
    private var filterCard: some View {
        DashboardCard(title: "再生する単語（\(viewModel.words.count)語）") {
            VStack(spacing: 12) {
                Picker("学習ステータス", selection: $viewModel.filter.status) {
                    Text("すべて").tag(LearningStatus?.none)
                    ForEach(LearningStatus.allCases) { status in
                        Text(status.displayName).tag(LearningStatus?.some(status))
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    filterMenu(
                        title: "階層",
                        selectedLabel: viewModel.filter.tier?.displayName ?? "出題範囲"
                    ) {
                        Button("出題範囲（既定）") { viewModel.filter.tier = nil }
                        ForEach(VocabularyTier.allCases) { tier in
                            Button(tier.displayName) { viewModel.filter.tier = tier }
                        }
                    }
                    Spacer(minLength: 12)
                    filterMenu(
                        title: "分野",
                        selectedLabel: viewModel.filter.domain?.displayName ?? "すべて"
                    ) {
                        Button("すべて") { viewModel.filter.domain = nil }
                        ForEach(VocabularyDomain.allCases) { domain in
                            Button(domain.displayName) { viewModel.filter.domain = domain }
                        }
                    }
                }

                HStack {
                    filterMenu(
                        title: "頻出度",
                        selectedLabel: viewModel.filter.category?.displayName ?? "すべて"
                    ) {
                        Button("すべて") { viewModel.filter.category = nil }
                        ForEach(FrequencyRank.allCases) { rank in
                            Button(rank.displayName) { viewModel.filter.category = rank }
                        }
                    }
                    Spacer(minLength: 12)
                    filterMenu(
                        title: "品詞",
                        selectedLabel: viewModel.filter.partOfSpeech?.displayName ?? "すべて"
                    ) {
                        Button("すべて") { viewModel.filter.partOfSpeech = nil }
                        ForEach(PartOfSpeech.allCases) { pos in
                            Button(pos.displayName) { viewModel.filter.partOfSpeech = pos }
                        }
                    }
                }
            }
        }
    }

    private func filterMenu<Content: View>(
        title: String,
        selectedLabel: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 4) {
                Text(title).foregroundStyle(.primary)
                Text(selectedLabel).foregroundStyle(.secondary)
                Image(systemName: "chevron.up.chevron.down").font(.caption2)
            }
            .font(.subheadline)
            .lineLimit(1)
            .fixedSize()
        }
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
            audioManager.play(items: viewModel.makePlaybackItems())
        case .playing:
            audioManager.pause()
        case .paused:
            audioManager.resume()
        }
    }

    /// 連続スライダーだと「今どのくらいの速さなのか」「標準はどこか」が分からないため、
    /// 段階を決め打ちにして倍率をそのまま見せる。
    ///
    /// 2.0倍は外している。合成音声が潰れて単語の聞き分けができず、聞き流しの用をなさないため。
    private static let speedOptions: [Double] = [0.8, 1.0, 1.2, 1.5]

    private var speedCard: some View {
        DashboardCard(title: "再生速度") {
            Picker("再生速度", selection: $audioManager.speedMultiplier) {
                ForEach(Self.speedOptions, id: \.self) { speed in
                    Text(speed == 1.0 ? "標準" : String(format: "%.1f倍", speed))
                        .tag(speed)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

#Preview {
    ListeningView()
        .modelContainer(for: [WordMaster.self, UserProgress.self, StudyLog.self, TypingScore.self], inMemory: true)
}
