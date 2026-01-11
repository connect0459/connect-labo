import ComposableArchitecture
import Foundation

/// アンケート詳細Feature
@Reducer
struct SurveyDetailFeature {
    // MARK: - State

    @ObservableState
    struct State: Equatable, Identifiable {
        let survey: Survey
        var answers: [SurveyAnswer] = []
        var currentQuestionIndex: Int = 0
        var isSubmitting = false
        var earnedPoints: PointAmount?
        var errorMessage: String?

        var id: SurveyID { survey.id }

        var currentQuestion: SurveyQuestion? {
            guard currentQuestionIndex < survey.questions.count else { return nil }
            return survey.questions[currentQuestionIndex]
        }

        var isLastQuestion: Bool {
            currentQuestionIndex >= survey.questions.count - 1
        }

        var canSubmit: Bool {
            answers.count == survey.questions.count
        }

        var progress: Double {
            guard !survey.questions.isEmpty else { return 0 }
            return Double(answers.count) / Double(survey.questions.count)
        }
    }

    // MARK: - Action

    enum Action {
        // ユーザーアクション
        case answerSelected(SurveyAnswer)
        case nextButtonTapped
        case previousButtonTapped
        case submitButtonTapped
        case closeButtonTapped

        // 内部アクション
        case submitCompleted(Result<PointAmount, Error>)

        // 親への通知
        case surveyCompleted
    }

    // MARK: - Dependencies

    @Dependency(\.surveyClient) var surveyClient
    @Dependency(\.dismiss) var dismiss

    // MARK: - Reducer

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .answerSelected(let answer):
                // 現在の質問の回答を保存
                if state.currentQuestionIndex < state.answers.count {
                    state.answers[state.currentQuestionIndex] = answer
                } else {
                    state.answers.append(answer)
                }
                return .none

            case .nextButtonTapped:
                guard state.currentQuestionIndex < state.survey.questions.count - 1 else {
                    return .none
                }
                state.currentQuestionIndex += 1
                return .none

            case .previousButtonTapped:
                guard state.currentQuestionIndex > 0 else { return .none }
                state.currentQuestionIndex -= 1
                return .none

            case .submitButtonTapped:
                guard state.canSubmit else { return .none }
                state.isSubmitting = true
                state.errorMessage = nil

                let surveyId = state.survey.id
                let answers = state.answers

                return .run { send in
                    do {
                        let earnedPoints = try await surveyClient.submitAnswer(surveyId, answers)
                        await send(.submitCompleted(.success(earnedPoints)))
                    } catch {
                        await send(.submitCompleted(.failure(error)))
                    }
                }

            case .closeButtonTapped:
                return .run { _ in
                    await dismiss()
                }

            case .submitCompleted(.success(let points)):
                state.isSubmitting = false
                state.earnedPoints = points
                return .none

            case .submitCompleted(.failure(let error)):
                state.isSubmitting = false
                state.errorMessage = error.localizedDescription
                return .none

            case .surveyCompleted:
                return .run { _ in
                    await dismiss()
                }
            }
        }
    }
}
