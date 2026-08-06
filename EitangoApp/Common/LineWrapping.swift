import CoreGraphics

/// 幅の並びを、指定した幅に収まる行へ分ける。
///
/// タイピングは1文字ずつ色と下線を変えるため `Text` をひとつにまとめられず、
/// 標準の折り返しが使えない。`HStack` に任せると幅の足りないぶん文字が潰れて重なる。
/// 折り返しの判断はレイアウト側の型（`Layout.Subviews`）に触れずに済むので、
/// 目視で確かめにくい境界をテストできるようここへ切り出している。
enum LineWrapping {

    /// - Returns: 各行に載せる要素の添字。要素が無ければ空。
    static func rows(widths: [CGFloat], maxWidth: CGFloat, spacing: CGFloat) -> [[Int]] {
        var rows: [[Int]] = []
        var current: [Int] = []
        var currentWidth: CGFloat = 0

        for (index, width) in widths.enumerated() {
            let advance = current.isEmpty ? width : width + spacing
            // 行頭の1つは幅を超えても必ず載せる。でないと1つで超える要素があったときに
            // 空の行を作り続けて終わらない。
            if !current.isEmpty, currentWidth + advance > maxWidth {
                rows.append(current)
                current = [index]
                currentWidth = width
            } else {
                current.append(index)
                currentWidth += advance
            }
        }

        if !current.isEmpty { rows.append(current) }
        return rows
    }
}
