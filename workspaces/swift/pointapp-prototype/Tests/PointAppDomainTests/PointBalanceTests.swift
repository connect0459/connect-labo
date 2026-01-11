import Testing
import Foundation
@testable import PointAppDomain

/// PointBalance（ポイント残高）のテスト
/// ビジネスルール: ポイントには有効期限があり、期限切れポイントは使用不可
@Suite("PointBalance Tests")
struct PointBalanceTests {

    // MARK: - 初期状態

    @Test("初期残高は0")
    func initialBalanceIsZero() {
        // Arrange
        let balance = PointBalance()

        // Assert
        #expect(balance.total.value == 0)
    }

    // MARK: - ポイント加算

    @Test("ポイントを加算できる")
    func addPoints() throws {
        // Arrange
        var balance = PointBalance()
        let futureDate = Date().addingTimeInterval(86400)

        // Act
        balance.add(try PointAmount(100), expiresAt: futureDate)

        // Assert
        #expect(balance.total.value == 100)
    }

    @Test("複数回のポイント加算が累積される")
    func accumulatePoints() throws {
        // Arrange
        var balance = PointBalance()
        let futureDate = Date().addingTimeInterval(86400)

        // Act
        balance.add(try PointAmount(100), expiresAt: futureDate)
        balance.add(try PointAmount(50), expiresAt: futureDate)

        // Assert
        #expect(balance.total.value == 150)
    }

    // MARK: - ポイント使用

    @Test("ポイントを使用できる")
    func usePoints() throws {
        // Arrange
        var balance = PointBalance()
        let futureDate = Date().addingTimeInterval(86400)
        balance.add(try PointAmount(100), expiresAt: futureDate)

        // Act
        let result = balance.use(try PointAmount(30))

        // Assert
        switch result {
        case .success: break
        case .failure: Issue.record("Expected success")
        }
        #expect(balance.availableTotal().value == 70)
    }

    @Test("残高不足の場合は使用できない")
    func failsWhenInsufficientBalance() throws {
        // Arrange
        var balance = PointBalance()
        let futureDate = Date().addingTimeInterval(86400)
        balance.add(try PointAmount(50), expiresAt: futureDate)

        // Act
        let result = balance.use(try PointAmount(100))

        // Assert
        switch result {
        case .success: Issue.record("Expected failure")
        case .failure(let error): #expect(error == .insufficientBalance)
        }
    }

    // MARK: - 有効期限

    @Test("期限切れポイントは残高に含まれない")
    func excludesExpiredPoints() throws {
        // Arrange
        var balance = PointBalance()
        let pastDate = Date().addingTimeInterval(-3600) // 1時間前
        let futureDate = Date().addingTimeInterval(86400)

        balance.add(try PointAmount(100), expiresAt: pastDate) // 期限切れ
        balance.add(try PointAmount(50), expiresAt: futureDate) // 有効

        // Assert
        #expect(balance.availableTotal().value == 50)
    }

    @Test("期限切れ間近のポイントを取得できる")
    func getPointsExpiringSoon() throws {
        // Arrange
        var balance = PointBalance()
        let soonDate = Date().addingTimeInterval(3600) // 1時間後
        let laterDate = Date().addingTimeInterval(86400 * 30) // 30日後

        balance.add(try PointAmount(100), expiresAt: soonDate)
        balance.add(try PointAmount(200), expiresAt: laterDate)

        // Act: 24時間以内に切れるポイント
        let expiringSoon = balance.pointsExpiringSoon(within: 86400)

        // Assert
        #expect(expiringSoon.value == 100)
    }

    @Test("期限切れ間近のポイントがない場合は0")
    func zeroWhenNoPointsExpiringSoon() throws {
        // Arrange
        var balance = PointBalance()
        let laterDate = Date().addingTimeInterval(86400 * 30) // 30日後
        balance.add(try PointAmount(100), expiresAt: laterDate)

        // Act
        let expiringSoon = balance.pointsExpiringSoon(within: 86400)

        // Assert
        #expect(expiringSoon.value == 0)
    }

    // MARK: - 円換算

    @Test("残高を円換算で取得できる")
    func getBalanceInYen() throws {
        // Arrange
        var balance = PointBalance()
        let futureDate = Date().addingTimeInterval(86400)
        balance.add(try PointAmount(1000), expiresAt: futureDate)

        // Act
        let yen = balance.availableTotal().toYen()

        // Assert
        #expect(yen == 100) // 1000pt = 100円
    }
}

// MARK: - PointTransaction Tests

@Suite("PointTransaction Tests")
struct PointTransactionTests {

    @Test("獲得トランザクションを作成できる")
    func createEarnTransaction() throws {
        // Act
        let transaction = PointTransaction.earn(
            amount: try PointAmount(100),
            reason: .surveyCompleted(surveyId: "survey-1"),
            expiresAt: Date().addingTimeInterval(86400)
        )

        // Assert
        #expect(transaction.amount.value == 100)
        #expect(transaction.type == .earn)
    }

    @Test("使用トランザクションを作成できる")
    func createSpendTransaction() throws {
        // Act
        let transaction = PointTransaction.spend(
            amount: try PointAmount(500),
            reason: .exchanged(to: "Amazonギフト券")
        )

        // Assert
        #expect(transaction.amount.value == 500)
        #expect(transaction.type == .spend)
    }

    @Test("トランザクションにはタイムスタンプがある")
    func transactionHasTimestamp() throws {
        // Arrange
        let before = Date()

        // Act
        let transaction = PointTransaction.earn(
            amount: try PointAmount(100),
            reason: .dailyLogin,
            expiresAt: Date().addingTimeInterval(86400)
        )

        // Assert
        #expect(transaction.createdAt >= before)
    }
}
