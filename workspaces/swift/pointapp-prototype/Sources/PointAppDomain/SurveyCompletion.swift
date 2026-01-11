import Foundation

// MARK: - SurveyCompletion

/// アンケート回答記録を表すドメインオブジェクト
/// ビジネスルール: 回答済みアンケートを追跡し、重複回答を防止
public struct SurveyCompletion: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let surveyId: SurveyID
    public let earnedPoints: PointAmount
    public let completedAt: Date
    public let duration: TimeInterval?

    public init(
        id: UUID = UUID(),
        surveyId: SurveyID,
        earnedPoints: PointAmount,
        completedAt: Date = Date(),
        duration: TimeInterval? = nil
    ) {
        self.id = id
        self.surveyId = surveyId
        self.earnedPoints = earnedPoints
        self.completedAt = completedAt
        self.duration = duration
    }

    /// Surveyから回答記録を作成
    public static func from(
        survey: Survey,
        completedAt: Date = Date(),
        duration: TimeInterval? = nil
    ) -> SurveyCompletion {
        SurveyCompletion(
            surveyId: survey.id,
            earnedPoints: survey.reward,
            completedAt: completedAt,
            duration: duration
        )
    }
}

// MARK: - SurveyCompletionHistory

/// アンケート回答履歴を管理するドメインオブジェクト
public struct SurveyCompletionHistory: Equatable, Sendable {
    public private(set) var completions: [SurveyCompletion]

    public init() {
        self.completions = []
    }

    // MARK: - 履歴管理

    /// 回答を追加
    public mutating func add(_ completion: SurveyCompletion) {
        completions.append(completion)
    }

    // MARK: - 回答済み判定

    /// 指定アンケートが回答済みか判定
    public func isCompleted(surveyId: SurveyID) -> Bool {
        completions.contains { $0.surveyId == surveyId }
    }

    /// 指定アンケートの回答記録を取得
    public func completion(for surveyId: SurveyID) -> SurveyCompletion? {
        completions.first { $0.surveyId == surveyId }
    }

    // MARK: - 統計

    /// 合計獲得ポイント
    public func totalEarnedPoints() -> PointAmount {
        let total = completions.reduce(0) { $0 + $1.earnedPoints.value }
        return try! PointAmount(total)
    }

    /// 回答数
    public func completionCount() -> Int {
        completions.count
    }

    // MARK: - 期間フィルタ

    /// 指定日の回答を取得
    private func completions(on date: Date) -> [SurveyCompletion] {
        let calendar = Calendar.current
        return completions.filter { completion in
            calendar.isDate(completion.completedAt, inSameDayAs: date)
        }
    }

    /// 指定日の回答数
    public func completionCount(on date: Date) -> Int {
        completions(on: date).count
    }

    /// 指定日の獲得ポイント
    public func totalEarnedPoints(on date: Date) -> PointAmount {
        let total = completions(on: date).reduce(0) { $0 + $1.earnedPoints.value }
        return try! PointAmount(total)
    }

    // MARK: - 最近の回答

    /// 最近の回答を取得（新しい順）
    public func recentCompletions(limit: Int) -> [SurveyCompletion] {
        completions
            .sorted { $0.completedAt > $1.completedAt }
            .prefix(limit)
            .map { $0 }
    }
}
