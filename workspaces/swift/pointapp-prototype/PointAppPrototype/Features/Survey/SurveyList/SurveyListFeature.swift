import ComposableArchitecture
import Foundation

/// アンケート一覧Feature
@Reducer
struct SurveyListFeature {
    // MARK: - State

    @ObservableState
    struct State: Equatable {
        var surveys: [Survey] = []
        var isLoading = false
        var selectedCategory: SurveyCategory?
        var errorMessage: String?
        @Presents var detail: SurveyDetailFeature.State?
    }

    // MARK: - Action

    enum Action {
        // ユーザーアクション
        case onAppear
        case categorySelected(SurveyCategory?)
        case surveyTapped(Survey)
        case refreshButtonTapped

        // 内部アクション
        case surveysLoaded(Result<[Survey], Error>)

        // 子Feature
        case detail(PresentationAction<SurveyDetailFeature.Action>)
    }

    // MARK: - Dependencies

    @Dependency(\.surveyClient) var surveyClient

    // MARK: - Reducer

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.isLoading else { return .none }
                state.isLoading = true
                state.errorMessage = nil

                let category = state.selectedCategory
                return .run { send in
                    do {
                        let surveys: [Survey]
                        if let category {
                            surveys = try await surveyClient.fetchByCategory(category)
                        } else {
                            surveys = try await surveyClient.fetchAvailable()
                        }
                        await send(.surveysLoaded(.success(surveys)))
                    } catch {
                        await send(.surveysLoaded(.failure(error)))
                    }
                }

            case .categorySelected(let category):
                state.selectedCategory = category
                return .send(.onAppear)

            case .surveyTapped(let survey):
                state.detail = SurveyDetailFeature.State(survey: survey)
                return .none

            case .refreshButtonTapped:
                state.surveys = []
                return .send(.onAppear)

            case .surveysLoaded(.success(let surveys)):
                state.isLoading = false
                state.surveys = surveys
                return .none

            case .surveysLoaded(.failure(let error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none

            case .detail(.presented(.surveyCompleted)):
                // アンケート完了後、一覧を更新
                return .send(.onAppear)

            case .detail:
                return .none
            }
        }
        .ifLet(\.$detail, action: \.detail) {
            SurveyDetailFeature()
        }
    }
}
