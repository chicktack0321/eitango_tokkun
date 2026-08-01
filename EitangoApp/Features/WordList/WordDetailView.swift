import SwiftUI
import SwiftData

struct WordDetailView: View {
    let word: WordMaster

    @Environment(\.modelContext) private var modelContext
    // 単語詳細を開くたびに生成すると、そのつどオーディオセッションを奪って
    // ユーザーが聴いていた音楽を止めてしまうため、共有インスタンスを使う
    @State private var audioManager = AudioPlaybackManager.shared
    @State private var progress: UserProgress?

    var body: some View {
        Form {
            Section {
                HStack {
                    Text(word.word).font(.title2).bold()
                    Button {
                        audioManager.play(items: [ListeningItem(id: word.wordId, word: word.word, meaning: word.meaning)])
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                    }
                }
                Text(word.meaning).foregroundStyle(.secondary)
            }

            Section("例文") {
                Text(word.example)
            }

            Section("データ") {
                LabeledContent("頻出度", value: word.category.displayName)
                LabeledContent("品詞", value: word.partOfSpeech.displayName)
                LabeledContent("出題回数", value: "\(word.frequencyCount)回")
                if let progress {
                    LabeledContent("正答率", value: percentString(progress.accuracy))
                }
            }

            // 習熟段階は解答の履歴から導出するため直接は書き換えない。
            // 代わりに復習間隔そのものを動かす操作を用意し、表示と根拠が食い違わないようにしている。
            Section {
                LabeledContent("習熟度", value: (progress?.status ?? .notStudied).displayName)
                if let progress, let nextReviewAt = progress.nextReviewAt, progress.attemptCount > 0 {
                    LabeledContent("次回の復習", value: nextReviewAt.formatted(.dateTime.month().day()))
                }

                Button("もう一度復習する") {
                    progress?.markForReview()
                    try? modelContext.save()
                }
                Button("覚えたことにする") {
                    progress?.markAsMemorized()
                    try? modelContext.save()
                }
            } header: {
                Text("習熟度")
            } footer: {
                Text((progress?.status ?? .notStudied).criteria)
            }
        }
        .navigationTitle(word.word)
        .task {
            progress = ProgressRepository(context: modelContext).progress(for: word.wordId)
        }
    }

    private func percentString(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
