import Foundation

// MARK: - AlertUrgency

/// アラートの緊急度
public enum AlertUrgency: Equatable, Sendable {
    /// 期限切れ済み
    case expired
    /// 緊急（24時間以内）
    case urgent
    /// 警告（7日以内）
    case warning
    /// 情報（30日以内）
    case info
    /// 低優先度（30日以上）
    case low
}

// MARK: - PointExpirationAlert

/// ポイント期限切れアラートを表すドメインオブジェクト
/// ビジネスルール: ポイントの期限切れを事前に通知し、失効を防ぐ
public struct PointExpirationAlert: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let amount: PointAmount
    public let expiresAt: Date
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        amount: PointAmount,
        expiresAt: Date,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.amount = amount
        self.expiresAt = expiresAt
        self.createdAt = createdAt
    }

    // MARK: - 緊急度判定

    /// 現在の緊急度を取得
    public func urgency(at date: Date = Date()) -> AlertUrgency {
        let remaining = expiresAt.timeIntervalSince(date)

        if remaining <= 0 {
            return .expired
        } else if remaining <= 86400 { // 24時間
            return .urgent
        } else if remaining <= 86400 * 7 { // 7日
            return .warning
        } else if remaining <= 86400 * 30 { // 30日
            return .info
        } else {
            return .low
        }
    }

    // MARK: - 残り時間

    /// 残り時間（秒）を取得。期限切れの場合はnil
    public func remainingTime(at date: Date = Date()) -> TimeInterval? {
        let remaining = expiresAt.timeIntervalSince(date)
        return remaining > 0 ? remaining : nil
    }

    /// 残り日数/時間を表示用テキストで取得
    public func remainingDaysText(at date: Date = Date()) -> String {
        guard let remaining = remainingTime(at: date) else {
            return "期限切れ"
        }

        let hours = Int(remaining / 3600)
        let days = hours / 24

        if days >= 1 {
            return "\(days)日"
        } else {
            return "\(hours)時間"
        }
    }
}

// MARK: - ExpirationAlertService

/// ポイント期限切れアラートを生成するサービス
public struct ExpirationAlertService: Sendable {

    public init() {}

    /// PointBalanceから期限切れ間近のアラートを生成
    /// - Parameters:
    ///   - balance: ポイント残高
    ///   - interval: この期間内に切れるポイントを対象（秒）
    ///   - date: 基準日時
    /// - Returns: 期限の近い順にソートされたアラート配列
    public func generateAlerts(
        from balance: PointBalance,
        within interval: TimeInterval,
        at date: Date = Date()
    ) -> [PointExpirationAlert] {
        let deadline = date.addingTimeInterval(interval)

        return balance.entries(expiringSoonBefore: deadline, at: date)
            .map { entry in
                PointExpirationAlert(
                    amount: entry.amount,
                    expiresAt: entry.expiresAt,
                    createdAt: date
                )
            }
            .sorted { $0.expiresAt < $1.expiresAt }
    }

    /// 指定期間内に失効予定の合計ポイントを取得
    public func totalExpiringAmount(
        from balance: PointBalance,
        within interval: TimeInterval,
        at date: Date = Date()
    ) -> PointAmount {
        balance.pointsExpiringSoon(within: interval, at: date)
    }
}
