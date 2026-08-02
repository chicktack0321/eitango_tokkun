import SwiftUI
import SwiftData

struct WordDetailView: View {
    let word: WordMaster

    @Environment(\.modelContext) private var modelContext
    // 単語詳細を開くたびに生成すると、そのつどオーディオセッションを奪って
    // ユーザーが聴いていた音楽を止めてしまうため、共有インスタンスを使う
    @State private var audioManager = AudioPlaybackManager.shared
    @State private var progress: UserProgress?
    /// 自分で追加した語のときだけ入る原本。編集・削除に使う。
    @State private var userWord: UserWord?
    @State private var isEditing = false
    @State private var isConfirmingDelete = false

    @Environment(\.dismiss) private var dismiss

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
                LabeledContent("階層", value: word.tier.displayName)
                LabeledContent("分野", value: word.domain.displayName)
                if word.source == .user {
                    LabeledContent("登録", value: "自分で追加した単語")
                } else if word.frequencyCount > 0 {
                    // 過去問での実出題回数は公開されていないため、値を持つ語だけに出す
                    LabeledContent("出題回数", value: "\(word.frequencyCount)回")
                }
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

            if let userWord {
                Section {
                    Button("編集する") { isEditing = true }
                    Button("単語帳から削除", role: .destructive) { isConfirmingDelete = true }
                } footer: {
                    Text("削除すると、この単語の学習履歴も一緒に消えます。")
                }
            }
        }
        .navigationTitle(word.word)
        .sheet(isPresented: $isEditing, onDismiss: reloadUserWord) {
            WordEditorView(editing: userWord)
        }
        .alert("この単語を削除しますか？", isPresented: $isConfirmingDelete) {
            Button("削除", role: .destructive, action: deleteUserWord)
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("「\(word.word)」と、その学習履歴が削除されます。この操作は取り消せません。")
        }
        .task {
            progress = ProgressRepository(context: modelContext).progress(for: word.wordId)
            reloadUserWord()
        }
    }

    private func reloadUserWord() {
        guard word.source == .user else { return }
        userWord = UserWordRepository(context: modelContext).userWord(for: word.wordId)
    }

    private func deleteUserWord() {
        guard let userWord else { return }
        UserWordRepository(context: modelContext).delete(userWord)
        // 一覧に残っている参照先が消えるため、詳細は閉じる
        dismiss()
    }

    private func percentString(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
