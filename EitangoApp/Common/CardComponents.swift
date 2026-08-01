import SwiftUI

/// アプリ全体で使う「白いカード」の共通コンテナ。Home/Typing等、複数画面で見た目を揃えるために共有する。
struct DashboardCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }
}

/// 数値+ラベルを淡い色付き背景で見せる共通タイル（今日の学習、スコアなど）。
struct StatTile: View {
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title2).bold()
                .foregroundStyle(tint)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}
