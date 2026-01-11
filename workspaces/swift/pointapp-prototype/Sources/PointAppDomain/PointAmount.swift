import Foundation

/// ポイント金額のエラー
public enum PointAmountError: Error, Equatable {
    case negativeValue
}

/// ポイント金額を表す値オブジェクト
/// ビジネスルール: ポイントは0以上の整数、10pt = 1円
public struct PointAmount: Equatable, Comparable, Sendable, Hashable {

    /// ポイント値
    public let value: Int

    /// イニシャライザ
    /// - Parameter value: ポイント値（0以上）
    /// - Throws: `PointAmountError.negativeValue` 負の値の場合
    public init(_ value: Int) throws {
        guard value >= 0 else {
            throw PointAmountError.negativeValue
        }
        self.value = value
    }

    // MARK: - ファクトリ

    /// ゼロポイント
    public static let zero = try! PointAmount(0)

    // MARK: - 計算

    /// 円換算（10pt = 1円）
    public func toYen() -> Decimal {
        Decimal(value) / 10
    }

    /// 円表示の文字列
    public func toYenString() -> String {
        let yen = toYen()
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        let yenString = formatter.string(from: yen as NSNumber) ?? "\(yen)"
        return "\(yenString)円"
    }

    /// ポイントを加算
    public func adding(_ other: PointAmount) -> PointAmount {
        try! PointAmount(value + other.value)
    }

    /// ポイントを減算（結果が負になる場合はゼロ）
    public func subtracting(_ other: PointAmount) -> PointAmount {
        let result = value - other.value
        return result >= 0 ? try! PointAmount(result) : .zero
    }

    // MARK: - Comparable

    public static func < (lhs: PointAmount, rhs: PointAmount) -> Bool {
        lhs.value < rhs.value
    }
}

// MARK: - CustomStringConvertible

extension PointAmount: CustomStringConvertible {
    public var description: String {
        "\(value)pt"
    }
}
