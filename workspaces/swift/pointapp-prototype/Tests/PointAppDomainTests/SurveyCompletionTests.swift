import Testing
import Foundation
@testable import PointAppDomain

/// SurveyCompletion（アンケート回答履歴）のテスト
/// ビジネスルール: 回答済みアンケートを追跡し、重複回答を防止
@Suite("SurveyCompletion Tests")
struct SurveyCompletionTests {

    // MARK: - 回答記録の作成

    @Test("回答記録を作成できる")
    func createCompletion() throws {
        // Arrange
        let surveyId = SurveyID("survey-123")
        let earnedPoints = try PointAmount(100)

        // Act
        let completion = SurveyCompletion(
            surveyId: surveyId,
            earnedPoints: earnedPoints,
            completedAt: Date()
        )

        // Assert
        #expect(completion.surveyId == surveyId)
        #expect(completion.earnedPoints.value == 100)
    }

    @Test("回答記録には一意のIDがある")
    func completionHasUniqueId() throws {
        // Arrange & Act
        let completion1 = SurveyCompletion(
            surveyId: SurveyID("survey-1"),
            earnedPoints: try PointAmount(100),
            completedAt: Date()
        )
        let completion2 = SurveyCompletion(
            surveyId: SurveyID("survey-1"),
            earnedPoints: try PointAmount(100),
            completedAt: Date()
        )

        // Assert
        #expect(completion1.id != completion2.id)
    }

    @Test("回答時間を記録できる")
    func recordCompletionTime() throws {
        // Arrange
        let startTime = Date()
        let completionTime = Date()
        let duration: TimeInterval = 180 // 3分

        // Act
        let completion = SurveyCompletion(
            surveyId: SurveyID("survey-1"),
            earnedPoints: try PointAmount(50),
            completedAt: completionTime,
            duration: duration
        )

        // Assert
        #expect(completion.duration == 180)
    }
}

// MARK: - SurveyCompletionHistory Tests

@Suite("SurveyCompletionHistory Tests")
struct SurveyCompletionHistoryTests {

    // MARK: - 履歴管理

    @Test("空の履歴を作成できる")
    func createEmptyHistory() {
        // Act
        let history = SurveyCompletionHistory()

        // Assert
        #expect(history.completions.isEmpty)
    }

    @Test("回答を追加できる")
    func addCompletion() throws {
        // Arrange
        var history = SurveyCompletionHistory()
        let completion = SurveyCompletion(
            surveyId: SurveyID("survey-1"),
            earnedPoints: try PointAmount(100),
            completedAt: Date()
        )

        // Act
        history.add(completion)

        // Assert
        #expect(history.completions.count == 1)
    }

    // MARK: - 回答済み判定

    @Test("アンケートが回答済みか判定できる")
    func checkIfCompleted() throws {
        // Arrange
        var history = SurveyCompletionHistory()
        let surveyId = SurveyID("survey-1")
        history.add(SurveyCompletion(
            surveyId: surveyId,
            earnedPoints: try PointAmount(100),
            completedAt: Date()
        ))

        // Act & Assert
        #expect(history.isCompleted(surveyId: surveyId))
        #expect(!history.isCompleted(surveyId: SurveyID("survey-2")))
    }

    @Test("回答済みアンケートの回答記録を取得できる")
    func getCompletionForSurvey() throws {
        // Arrange
        var history = SurveyCompletionHistory()
        let surveyId = SurveyID("survey-1")
        let completion = SurveyCompletion(
            surveyId: surveyId,
            earnedPoints: try PointAmount(100),
            completedAt: Date()
        )
        history.add(completion)

        // Act
        let found = history.completion(for: surveyId)

        // Assert
        #expect(found?.surveyId == surveyId)
    }

    // MARK: - 統計

    @Test("合計獲得ポイントを取得できる")
    func getTotalEarnedPoints() throws {
        // Arrange
        var history = SurveyCompletionHistory()
        history.add(SurveyCompletion(
            surveyId: SurveyID("survey-1"),
            earnedPoints: try PointAmount(100),
            completedAt: Date()
        ))
        history.add(SurveyCompletion(
            surveyId: SurveyID("survey-2"),
            earnedPoints: try PointAmount(150),
            completedAt: Date()
        ))

        // Act
        let total = history.totalEarnedPoints()

        // Assert
        #expect(total.value == 250)
    }

    @Test("回答数を取得できる")
    func getCompletionCount() throws {
        // Arrange
        var history = SurveyCompletionHistory()
        history.add(SurveyCompletion(
            surveyId: SurveyID("survey-1"),
            earnedPoints: try PointAmount(100),
            completedAt: Date()
        ))
        history.add(SurveyCompletion(
            surveyId: SurveyID("survey-2"),
            earnedPoints: try PointAmount(50),
            completedAt: Date()
        ))

        // Act
        let count = history.completionCount()

        // Assert
        #expect(count == 2)
    }

    // MARK: - 期間フィルタ

    @Test("今日の回答数を取得できる")
    func getTodayCompletionCount() throws {
        // Arrange
        var history = SurveyCompletionHistory()
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400 * 2)

        history.add(SurveyCompletion(
            surveyId: SurveyID("survey-1"),
            earnedPoints: try PointAmount(100),
            completedAt: now
        ))
        history.add(SurveyCompletion(
            surveyId: SurveyID("survey-2"),
            earnedPoints: try PointAmount(50),
            completedAt: yesterday
        ))

        // Act
        let todayCount = history.completionCount(on: now)

        // Assert
        #expect(todayCount == 1)
    }

    @Test("今日の獲得ポイントを取得できる")
    func getTodayEarnedPoints() throws {
        // Arrange
        var history = SurveyCompletionHistory()
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400 * 2)

        history.add(SurveyCompletion(
            surveyId: SurveyID("survey-1"),
            earnedPoints: try PointAmount(100),
            completedAt: now
        ))
        history.add(SurveyCompletion(
            surveyId: SurveyID("survey-2"),
            earnedPoints: try PointAmount(50),
            completedAt: yesterday
        ))

        // Act
        let todayPoints = history.totalEarnedPoints(on: now)

        // Assert
        #expect(todayPoints.value == 100)
    }

    // MARK: - 最近の回答

    @Test("最近の回答を取得できる")
    func getRecentCompletions() throws {
        // Arrange
        var history = SurveyCompletionHistory()
        for i in 1...10 {
            history.add(SurveyCompletion(
                surveyId: SurveyID("survey-\(i)"),
                earnedPoints: try PointAmount(10 * i),
                completedAt: Date().addingTimeInterval(Double(-i * 3600))
            ))
        }

        // Act
        let recent = history.recentCompletions(limit: 5)

        // Assert
        #expect(recent.count == 5)
        // 最新順（survey-1が最初、survey-5が最後）
        #expect(recent.first?.surveyId.value == "survey-1")
    }

    // MARK: - Surveyとの連携

    @Test("Surveyから回答記録を作成できる")
    func createCompletionFromSurvey() throws {
        // Arrange
        let survey = try Survey.fixture(
            id: SurveyID("survey-123"),
            reward: PointAmount(100)
        )

        // Act
        let completion = SurveyCompletion.from(
            survey: survey,
            duration: 120
        )

        // Assert
        #expect(completion.surveyId == survey.id)
        #expect(completion.earnedPoints.value == 100)
        #expect(completion.duration == 120)
    }
}
