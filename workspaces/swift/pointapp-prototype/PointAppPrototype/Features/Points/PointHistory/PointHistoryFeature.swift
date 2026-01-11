import ComposableArchitecture
import Foundation

/// ポイント履歴Feature
@Reducer
struct PointHistoryFeature {
    // MARK: - State

    @ObservableState
    struct State: Equatable, Identifiable {
        let id = UUID()
        var transactions: [PointTransaction] = []
        var isLoading = false
        var hasMore = true
    }

    // MARK: - Action

    enum Action {
        case onAppear
        case loadMore
        case transactionsLoaded(Result<[PointTransaction], Error>)
    }

    // MARK: - Dependencies

    @Dependency(\.pointClient) var pointClient

    // MARK: - Reducer

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.transactions.isEmpty else { return .none }
                state.isLoading = true

                return .run { send in
                    do {
                        let transactions = try await pointClient.getTransactionHistory(nil)
                        await send(.transactionsLoaded(.success(transactions)))
                    } catch {
                        await send(.transactionsLoaded(.failure(error)))
                    }
                }

            case .loadMore:
                // プロトタイプでは追加読み込みは未実装
                return .none

            case .transactionsLoaded(.success(let transactions)):
                state.isLoading = false
                state.transactions = transactions
                state.hasMore = false
                return .none

            case .transactionsLoaded(.failure):
                state.isLoading = false
                return .none
            }
        }
    }
}
