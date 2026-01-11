import XCTest
@testable import PointAppDomain

/// Survey（アンケート）のテスト
/// ビジネスルール: アンケートは期限があり、報酬効率（pt/分）で評価できる
final class SurveyTests: XCTestCase {

    // MARK: - 利用可能判定

    func test_期限内のアンケートは回答可能() throws {
        // Arrange
        let futureDate = Date().addingTimeInterval(86400) // 24時間後
        let survey = try Survey.fixture(expiresAt: futureDate)

        // Act & Assert
        XCTAssertTrue(survey.isAvailable())
    }

    func test_期限切れのアンケートは回答不可() throws {
        // Arrange
        let pastDate = Date().addingTimeInterval(-3600) // 1時間前
        let survey = try Survey.fixture(expiresAt: pastDate)

        // Act & Assert
        XCTAssertFalse(survey.isAvailable())
    }

    // MARK: - 報酬効率

    func test_報酬効率を計算できる() throws {
        // Arrange: 100pt / 5分 = 20pt/分
        let survey = try Survey.fixture(
            reward: PointAmount(100),
            estimatedMinutes: 5
        )

        // Act
        let efficiency = survey.rewardEfficiency()

        // Assert
        XCTAssertEqual(efficiency, 20.0)
    }

    func test_所要時間が0の場合は効率0() throws {
        // Arrange
        let survey = try Survey.fixture(
            reward: PointAmount(100),
            estimatedMinutes: 0
        )

        // Act
        let efficiency = survey.rewardEfficiency()

        // Assert
        XCTAssertEqual(efficiency, 0)
    }

    func test_高効率アンケートを判定できる() throws {
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
        XCTAssertTrue(highEfficiency.isHighEfficiency())
        XCTAssertFalse(lowEfficiency.isHighEfficiency())
    }

    // MARK: - 残り時間

    func test_残り時間を取得できる() throws {
        // Arrange
        let futureDate = Date().addingTimeInterval(7200) // 2時間後
        let survey = try Survey.fixture(expiresAt: futureDate)

        // Act
        let remaining = survey.remainingTime()

        // Assert
        XCTAssertNotNil(remaining)
        XCTAssertGreaterThan(remaining!, 7000) // 約2時間
        XCTAssertLessThan(remaining!, 7300)
    }

    func test_期限切れの場合は残り時間nil() throws {
        // Arrange
        let pastDate = Date().addingTimeInterval(-3600)
        let survey = try Survey.fixture(expiresAt: pastDate)

        // Act
        let remaining = survey.remainingTime()

        // Assert
        XCTAssertNil(remaining)
    }
}

// MARK: - SurveyQuestion Tests

final class SurveyQuestionTests: XCTestCase {

    func test_単一選択の質問を作成できる() {
        // Act
        let question = SurveyQuestion.singleChoice(
            text: "満足度は？",
            choices: ["高", "中", "低"]
        )

        // Assert
        XCTAssertEqual(question.text, "満足度は？")
        if case .singleChoice(_, let choices) = question {
            XCTAssertEqual(choices, ["高", "中", "低"])
        } else {
            XCTFail("Expected singleChoice")
        }
    }

    func test_複数選択の質問を作成できる() {
        // Act
        let question = SurveyQuestion.multipleChoice(
            text: "好きな色は？",
            choices: ["赤", "青", "緑"],
            maxSelections: 2
        )

        // Assert
        XCTAssertEqual(question.text, "好きな色は？")
        if case .multipleChoice(_, let choices, let max) = question {
            XCTAssertEqual(choices, ["赤", "青", "緑"])
            XCTAssertEqual(max, 2)
        } else {
            XCTFail("Expected multipleChoice")
        }
    }

    func test_自由記述の質問を作成できる() {
        // Act
        let question = SurveyQuestion.freeText(
            text: "ご意見をお聞かせください",
            maxLength: 500
        )

        // Assert
        XCTAssertEqual(question.text, "ご意見をお聞かせください")
    }

    func test_スケールの質問を作成できる() {
        // Act
        let question = SurveyQuestion.scale(
            text: "満足度を10点満点で",
            min: 1,
            max: 10,
            labels: ScaleLabels(min: "不満", max: "満足")
        )

        // Assert
        XCTAssertEqual(question.text, "満足度を10点満点で")
    }
}

// MARK: - SurveyAnswer Tests

final class SurveyAnswerTests: XCTestCase {

    func test_単一選択の回答を作成できる() {
        // Act
        let answer = SurveyAnswer.singleChoice("高")

        // Assert
        if case .singleChoice(let selected) = answer {
            XCTAssertEqual(selected, "高")
        } else {
            XCTFail("Expected singleChoice")
        }
    }

    func test_複数選択の回答を作成できる() {
        // Act
        let answer = SurveyAnswer.multipleChoice(["赤", "青"])

        // Assert
        if case .multipleChoice(let selected) = answer {
            XCTAssertEqual(selected, ["赤", "青"])
        } else {
            XCTFail("Expected multipleChoice")
        }
    }
}
