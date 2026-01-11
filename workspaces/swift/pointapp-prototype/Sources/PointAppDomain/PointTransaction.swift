import Foundation

// MARK: - PointTransaction

/// ポイント取引を表すドメインオブジェクト
public struct PointTransaction: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let amount: PointAmount
    public let type: TransactionType
    public let reason: TransactionReason
    public let expiresAt: Date?
    public let createdAt: Date

    private init(
        id: UUID = UUID(),
        amount: PointAmount,
        type: TransactionType,
        reason: TransactionReason,
        expiresAt: Date?,
        createdAt: Date = .now
    ) {
        self.id = id
        self.amount = amount
        self.type = type
        self.reason = reason
        self.expiresAt = expiresAt
        self.createdAt = createdAt
    }

    // MARK: - Factory Methods

    /// ポイント獲得トランザクションを作成
    public static func earn(
        amount: PointAmount,
        reason: TransactionReason,
        expiresAt: Date
    ) -> PointTransaction {
        PointTransaction(
            amount: amount,
            type: .earn,
            reason: reason,
            expiresAt: expiresAt
        )
    }

    /// ポイント使用トランザクションを作成
    public static func spend(
        amount: PointAmount,
        reason: TransactionReason
    ) -> PointTransaction {
        PointTransaction(
            amount: amount,
            type: .spend,
            reason: reason,
            expiresAt: nil
        )
    }
}

// MARK: - TransactionType

public enum TransactionType: String, Equatable, Sendable {
    case earn   // 獲得
    case spend  // 使用
}

// MARK: - TransactionReason

public enum TransactionReason: Equatable, Sendable {
    // 獲得理由
    case surveyCompleted(surveyId: String)
    case dailyLogin
    case streakBonus(days: Int)
    case missionCompleted(missionId: String)
    case referralBonus
    case campaignBonus(name: String)

    // 使用理由
    case exchanged(to: String)
    case expired
}
