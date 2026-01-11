import Foundation

/// ポイント金額を表す値オブジェクト
/// 不変性とバリデーションを保証する
struct PointAmount: Equatable, Comparable, Sendable, Codable {
    let value: Int

    /// ポイント金額を生成する
    /// - Parameter value: ポイント値（0以上）
    /// - Throws: 負の値の場合はエラー
    init(_ value: Int) throws {
        guard value >= 0 else {
            throw PointAmountError.negativeValue
        }
        self.value = value
    }

    /// 円換算（10ポイント = 1円）
    func toYen() -> Decimal {
        Decimal(value) / 10
    }

    /// 円換算の文字列表現
    func toYenString() -> String {
        let yen = Double(truncating: toYen() as NSNumber)
        return String(format: "%.1f円", yen)
    }

    /// ポイントを加算
    func adding(_ other: PointAmount) -> PointAmount {
        // 加算結果は常に正なのでtry!で安全
        try! PointAmount(value + other.value)
    }

    /// ポイントを減算
    /// - Returns: 減算結果、または残高不足の場合はnil
    func subtracting(_ other: PointAmount) -> PointAmount? {
        let result = value - other.value
        return try? PointAmount(result)
    }

    static func < (lhs: PointAmount, rhs: PointAmount) -> Bool {
        lhs.value < rhs.value
    }

    /// ゼロポイント
    static let zero = try! PointAmount(0)
}

/// PointAmount関連のエラー
enum PointAmountError: Error, Equatable {
    case negativeValue
}
