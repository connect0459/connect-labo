import Testing
import Foundation
@testable import PointAppDomain

/// Streak（連続ログイン）のテスト
/// ビジネスルール: 連続ログインでボーナスポイントが増加、途切れるとリセット
@Suite("Streak Tests")
struct StreakTests {

    // MARK: - 初期状態

    @Test("初期状態では連続日数は0")
    func initialDaysIsZero() {
        // Arrange
        let streak = Streak()

        // Assert
        #expect(streak.currentDays == 0)
    }

    @Test("初期状態では最終ログイン日はnil")
    func initialLastLoginDateIsNil() {
        // Arrange
        let streak = Streak()

        // Assert
        #expect(streak.lastLoginDate == nil)
    }

    // MARK: - ログイン記録

    @Test("初回ログインで連続日数が1になる")
    func firstLoginSetsDaysToOne() {
        // Arrange
        var streak = Streak()
        let today = Date()

        // Act
        streak.recordLogin(at: today)

        // Assert
        #expect(streak.currentDays == 1)
    }

    @Test("同じ日に複数回ログインしても連続日数は増えない")
    func multipleSameDayLoginsDoNotIncrement() {
        // Arrange
        var streak = Streak()
        let today = Date()

        // Act
        streak.recordLogin(at: today)
        streak.recordLogin(at: today.addingTimeInterval(3600)) // 1時間後

        // Assert
        #expect(streak.currentDays == 1)
    }

    @Test("連続した日にログインすると連続日数が増える")
    func consecutiveDaysIncrement() {
        // Arrange
        var streak = Streak()
        let day1 = createDate(year: 2026, month: 1, day: 10)
        let day2 = createDate(year: 2026, month: 1, day: 11)
        let day3 = createDate(year: 2026, month: 1, day: 12)

        // Act
        streak.recordLogin(at: day1)
        streak.recordLogin(at: day2)
        streak.recordLogin(at: day3)

        // Assert
        #expect(streak.currentDays == 3)
    }

    @Test("1日スキップすると連続日数がリセットされる")
    func skipDayResetsStreak() {
        // Arrange
        var streak = Streak()
        let day1 = createDate(year: 2026, month: 1, day: 10)
        let day2 = createDate(year: 2026, month: 1, day: 11)
        let day4 = createDate(year: 2026, month: 1, day: 13) // 1日スキップ

        // Act
        streak.recordLogin(at: day1)
        streak.recordLogin(at: day2)
        streak.recordLogin(at: day4)

        // Assert
        #expect(streak.currentDays == 1)
    }

    // MARK: - ボーナスポイント計算

    @Test("1日目のボーナスは1ポイント")
    func firstDayBonusIsOne() {
        // Arrange
        var streak = Streak()
        streak.recordLogin(at: Date())

        // Act
        let bonus = streak.bonusPoints()

        // Assert
        #expect(bonus.value == 1)
    }

    @Test("7日連続でボーナスが7ポイント")
    func sevenDayBonusIsSeven() {
        // Arrange
        var streak = Streak()
        for i in 0..<7 {
            let day = createDate(year: 2026, month: 1, day: 10 + i)
            streak.recordLogin(at: day)
        }

        // Act
        let bonus = streak.bonusPoints()

        // Assert
        #expect(bonus.value == 7)
    }

    @Test("30日連続でボーナスは上限の30ポイント")
    func thirtyDayBonusIsMax() {
        // Arrange
        var streak = Streak()
        for i in 0..<30 {
            let day = createDate(year: 2026, month: 1, day: 1 + i)
            streak.recordLogin(at: day)
        }

        // Act
        let bonus = streak.bonusPoints()

        // Assert
        #expect(bonus.value == 30)
    }

    @Test("31日以上連続でもボーナスは30ポイントが上限")
    func bonusCapsAtThirty() {
        // Arrange
        var streak = Streak()
        for i in 0..<35 {
            let day = createDate(year: 2026, month: 1, day: 1 + i)
            streak.recordLogin(at: day)
        }

        // Act
        let bonus = streak.bonusPoints()

        // Assert
        #expect(bonus.value == 30)
    }

    @Test("連続日数0の場合はボーナス0")
    func zeroDaysZeroBonus() {
        // Arrange
        let streak = Streak()

        // Act
        let bonus = streak.bonusPoints()

        // Assert
        #expect(bonus.value == 0)
    }

    // MARK: - 連続記録

    @Test("最高連続記録を追跡できる")
    func tracksMaxDays() {
        // Arrange
        var streak = Streak()

        // 5日連続
        for i in 0..<5 {
            streak.recordLogin(at: createDate(year: 2026, month: 1, day: 1 + i))
        }

        // 1日スキップして3日連続
        for i in 0..<3 {
            streak.recordLogin(at: createDate(year: 2026, month: 1, day: 7 + i))
        }

        // Assert
        #expect(streak.currentDays == 3)
        #expect(streak.maxDays == 5)
    }

    // MARK: - Helper

    private func createDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return Calendar.current.date(from: components)!
    }
}
