import ComposableArchitecture
import Foundation

/// ポイントダッシュボードFeature
@Reducer
struct PointDashboardFeature {
    // MARK: - State

    @ObservableState
    struct State: Equatable {
        var balance: PointBalance?
        var recentTransactions: [PointTransaction] = []
        var isLoading = false
        var errorMessage: String?
        @Presents var history: PointHistoryFeature.State?
    }

    // MARK: - Action

    enum Action {
        case onAppear
        case refreshTapped
        case showHistoryTapped

        // 内部
        case balanceLoaded(Result<PointBalance, Error>)
        case transactionsLoaded(Result<[PointTransaction], Error>)

        // 子Feature
        case history(PresentationAction<PointHistoryFeature.Action>)
    }

    // MARK: - Dependencies

    @Dependency(\.pointClient) var pointClient

    // MARK: - Reducer

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.isLoading else { return .none }
                state.isLoading = true
                state.errorMessage = nil

                return .merge(
                    .run { send in
                        do {
                            let balance = try await pointClient.getBalance()
                            await send(.balanceLoaded(.success(balance)))
                        } catch {
                            await send(.balanceLoaded(.failure(error)))
                        }
                    },
                    .run { send in
                        do {
                            let transactions = try await pointClient.getTransactionHistory(5)
                            await send(.transactionsLoaded(.success(transactions)))
                        } catch {
                            await send(.transactionsLoaded(.failure(error)))
                        }
                    }
                )

            case .refreshTapped:
                state.balance = nil
                state.recentTransactions = []
                return .send(.onAppear)

            case .showHistoryTapped:
                state.history = PointHistoryFeature.State()
                return .none

            case .balanceLoaded(.success(let balance)):
                state.isLoading = false
                state.balance = balance
                return .none

            case .balanceLoaded(.failure(let error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none

            case .transactionsLoaded(.success(let transactions)):
                state.recentTransactions = transactions
                return .none

            case .transactionsLoaded(.failure):
                return .none

            case .history:
                return .none
            }
        }
        .ifLet(\.$history, action: \.history) {
            PointHistoryFeature()
        }
    }
}
