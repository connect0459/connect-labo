import Testing
import Foundation
@testable import PointAppDomain

/// PointExpirationAlert（ポイント期限切れアラート）のテスト
/// ビジネスルール: ポイントの期限切れを事前に通知し、失効を防ぐ
@Suite("PointExpirationAlert Tests")
struct PointExpirationAlertTests {

    // MARK: - アラート生成

    @Test("期限切れ間近のポイントからアラートを生成できる")
    func createAlertFromExpiringPoints() throws {
        // Arrange
        let expiresAt = Date().addingTimeInterval(86400 * 3) // 3日後
        let alert = PointExpirationAlert(
            amount: try PointAmount(500),
            expiresAt: expiresAt,
            createdAt: Date()
        )

        // Assert
        #expect(alert.amount.value == 500)
        #expect(alert.expiresAt == expiresAt)
    }

    @Test("アラートIDが一意に生成される")
    func alertHasUniqueId() throws {
        // Arrange
        let alert1 = PointExpirationAlert(
            amount: try PointAmount(100),
            expiresAt: Date().addingTimeInterval(86400),
            createdAt: Date()
        )
        let alert2 = PointExpirationAlert(
            amount: try PointAmount(100),
            expiresAt: Date().addingTimeInterval(86400),
            createdAt: Date()
        )

        // Assert
        #expect(alert1.id != alert2.id)
    }

    // MARK: - 緊急度判定

    @Test("24時間以内の期限切れは緊急")
    func urgentWhenExpiringWithin24Hours() throws {
        // Arrange
        let expiresAt = Date().addingTimeInterval(3600 * 12) // 12時間後
        let alert = PointExpirationAlert(
            amount: try PointAmount(500),
            expiresAt: expiresAt,
            createdAt: Date()
        )

        // Act
        let urgency = alert.urgency()

        // Assert
        #expect(urgency == .urgent)
    }

    @Test("7日以内の期限切れは警告")
    func warningWhenExpiringWithin7Days() throws {
        // Arrange
        let expiresAt = Date().addingTimeInterval(86400 * 5) // 5日後
        let alert = PointExpirationAlert(
            amount: try PointAmount(500),
            expiresAt: expiresAt,
            createdAt: Date()
        )

        // Act
        let urgency = alert.urgency()

        // Assert
        #expect(urgency == .warning)
    }

    @Test("30日以内の期限切れは情報")
    func infoWhenExpiringWithin30Days() throws {
        // Arrange
        let expiresAt = Date().addingTimeInterval(86400 * 20) // 20日後
        let alert = PointExpirationAlert(
            amount: try PointAmount(500),
            expiresAt: expiresAt,
            createdAt: Date()
        )

        // Act
        let urgency = alert.urgency()

        // Assert
        #expect(urgency == .info)
    }

    @Test("30日以上先は低優先度")
    func lowWhenExpiringAfter30Days() throws {
        // Arrange
        let expiresAt = Date().addingTimeInterval(86400 * 60) // 60日後
        let alert = PointExpirationAlert(
            amount: try PointAmount(500),
            expiresAt: expiresAt,
            createdAt: Date()
        )

        // Act
        let urgency = alert.urgency()

        // Assert
        #expect(urgency == .low)
    }

    @Test("期限切れ済みは期限切れ状態")
    func expiredWhenPastExpiration() throws {
        // Arrange
        let expiresAt = Date().addingTimeInterval(-3600) // 1時間前
        let alert = PointExpirationAlert(
            amount: try PointAmount(500),
            expiresAt: expiresAt,
            createdAt: Date()
        )

        // Act
        let urgency = alert.urgency()

        // Assert
        #expect(urgency == .expired)
    }

    // MARK: - 残り時間

    @Test("残り時間を取得できる")
    func getRemainingTime() throws {
        // Arrange
        let expiresAt = Date().addingTimeInterval(86400 * 3) // 3日後
        let alert = PointExpirationAlert(
            amount: try PointAmount(500),
            expiresAt: expiresAt,
            createdAt: Date()
        )

        // Act
        let remaining = alert.remainingTime()

        // Assert
        #expect(remaining != nil)
        #expect(remaining! > 86400 * 2) // 2日以上
        #expect(remaining! < 86400 * 4) // 4日未満
    }

    @Test("期限切れの場合は残り時間nil")
    func nilRemainingTimeWhenExpired() throws {
        // Arrange
        let expiresAt = Date().addingTimeInterval(-3600) // 1時間前
        let alert = PointExpirationAlert(
            amount: try PointAmount(500),
            expiresAt: expiresAt,
            createdAt: Date()
        )

        // Act
        let remaining = alert.remainingTime()

        // Assert
        #expect(remaining == nil)
    }

    // MARK: - 表示用テキスト

    @Test("残り日数を表示用テキストで取得できる")
    func getRemainingDaysText() throws {
        // Arrange
        let expiresAt = Date().addingTimeInterval(86400 * 3 + 3600) // 3日と1時間後
        let alert = PointExpirationAlert(
            amount: try PointAmount(500),
            expiresAt: expiresAt,
            createdAt: Date()
        )

        // Act
        let text = alert.remainingDaysText()

        // Assert
        #expect(text == "3日")
    }

    @Test("24時間未満は時間で表示")
    func showHoursWhenLessThan24Hours() throws {
        // Arrange: 固定の基準日時を使用してタイミング問題を回避
        let baseDate = Date()
        let expiresAt = baseDate.addingTimeInterval(3600 * 5 + 60) // 5時間と1分後
        let alert = PointExpirationAlert(
            amount: try PointAmount(500),
            expiresAt: expiresAt,
            createdAt: baseDate
        )

        // Act
        let text = alert.remainingDaysText(at: baseDate)

        // Assert
        #expect(text == "5時間")
    }

    @Test("期限切れは期限切れと表示")
    func showExpiredTextWhenExpired() throws {
        // Arrange
        let expiresAt = Date().addingTimeInterval(-3600)
        let alert = PointExpirationAlert(
            amount: try PointAmount(500),
            expiresAt: expiresAt,
            createdAt: Date()
        )

        // Act
        let text = alert.remainingDaysText()

        // Assert
        #expect(text == "期限切れ")
    }
}

// MARK: - ExpirationAlertService Tests

@Suite("ExpirationAlertService Tests")
struct ExpirationAlertServiceTests {

    @Test("PointBalanceからアラートを生成できる")
    func generateAlertsFromBalance() throws {
        // Arrange
        var balance = PointBalance()
        let soon = Date().addingTimeInterval(86400 * 3) // 3日後
        let later = Date().addingTimeInterval(86400 * 60) // 60日後

        balance.add(try PointAmount(100), expiresAt: soon)
        balance.add(try PointAmount(200), expiresAt: later)

        let service = ExpirationAlertService()

        // Act: 30日以内に切れるポイントのアラート
        let alerts = service.generateAlerts(from: balance, within: 86400 * 30)

        // Assert
        #expect(alerts.count == 1)
        #expect(alerts.first?.amount.value == 100)
    }

    @Test("期限切れポイントはアラートに含まれない")
    func excludeExpiredFromAlerts() throws {
        // Arrange
        var balance = PointBalance()
        let expired = Date().addingTimeInterval(-3600) // 1時間前
        let soon = Date().addingTimeInterval(86400 * 3) // 3日後

        balance.add(try PointAmount(100), expiresAt: expired)
        balance.add(try PointAmount(200), expiresAt: soon)

        let service = ExpirationAlertService()

        // Act
        let alerts = service.generateAlerts(from: balance, within: 86400 * 30)

        // Assert
        #expect(alerts.count == 1)
        #expect(alerts.first?.amount.value == 200)
    }

    @Test("アラートは期限の近い順にソートされる")
    func alertsSortedByExpiration() throws {
        // Arrange
        var balance = PointBalance()
        let day10 = Date().addingTimeInterval(86400 * 10)
        let day3 = Date().addingTimeInterval(86400 * 3)
        let day7 = Date().addingTimeInterval(86400 * 7)

        balance.add(try PointAmount(100), expiresAt: day10)
        balance.add(try PointAmount(200), expiresAt: day3)
        balance.add(try PointAmount(300), expiresAt: day7)

        let service = ExpirationAlertService()

        // Act
        let alerts = service.generateAlerts(from: balance, within: 86400 * 30)

        // Assert
        #expect(alerts.count == 3)
        #expect(alerts[0].amount.value == 200) // 3日後
        #expect(alerts[1].amount.value == 300) // 7日後
        #expect(alerts[2].amount.value == 100) // 10日後
    }

    @Test("合計失効予定ポイントを取得できる")
    func getTotalExpiringAmount() throws {
        // Arrange
        var balance = PointBalance()
        balance.add(try PointAmount(100), expiresAt: Date().addingTimeInterval(86400 * 3))
        balance.add(try PointAmount(200), expiresAt: Date().addingTimeInterval(86400 * 5))
        balance.add(try PointAmount(500), expiresAt: Date().addingTimeInterval(86400 * 60))

        let service = ExpirationAlertService()

        // Act: 7日以内に切れるポイント
        let total = service.totalExpiringAmount(from: balance, within: 86400 * 7)

        // Assert
        #expect(total.value == 300) // 100 + 200
    }
}
