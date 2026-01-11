import Testing
import Foundation
@testable import PointAppDomain

/// Survey（アンケート）のテスト
/// ビジネスルール: アンケートは期限があり、報酬効率（pt/分）で評価できる
@Suite("Survey Tests")
struct SurveyTests {

    // MARK: - 利用可能判定

    @Test("期限内のアンケートは回答可能")
    func availableWhenNotExpired() throws {
        // Arrange
        let futureDate = Date().addingTimeInterval(86400) // 24時間後
        let survey = try Survey.fixture(expiresAt: futureDate)

        // Act & Assert
        #expect(survey.isAvailable())
    }

    @Test("期限切れのアンケートは回答不可")
    func unavailableWhenExpired() throws {
        // Arrange
        let pastDate = Date().addingTimeInterval(-3600) // 1時間前
        let survey = try Survey.fixture(expiresAt: pastDate)

        // Act & Assert
        #expect(!survey.isAvailable())
    }

    // MARK: - 報酬効率

    @Test("報酬効率を計算できる")
    func calculateRewardEfficiency() throws {
        // Arrange: 100pt / 5分 = 20pt/分
        let survey = try Survey.fixture(
            reward: PointAmount(100),
            estimatedMinutes: 5
        )

        // Act
        let efficiency = survey.rewardEfficiency()

        // Assert
        #expect(efficiency == 20.0)
    }

    @Test("所要時間が0の場合は効率0")
    func zeroEfficiencyWhenZeroMinutes() throws {
        // Arrange
        let survey = try Survey.fixture(
            reward: PointAmount(100),
            estimatedMinutes: 0
        )

        // Act
        let efficiency = survey.rewardEfficiency()

        // Assert
        #expect(efficiency == 0)
    }

    @Test("高効率アンケートを判定できる")
    func determineHighEfficiency() throws {
        // Arrange
        let highEfficiency = try Survey.fixture(
            reward: PointAmount(100),
            estimatedMinutes: 5 // 20pt/分
        )
        let lowEfficiency = try Survey.fixture(
            reward: PointAmount(50),
            estimatedMinutes: 5 // 10pt/分
        )

        // Assert
        #expect(highEfficiency.isHighEfficiency())
        #expect(!lowEfficiency.isHighEfficiency())
    }

    // MARK: - 残り時間

    @Test("残り時間を取得できる")
    func getRemainingTime() throws {
        // Arrange
        let futureDate = Date().addingTimeInterval(7200) // 2時間後
        let survey = try Survey.fixture(expiresAt: futureDate)

        // Act
        let remaining = survey.remainingTime()

        // Assert
        #expect(remaining != nil)
        #expect(remaining! > 7000) // 約2時間
        #expect(remaining! < 7300)
    }

    @Test("期限切れの場合は残り時間nil")
    func nilRemainingTimeWhenExpired() throws {
        // Arrange
        let pastDate = Date().addingTimeInterval(-3600)
        let survey = try Survey.fixture(expiresAt: pastDate)

        // Act
        let remaining = survey.remainingTime()

        // Assert
        #expect(remaining == nil)
    }
}

// MARK: - SurveyQuestion Tests

@Suite("SurveyQuestion Tests")
struct SurveyQuestionTests {

    @Test("単一選択の質問を作成できる")
    func createSingleChoice() {
        // Act
        let question = SurveyQuestion.singleChoice(
            text: "満足度は？",
            choices: ["高", "中", "低"]
        )

        // Assert
        #expect(question.text == "満足度は？")
        if case .singleChoice(_, let choices) = question {
            #expect(choices == ["高", "中", "低"])
        } else {
            Issue.record("Expected singleChoice")
        }
    }

    @Test("複数選択の質問を作成できる")
    func createMultipleChoice() {
        // Act
        let question = SurveyQuestion.multipleChoice(
            text: "好きな色は？",
            choices: ["赤", "青", "緑"],
            maxSelections: 2
        )

        // Assert
        #expect(question.text == "好きな色は？")
        if case .multipleChoice(_, let choices, let max) = question {
            #expect(choices == ["赤", "青", "緑"])
            #expect(max == 2)
        } else {
            Issue.record("Expected multipleChoice")
        }
    }

    @Test("自由記述の質問を作成できる")
    func createFreeText() {
        // Act
        let question = SurveyQuestion.freeText(
            text: "ご意見をお聞かせください",
            maxLength: 500
        )

        // Assert
        #expect(question.text == "ご意見をお聞かせください")
    }

    @Test("スケールの質問を作成できる")
    func createScale() {
        // Act
        let question = SurveyQuestion.scale(
            text: "満足度を10点満点で",
            min: 1,
            max: 10,
            labels: ScaleLabels(min: "不満", max: "満足")
        )

        // Assert
        #expect(question.text == "満足度を10点満点で")
    }
}

// MARK: - SurveyAnswer Tests

@Suite("SurveyAnswer Tests")
struct SurveyAnswerTests {

    @Test("単一選択の回答を作成できる")
    func createSingleChoiceAnswer() {
        // Act
        let answer = SurveyAnswer.singleChoice("高")

        // Assert
        if case .singleChoice(let selected) = answer {
            #expect(selected == "高")
        } else {
            Issue.record("Expected singleChoice")
        }
    }

    @Test("複数選択の回答を作成できる")
    func createMultipleChoiceAnswer() {
        // Act
        let answer = SurveyAnswer.multipleChoice(["赤", "青"])

        // Assert
        if case .multipleChoice(let selected) = answer {
            #expect(selected == ["赤", "青"])
        } else {
            Issue.record("Expected multipleChoice")
        }
    }
}
