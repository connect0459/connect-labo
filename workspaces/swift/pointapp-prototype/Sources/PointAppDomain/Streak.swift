import Foundation

// MARK: - Streak

/// 連続ログインを表すドメインオブジェクト
/// ビジネスルール: 連続ログインでボーナスポイントが増加、途切れるとリセット
public struct Streak: Equatable, Sendable {
    /// 現在の連続日数
    public private(set) var currentDays: Int

    /// 最高連続記録
    public private(set) var maxDays: Int

    /// 最終ログイン日
    public private(set) var lastLoginDate: Date?

    /// ボーナスの上限日数
    private static let maxBonusDays = 30

    public init() {
        self.currentDays = 0
        self.maxDays = 0
        self.lastLoginDate = nil
    }

    // MARK: - ログイン記録

    /// ログインを記録する
    /// - Parameter date: ログイン日時
    public mutating func recordLogin(at date: Date) {
        guard let lastLogin = lastLoginDate else {
            // 初回ログイン
            currentDays = 1
            maxDays = max(maxDays, currentDays)
            lastLoginDate = date
            return
        }

        let calendar = Calendar.current

        // 同じ日の場合は何もしない
        if calendar.isDate(date, inSameDayAs: lastLogin) {
            return
        }

        // 前日かどうかチェック
        let lastLoginDay = calendar.startOfDay(for: lastLogin)
        let loginDay = calendar.startOfDay(for: date)
        let daysDifference = calendar.dateComponents([.day], from: lastLoginDay, to: loginDay).day ?? 0

        if daysDifference == 1 {
            // 連続ログイン
            currentDays += 1
        } else {
            // 連続が途切れた
            currentDays = 1
        }

        maxDays = max(maxDays, currentDays)
        lastLoginDate = date
    }

    // MARK: - ボーナス計算

    /// 現在の連続日数に応じたボーナスポイントを取得
    /// - Returns: ボーナスポイント（1日1pt、上限30pt）
    public func bonusPoints() -> PointAmount {
        let bonus = min(currentDays, Self.maxBonusDays)
        // PointAmountは0以上なので安全
        return try! PointAmount(bonus)
    }
}
