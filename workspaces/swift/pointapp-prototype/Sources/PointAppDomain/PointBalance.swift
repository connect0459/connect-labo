import Foundation

// MARK: - PointBalance

/// ポイント残高を管理するドメインオブジェクト
/// ビジネスルール: ポイントには有効期限があり、期限切れ前にアラートを表示
public struct PointBalance: Equatable, Sendable {
    /// ポイントエントリ（個々のポイント獲得記録）
    private var entries: [PointEntry] = []

    public init() {}

    // MARK: - 残高

    /// 総ポイント（期限切れ含む）
    public var total: PointAmount {
        let sum = entries.reduce(0) { $0 + $1.remainingAmount.value }
        return try! PointAmount(sum)
    }

    /// 有効なポイント残高（期限切れを除く）
    public func availableTotal(at date: Date = .now) -> PointAmount {
        let sum = entries
            .filter { $0.expiresAt > date }
            .reduce(0) { $0 + $1.remainingAmount.value }
        return try! PointAmount(sum)
    }

    // MARK: - 加算

    /// ポイントを加算
    public mutating func add(_ amount: PointAmount, expiresAt: Date) {
        let entry = PointEntry(
            originalAmount: amount,
            remainingAmount: amount,
            expiresAt: expiresAt,
            createdAt: .now
        )
        entries.append(entry)
    }

    // MARK: - 使用

    /// ポイントを使用（FIFO: 古いポイントから消費）
    public mutating func use(_ amount: PointAmount, at date: Date = .now) -> Result<Void, PointBalanceError> {
        let available = availableTotal(at: date)
        guard available >= amount else {
            return .failure(.insufficientBalance)
        }

        var remaining = amount.value

        // 有効なエントリを期限が近い順にソート
        let sortedIndices = entries.indices
            .filter { entries[$0].expiresAt > date && entries[$0].remainingAmount.value > 0 }
            .sorted { entries[$0].expiresAt < entries[$1].expiresAt }

        for index in sortedIndices {
            guard remaining > 0 else { break }

            let available = entries[index].remainingAmount.value
            let toUse = min(available, remaining)

            entries[index].remainingAmount = try! PointAmount(available - toUse)
            remaining -= toUse
        }

        return .success(())
    }

    // MARK: - 有効期限

    /// 指定期間内に期限切れになるポイント
    public func pointsExpiringSoon(within interval: TimeInterval, at date: Date = .now) -> PointAmount {
        let threshold = date.addingTimeInterval(interval)
        let sum = entries
            .filter { $0.expiresAt > date && $0.expiresAt <= threshold }
            .reduce(0) { $0 + $1.remainingAmount.value }
        return try! PointAmount(sum)
    }

    /// 期限切れポイントを削除
    public mutating func removeExpired(at date: Date = .now) {
        entries.removeAll { $0.expiresAt <= date }
    }

    /// 指定日時より前に期限切れになるエントリを取得（期限切れ除く）
    public func entries(expiringSoonBefore deadline: Date, at date: Date = .now) -> [ExpiringPointEntry] {
        entries
            .filter { $0.expiresAt > date && $0.expiresAt <= deadline && $0.remainingAmount.value > 0 }
            .map { ExpiringPointEntry(amount: $0.remainingAmount, expiresAt: $0.expiresAt) }
    }
}

// MARK: - PointEntry

/// 個々のポイント獲得記録（内部用）
struct PointEntry: Equatable, Sendable {
    let originalAmount: PointAmount
    var remainingAmount: PointAmount
    let expiresAt: Date
    let createdAt: Date
}

// MARK: - ExpiringPointEntry

/// 期限切れ間近のポイントエントリ（公開用）
public struct ExpiringPointEntry: Equatable, Sendable {
    public let amount: PointAmount
    public let expiresAt: Date

    public init(amount: PointAmount, expiresAt: Date) {
        self.amount = amount
        self.expiresAt = expiresAt
    }
}

// MARK: - PointBalanceError

public enum PointBalanceError: Error, Equatable {
    case insufficientBalance
}

// MARK: - Result Extension

extension Result where Success == Void {
    var isSuccess: Bool {
        switch self {
        case .success: return true
        case .failure: return false
        }
    }
}
