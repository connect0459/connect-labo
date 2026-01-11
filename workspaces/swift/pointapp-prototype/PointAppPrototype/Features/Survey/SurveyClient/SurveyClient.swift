import ComposableArchitecture
import Foundation

/// アンケートClient
/// 外部境界（API/DB）を抽象化
struct SurveyClient {
    var fetchAvailable: @Sendable () async throws -> [Survey]
    var fetchByCategory: @Sendable (SurveyCategory) async throws -> [Survey]
    var findById: @Sendable (SurveyID) async throws -> Survey?
    var submitAnswer: @Sendable (SurveyID, [SurveyAnswer]) async throws -> PointAmount
}

extension SurveyClient: DependencyKey {
    /// 本番実装（プロトタイプではインメモリ）
    static let liveValue = SurveyClient(
        fetchAvailable: {
            // プロトタイプ: サンプルデータを返す
            try await Task.sleep(for: .milliseconds(500))
            return Survey.samples.filter { $0.isAvailable() }
                .sorted { $0.rewardEfficiency() > $1.rewardEfficiency() }
        },
        fetchByCategory: { category in
            try await Task.sleep(for: .milliseconds(300))
            return Survey.samples.filter { $0.category == category && $0.isAvailable() }
        },
        findById: { id in
            try await Task.sleep(for: .milliseconds(200))
            return Survey.samples.first { $0.id == id }
        },
        submitAnswer: { surveyId, answers in
            try await Task.sleep(for: .milliseconds(800))
            guard let survey = Survey.samples.first(where: { $0.id == surveyId }) else {
                throw SurveyClientError.surveyNotFound
            }
            return survey.reward
        }
    )

    /// プレビュー用（即座に返す）
    static let previewValue = SurveyClient(
        fetchAvailable: { Survey.samples },
        fetchByCategory: { _ in Survey.samples },
        findById: { id in Survey.samples.first { $0.id == id } },
        submitAnswer: { _, _ in try! PointAmount(100) }
    )

    /// テスト用（デフォルトは未実装でクラッシュ）
    static let testValue = SurveyClient(
        fetchAvailable: unimplemented("SurveyClient.fetchAvailable"),
        fetchByCategory: unimplemented("SurveyClient.fetchByCategory"),
        findById: unimplemented("SurveyClient.findById"),
        submitAnswer: unimplemented("SurveyClient.submitAnswer")
    )
}

extension DependencyValues {
    var surveyClient: SurveyClient {
        get { self[SurveyClient.self] }
        set { self[SurveyClient.self] = newValue }
    }
}

enum SurveyClientError: Error {
    case surveyNotFound
    case networkError
}
