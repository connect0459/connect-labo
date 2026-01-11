import ComposableArchitecture
import SwiftUI

/// ポイントダッシュボードView
struct PointDashboardView: View {
    @Bindable var store: StoreOf<PointDashboardFeature>

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // ポイント残高カード
                    balanceCard

                    // 期限切れアラート
                    if let expiring = store.balance?.expiringPoints,
                       expiring.isExpiringSoon() {
                        expirationAlert(expiring)
                    }

                    // 最近の取引
                    recentTransactionsSection
                }
                .padding()
            }
            .navigationTitle("ポイント")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if store.isLoading {
                        ProgressView()
                    } else {
                        Button {
                            store.send(.refreshTapped)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
        }
        .sheet(item: $store.scope(state: \.history, action: \.history)) { store in
            PointHistoryView(store: store)
        }
        .task {
            store.send(.onAppear)
        }
    }

    // MARK: - Balance Card

    private var balanceCard: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("ポイント残高")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let balance = store.balance {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(balance.total.value)")
                            .font(.system(size: 48, weight: .bold))
                            .contentTransition(.numericText())

                        Text("pt")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }

                    Text("≈ \(balance.total.toYenString())")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                        .frame(height: 60)
                }
            }

            Divider()

            // 内訳
            if let balance = store.balance {
                HStack {
                    VStack(alignment: .leading) {
                        Text("利用可能")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(balance.availablePoints.value)pt")
                            .font(.headline)
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text("処理中")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(balance.pendingPoints.value)pt")
                            .font(.headline)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }

    // MARK: - Expiration Alert

    private func expirationAlert(_ expiring: ExpiringPoints) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            VStack(alignment: .leading) {
                Text("\(expiring.amount.value)ptが\(expiring.daysUntilExpiration())日後に失効")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("お早めにご利用ください")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Recent Transactions

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近の履歴")
                    .font(.headline)

                Spacer()

                Button("すべて見る") {
                    store.send(.showHistoryTapped)
                }
                .font(.caption)
            }

            if store.recentTransactions.isEmpty {
                Text("履歴がありません")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(store.recentTransactions) { transaction in
                    TransactionRow(transaction: transaction)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}

// MARK: - Transaction Row

struct TransactionRow: View {
    let transaction: PointTransaction

    var body: some View {
        HStack {
            Image(systemName: transaction.reason.iconName)
                .foregroundStyle(transaction.isEarning ? .green : .red)
                .frame(width: 32)

            VStack(alignment: .leading) {
                Text(transaction.reason.displayText)
                    .font(.subheadline)

                Text(transaction.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(transaction.signedAmountString)
                .font(.headline)
                .foregroundStyle(transaction.isEarning ? .green : .red)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview

#Preview {
    PointDashboardView(
        store: Store(
            initialState: PointDashboardFeature.State(
                balance: .sample,
                recentTransactions: PointTransaction.samples
            )
        ) {
            PointDashboardFeature()
        } withDependencies: {
            $0.pointClient = .previewValue
        }
    )
}
