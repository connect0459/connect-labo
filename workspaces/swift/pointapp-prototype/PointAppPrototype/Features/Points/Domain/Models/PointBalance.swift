import Foundation

/// ポイント残高を表すドメインオブジェクト
struct PointBalance: Sendable, Equatable {
    let total: PointAmount
    let pendingPoints: PointAmount
    let expiringPoints: ExpiringPoints?

    init(
        total: PointAmount,
        pendingPoints: PointAmount = .zero,
        expiringPoints: ExpiringPoints? = nil
    ) {
        self.total = total
        self.pendingPoints = pendingPoints
        self.expiringPoints = expiringPoints
    }

    /// 利用可能なポイント（確定済み）
    var availablePoints: PointAmount {
        total.subtracting(pendingPoints) ?? .zero
    }

    /// 円換算した利用可能ポイント
    var availableYen: Decimal {
        availablePoints.toYen()
    }

    /// ポイントを加算した新しい残高を返す
    func adding(_ amount: PointAmount) -> PointBalance {
        PointBalance(
            total: total.adding(amount),
            pendingPoints: pendingPoints,
            expiringPoints: expiringPoints
        )
    }

    /// ポイントを減算した新しい残高を返す
    /// - Returns: 減算後の残高、または残高不足の場合はnil
    func subtracting(_ amount: PointAmount) -> PointBalance? {
        guard let newTotal = total.subtracting(amount) else {
            return nil
        }
        return PointBalance(
            total: newTotal,
            pendingPoints: pendingPoints,
            expiringPoints: expiringPoints
        )
    }

    /// 初期残高（ゼロ）
    static let zero = PointBalance(total: .zero)

    /// サンプルデータ
    static let sample = PointBalance(
        total: try! PointAmount(1234),
        pendingPoints: try! PointAmount(50),
        expiringPoints: ExpiringPoints(
            amount: try! PointAmount(200),
            expiresAt: Date().addingTimeInterval(86400 * 30)
        )
    )
}

/// 期限切れ予定のポイント
struct ExpiringPoints: Sendable, Equatable {
    let amount: PointAmount
    let expiresAt: Date

    /// 期限切れまでの日数
    func daysUntilExpiration(from date: Date = .now) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: date, to: expiresAt)
        return max(0, components.day ?? 0)
    }

    /// 期限が近いかどうか（7日以内）
    func isExpiringSoon(from date: Date = .now) -> Bool {
        daysUntilExpiration(from: date) <= 7
    }
}
