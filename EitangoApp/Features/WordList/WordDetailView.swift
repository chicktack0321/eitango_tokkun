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

            Section("学習ステータス") {
                Picker("ステータス", selection: statusBinding) {
                    ForEach(LearningStatus.allCases) { status in
                        Text(status.displayName).tag(status)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .navigationTitle(word.word)
        .task {
            progress = ProgressRepository(context: modelContext).progress(for: word.wordId)
        }
    }

    private var statusBinding: Binding<LearningStatus> {
        Binding(
            get: { progress?.status ?? .notStudied },
            set: { newValue in
                progress?.status = newValue
                try? modelContext.save()
            }
        )
    }

    private func percentString(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
