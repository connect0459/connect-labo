import Foundation

/// アンケートID
struct SurveyID: Hashable, Sendable, Codable {
    let value: String

    init(_ value: String = UUID().uuidString) {
        self.value = value
    }
}

/// アンケートを表すドメインオブジェクト
/// ビジネスルールとロジックを内包する（Rich Domain Object）
struct Survey: Identifiable, Equatable, Sendable {
    let id: SurveyID
    let title: String
    let description: String
    let questions: [SurveyQuestion]
    let reward: PointAmount
    let estimatedMinutes: Int
    let expiresAt: Date
    let category: SurveyCategory

    /// アンケートが回答可能かどうか
    /// - Parameter date: 判定基準日時（デフォルトは現在）
    func isAvailable(at date: Date = .now) -> Bool {
        date < expiresAt
    }

    /// 報酬効率（ポイント/分）を計算
    /// 高いほど効率的なアンケート
    func rewardEfficiency() -> Double {
        guard estimatedMinutes > 0 else { return 0 }
        return Double(reward.value) / Double(estimatedMinutes)
    }

    /// 高効率アンケートかどうか（20pt/分以上）
    var isHighEfficiency: Bool {
        rewardEfficiency() >= 20.0
    }

    /// 回答の妥当性を検証
    /// - Parameter answers: 回答リスト
    /// - Returns: 検証結果
    func validateAnswers(_ answers: [SurveyAnswer]) -> Result<Void, SurveyError> {
        guard answers.count == questions.count else {
            return .failure(.incompleteAnswers)
        }

        for (index, question) in questions.enumerated() {
            let answer = answers[index]
            if !question.isValidAnswer(answer) {
                return .failure(.invalidAnswer(questionIndex: index))
            }
        }

        return .success(())
    }

    /// 残り時間を取得
    /// - Parameter from: 基準日時
    /// - Returns: 残り時間（期限切れの場合はnil）
    func remainingTime(from date: Date = .now) -> TimeInterval? {
        let remaining = expiresAt.timeIntervalSince(date)
        return remaining > 0 ? remaining : nil
    }

    /// 残り時間の表示用文字列
    func remainingTimeLabel(from date: Date = .now) -> String? {
        guard let remaining = remainingTime(from: date) else { return nil }

        let hours = Int(remaining / 3600)
        let days = hours / 24

        if days > 0 {
            return "残り\(days)日"
        } else if hours > 0 {
            return "残り\(hours)時間"
        } else {
            return "まもなく終了"
        }
    }
}

/// アンケートカテゴリ
enum SurveyCategory: String, Sendable, CaseIterable, Codable {
    case general = "一般"
    case product = "商品"
    case service = "サービス"
    case lifestyle = "ライフスタイル"
    case monitor = "モニター"
}

/// アンケート関連のエラー
enum SurveyError: Error, Equatable {
    case incompleteAnswers
    case invalidAnswer(questionIndex: Int)
    case expired
    case alreadyAnswered
}

// MARK: - Sample Data

extension Survey {
    /// サンプルデータ
    static let samples: [Survey] = [
        Survey(
            id: SurveyID("survey-1"),
            title: "新商品に関するアンケート",
            description: "新しい飲料商品についてのご意見をお聞かせください",
            questions: [
                .singleChoice(text: "普段どのくらいの頻度で飲料を購入しますか？", choices: ["毎日", "週2-3回", "週1回", "月数回"]),
                .scale(text: "新商品のパッケージデザインについて評価してください", min: 1, max: 5, labels: ("悪い", "良い")),
                .freeText(text: "その他ご意見があればお聞かせください", maxLength: 500)
            ],
            reward: try! PointAmount(150),
            estimatedMinutes: 5,
            expiresAt: Date().addingTimeInterval(86400 * 7),
            category: .product
        ),
        Survey(
            id: SurveyID("survey-2"),
            title: "ライフスタイルアンケート",
            description: "日常生活についてお聞かせください",
            questions: [
                .multipleChoice(text: "休日の過ごし方を教えてください（複数選択可）", choices: ["外出", "自宅でゆっくり", "趣味", "家事", "運動"], maxSelections: 3)
            ],
            reward: try! PointAmount(50),
            estimatedMinutes: 2,
            expiresAt: Date().addingTimeInterval(86400 * 3),
            category: .lifestyle
        ),
        Survey(
            id: SurveyID("survey-3"),
            title: "サービス改善アンケート",
            description: "より良いサービス提供のためにご協力ください",
            questions: [
                .scale(text: "現在のサービスへの満足度を教えてください", min: 1, max: 10, labels: ("不満", "満足")),
                .freeText(text: "改善してほしい点があれば教えてください", maxLength: 1000)
            ],
            reward: try! PointAmount(200),
            estimatedMinutes: 8,
            expiresAt: Date().addingTimeInterval(86400 * 14),
            category: .service
        )
    ]

    /// テスト用フィクスチャ
    static func fixture(
        id: SurveyID = SurveyID(),
        title: String = "テストアンケート",
        description: String = "テスト用の説明文",
        questions: [SurveyQuestion] = [],
        reward: PointAmount = try! PointAmount(100),
        estimatedMinutes: Int = 5,
        expiresAt: Date = Date().addingTimeInterval(86400),
        category: SurveyCategory = .general
    ) -> Survey {
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
