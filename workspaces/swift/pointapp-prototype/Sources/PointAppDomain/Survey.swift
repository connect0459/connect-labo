import Foundation

// MARK: - SurveyID

/// アンケートの識別子
public struct SurveyID: Equatable, Hashable, Sendable {
    public let value: String

    public init(_ value: String = UUID().uuidString) {
        self.value = value
    }
}

// MARK: - SurveyCategory

/// アンケートのカテゴリ
public enum SurveyCategory: String, Equatable, Sendable, CaseIterable {
    case product = "商品"
    case service = "サービス"
    case lifestyle = "ライフスタイル"
    case general = "その他"
}

// MARK: - SurveyError

/// アンケート関連のエラー
public enum SurveyError: Error, Equatable {
    case expired
    case incompleteAnswers
    case invalidAnswer
    case alreadyAnswered
}

// MARK: - Survey

/// アンケートを表すドメインオブジェクト
/// ビジネスルール: アンケートは期限があり、報酬効率（pt/分）で評価できる
public struct Survey: Identifiable, Equatable, Sendable {
    public let id: SurveyID
    public let title: String
    public let description: String
    public let questions: [SurveyQuestion]
    public let reward: PointAmount
    public let estimatedMinutes: Int
    public let expiresAt: Date
    public let category: SurveyCategory

    public init(
        id: SurveyID = SurveyID(),
        title: String,
        description: String = "",
        questions: [SurveyQuestion] = [],
        reward: PointAmount,
        estimatedMinutes: Int,
        expiresAt: Date,
        category: SurveyCategory = .general
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.questions = questions
        self.reward = reward
        self.estimatedMinutes = estimatedMinutes
        self.expiresAt = expiresAt
        self.category = category
    }

    // MARK: - ビジネスロジック

    /// アンケートが回答可能かどうか
    /// - Parameter date: 判定基準日時（デフォルトは現在）
    /// - Returns: 期限内であれば `true`
    public func isAvailable(at date: Date = .now) -> Bool {
        date < expiresAt
    }

    /// 報酬効率（ポイント/分）を計算
    /// - Returns: 1分あたりの獲得ポイント
    public func rewardEfficiency() -> Double {
        guard estimatedMinutes > 0 else { return 0 }
        return Double(reward.value) / Double(estimatedMinutes)
    }

    /// 高効率アンケートかどうか（20pt/分以上）
    public func isHighEfficiency() -> Bool {
        rewardEfficiency() >= 20.0
    }

    /// 残り時間（秒）
    /// - Returns: 期限までの秒数。期限切れの場合は `nil`
    public func remainingTime(from date: Date = .now) -> TimeInterval? {
        let remaining = expiresAt.timeIntervalSince(date)
        return remaining > 0 ? remaining : nil
    }

    /// 回答の妥当性を検証
    public func validateAnswers(_ answers: [SurveyAnswer]) -> Result<Void, SurveyError> {
        guard answers.count == questions.count else {
            return .failure(.incompleteAnswers)
        }
        // 追加のバリデーション（型の一致など）はここに追加
        return .success(())
    }
}

// MARK: - Survey Fixture（テスト用）

extension Survey {
    /// テスト用のフィクスチャを生成
    public static func fixture(
        id: SurveyID = SurveyID(),
        title: String = "テストアンケート",
        description: String = "テスト用の説明",
        questions: [SurveyQuestion] = [],
        reward: PointAmount = try! PointAmount(100),
        estimatedMinutes: Int = 5,
        expiresAt: Date = Date().addingTimeInterval(86400),
        category: SurveyCategory = .general
    ) throws -> Survey {
        Survey(
            id: id,
            title: title,
            description: description,
            questions: questions,
            reward: reward,
            estimatedMinutes: estimatedMinutes,
            expiresAt: expiresAt,
            category: category
        )
    }
}

// MARK: - SurveyQuestion

/// アンケートの質問
public enum SurveyQuestion: Equatable, Sendable {
    /// 単一選択
    case singleChoice(text: String, choices: [String])

    /// 複数選択
    case multipleChoice(text: String, choices: [String], maxSelections: Int?)

    /// 自由記述
    case freeText(text: String, maxLength: Int?)

    /// スケール（1-5, 1-10など）
    case scale(text: String, min: Int, max: Int, labels: (min: String, max: String)?)

    /// 質問テキスト
    public var text: String {
        switch self {
        case .singleChoice(let text, _),
             .multipleChoice(let text, _, _),
             .freeText(let text, _),
             .scale(let text, _, _, _):
            return text
        }
    }
}

// MARK: - SurveyAnswer

/// アンケートの回答
public enum SurveyAnswer: Equatable, Sendable {
    /// 単一選択の回答
    case singleChoice(String)

    /// 複数選択の回答
    case multipleChoice([String])

    /// 自由記述の回答
    case freeText(String)

    /// スケールの回答
    case scale(Int)
}
