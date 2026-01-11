import ComposableArchitecture
import SwiftUI

/// ポイント履歴View
struct PointHistoryView: View {
    let store: StoreOf<PointHistoryFeature>

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.transactions) { transaction in
                    TransactionRow(transaction: transaction)
                }

                if store.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            }
            .navigationTitle("ポイント履歴")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            store.send(.onAppear)
        }
    }
}

// MARK: - Preview

#Preview {
    PointHistoryView(
        store: Store(
            initialState: PointHistoryFeature.State(
                transactions: PointTransaction.samples
            )
        ) {
            PointHistoryFeature()
        }
    )
}
