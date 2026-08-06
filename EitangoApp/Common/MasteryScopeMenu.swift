import SwiftUI

/// 覚えた語数を数える範囲（階層・分野・頻出度）を選ぶ1行のメニュー。
///
/// ホームの習熟度と学習の記録のグラフで同じ範囲を扱うため、共通の部品にしている。
/// 出題範囲の `StudyScopeCard` ほど場所を取れない画面向けに、カードではなく横並びのチップにしている。
struct MasteryScopeMenu: View {
    @Binding var scope: StudyScope
    /// 「自分で追加した単語のみ」を選べるようにするか
    var hasUserWords: Bool

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                Button("すべての階層") { scope.tier = nil }
                ForEach(VocabularyTier.allCases) { tier in
                    Button(tier.displayName) { scope.tier = tier }
                }
            } label: {
                label("階層", scope.tier?.displayName ?? "すべて")
            }

            Menu {
                Button("すべての分野") { scope.domain = nil }
                ForEach(VocabularyDomain.allCases) { domain in
                    Button(domain.displayName) { scope.domain = domain }
                }
            } label: {
                label("分野", scope.domain?.displayName ?? "すべて")
            }

            Menu {
                Button("すべての頻出度") { scope.category = nil }
                ForEach(FrequencyRank.allCases) { rank in
                    Button(rank.displayName) { scope.category = rank }
                }
                if hasUserWords {
                    Divider()
                    Button("自分で追加した単語のみ") { scope.onlyUserWords = true }
                }
                if !scope.isDefault {
                    Divider()
                    Button("リセット") { scope = .default }
                }
            } label: {
                label("頻出度", scope.category?.displayName ?? "すべて")
            }

            Spacer(minLength: 0)
        }
    }

    private func label(_ title: String, _ value: String) -> some View {
        HStack(spacing: 3) {
            Text(title).foregroundStyle(.secondary)
            Text(value).foregroundStyle(.primary)
            Image(systemName: "chevron.down").font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .lineLimit(1)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(.secondarySystemBackground), in: Capsule())
    }
}
