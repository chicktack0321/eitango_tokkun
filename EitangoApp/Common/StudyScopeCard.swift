import SwiftUI

/// 出題・集計の範囲を選ぶカード。クイズ・タイピング・習熟度で同じ見た目と操作にする。
///
/// 3,955語をまとめて扱うと習熟度がほとんど動かず、出題も分野が散らばって
/// 「いま何を潰しているのか」が分からなくなる。範囲を狭められること自体が機能なので、
/// 各画面に散らさず1つの部品にまとめている。
struct StudyScopeCard: View {
    let title: String
    @Binding var scope: StudyScope
    /// この条件に何語入るか。0語のまま始めさせないための表示
    var matchingCount: Int?
    /// 「自分で追加した単語のみ」を出すか（習熟度の集計では出さない場面もある）
    var showsUserWordsOption: Bool = true
    /// 自分で追加した単語が1語も無いときは選ばせない
    var hasUserWords: Bool = true
    /// 出題時の読み上げを切り替えられるようにするか
    var showsPronunciationOption: Bool = false
    /// 読み上げに条件があるときの補足（タイピングのブラインドなど）
    var pronunciationNote: String?

    @State private var pronouncesWords = StudySettings.pronouncesWords

    var body: some View {
        DashboardCard(title: title) {
            VStack(alignment: .leading, spacing: 12) {
                if scope.onlyUserWords {
                    Text("自分で追加した単語だけを出題します。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HStack {
                        menu(title: "階層", selected: scope.tier?.displayName ?? "おまかせ") {
                            Button("おまかせ（基礎を除く）") { scope.tier = nil }
                            ForEach(VocabularyTier.allCases) { tier in
                                Button(tier.displayName) { scope.tier = tier }
                            }
                        }
                        Spacer(minLength: 12)
                        menu(title: "頻出度", selected: scope.category?.displayName ?? "すべて") {
                            Button("すべて") { scope.category = nil }
                            ForEach(FrequencyRank.allCases) { rank in
                                Button(rank.displayName) { scope.category = rank }
                            }
                        }
                    }

                    HStack {
                        menu(title: "分野", selected: scope.domain?.displayName ?? "すべて") {
                            Button("すべて") { scope.domain = nil }
                            ForEach(VocabularyDomain.allCases) { domain in
                                Button(domain.displayName) { scope.domain = domain }
                            }
                        }
                        Spacer()
                    }
                }

                if showsUserWordsOption {
                    Toggle("自分で追加した単語のみ", isOn: $scope.onlyUserWords)
                        .font(.subheadline)
                        .disabled(!hasUserWords)
                    if !hasUserWords {
                        Text("単語帳の「＋」から追加すると、ここで集中して練習できます。")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if showsPronunciationOption {
                    Divider()
                    Toggle("出題時に発音を読み上げる", isOn: $pronouncesWords)
                        .font(.subheadline)
                        .onChange(of: pronouncesWords) { _, newValue in
                            StudySettings.pronouncesWords = newValue
                            if !newValue { WordPronouncer.shared.stop() }
                        }
                    if let pronunciationNote {
                        Text(pronunciationNote)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if let matchingCount {
                    Divider()
                    HStack {
                        Text("この条件の単語")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(matchingCount)語")
                            .font(.subheadline).bold()
                            .foregroundStyle(matchingCount == 0 ? .orange : .primary)
                            .contentTransition(.numericText())
                    }
                    if matchingCount == 0 {
                        Text("条件に合う単語がありません。絞り込みを緩めてください。")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                if !scope.isDefault {
                    Button("条件をリセット") { scope = .default }
                        .font(.caption)
                }
            }
        }
    }

    // Picker(.menu) はラベルと選択値を1行に詰めようとして幅の狭い端末で崩れるため、
    // 単語帳と同じく Menu を直接使って1行に固定する
    private func menu<Content: View>(
        title: String,
        selected: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 4) {
                Text(title).foregroundStyle(.primary)
                Text(selected).foregroundStyle(.secondary)
                Image(systemName: "chevron.up.chevron.down").font(.caption2)
            }
            .font(.subheadline)
            .lineLimit(1)
            .fixedSize()
        }
    }
}
