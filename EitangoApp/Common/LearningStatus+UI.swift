import SwiftUI

// 色は SwiftUI に依存するため、モデル側の enum ではなくUI層で持たせる。
extension LearningStatus {
    var tint: Color {
        switch self {
        case .notStudied: return .secondary
        case .needsReview: return .orange
        case .learning: return .blue
        case .memorized: return .green
        }
    }

    /// 習熟度バーで使う色。未学習だけは背景に馴染む灰色にする。
    var barColor: Color {
        self == .notStudied ? Color(.systemGray4) : tint
    }
}

/// 数値の意味をその場で説明するための「i」ボタン。
/// 正答率や習熟度は定義が分からないと解釈できず、誤解したまま一喜一憂させてしまうため、
/// 説明を画面の外（ヘルプやREADME）に置かず、指標のすぐ隣から開けるようにしている。
struct InfoButton: View {
    let title: String
    let message: String

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "info.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)の説明")
        .popover(isPresented: $isPresented) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .frame(maxWidth: 320)
            .presentationCompactAdaptation(.popover)
        }
    }
}
