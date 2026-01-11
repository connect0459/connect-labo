import ComposableArchitecture
import Foundation

/// アプリ全体のルートFeature
@Reducer
struct AppFeature {
    // MARK: - State

    @ObservableState
    struct State: Equatable {
        var selectedTab: Tab = .home
        var surveyList = SurveyListFeature.State()
        var pointDashboard = PointDashboardFeature.State()

        enum Tab: Hashable {
            case home
            case surveys
            case points
            case missions
        }
    }

    // MARK: - Action

    enum Action {
        case tabSelected(State.Tab)
        case surveyList(SurveyListFeature.Action)
        case pointDashboard(PointDashboardFeature.Action)
    }

    // MARK: - Reducer

    var body: some ReducerOf<Self> {
        Scope(state: \.surveyList, action: \.surveyList) {
            SurveyListFeature()
        }

        Scope(state: \.pointDashboard, action: \.pointDashboard) {
            PointDashboardFeature()
        }

        Reduce { state, action in
            switch action {
            case .tabSelected(let tab):
                state.selectedTab = tab
                return .none

            case .surveyList:
                return .none

            case .pointDashboard:
                return .none
            }
        }
    }
}
