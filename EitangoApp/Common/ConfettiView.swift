import SwiftUI

/// 正解や自己ベスト更新を祝う紙吹雪。
///
/// 画像素材は持たず、小さな矩形と円を散らして描くだけにしている
/// （音声と同じく、アプリ容量を増やさない方針のため）。
/// `trigger` の値が変わるたびに一度だけ降る。
struct ConfettiView: View {
    /// これが変わると新しく紙吹雪が発生する
    var trigger: Int
    var pieceCount: Int = 28

    @State private var pieces: [Piece] = []
    @State private var isAnimating = false

    struct Piece: Identifiable {
        let id = UUID()
        let xRatio: CGFloat
        let size: CGFloat
        let color: Color
        let isCircle: Bool
        let rotation: Double
        let delay: Double
        let drift: CGFloat
    }

    private static let palette: [Color] = [.pink, .orange, .yellow, .green, .blue, .purple]

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                ForEach(pieces) { piece in
                    shape(for: piece)
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.isCircle ? piece.size : piece.size * 0.5)
                        .rotationEffect(.degrees(isAnimating ? piece.rotation : 0))
                        .offset(
                            x: proxy.size.width * piece.xRatio + (isAnimating ? piece.drift : 0),
                            y: isAnimating ? proxy.size.height : -30
                        )
                        .opacity(isAnimating ? 0 : 1)
                        .animation(
                            .easeIn(duration: 1.1).delay(piece.delay),
                            value: isAnimating
                        )
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in burst() }
    }

    private func shape(for piece: Piece) -> some Shape {
        piece.isCircle
            ? AnyShape(Circle())
            : AnyShape(RoundedRectangle(cornerRadius: 1))
    }

    private func burst() {
        pieces = (0..<pieceCount).map { _ in
            Piece(
                xRatio: .random(in: 0.05...0.95),
                size: .random(in: 6...11),
                color: Self.palette.randomElement() ?? .pink,
                isCircle: Bool.random(),
                rotation: .random(in: 180...540),
                delay: .random(in: 0...0.18),
                drift: .random(in: -40...40)
            )
        }
        // 位置を初期状態に戻してから落下させる
        isAnimating = false
        DispatchQueue.main.async {
            isAnimating = true
        }
    }
}

/// 正解時など、一瞬だけ紙吹雪を重ねたい画面に付ける
extension View {
    func confetti(trigger: Int) -> some View {
        overlay(ConfettiView(trigger: trigger))
    }
}
