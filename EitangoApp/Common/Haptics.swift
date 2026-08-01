import UIKit

/// 触覚フィードバック。クイズとタイピングで同じ手応えにするため1か所にまとめる。
@MainActor
enum Haptics {
    /// 正解・単語完成。短く1回。
    static func success() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// 不正解。3回続けて震わせ、正解とはっきり区別できるようにする。
    /// 画面を見ずに解いていても間違いに気付けるのが狙い。
    static func failure() {
        Task { @MainActor in
            let generator = UIImpactFeedbackGenerator(style: .rigid)
            generator.prepare()
            for index in 0..<3 {
                generator.impactOccurred()
                if index < 2 {
                    try? await Task.sleep(nanoseconds: 110_000_000)
                }
            }
        }
    }

    /// 自己ベスト更新など、通常の正解より大きな達成
    static func celebrate() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
