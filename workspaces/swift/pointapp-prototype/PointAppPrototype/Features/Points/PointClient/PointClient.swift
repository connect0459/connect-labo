import ComposableArchitecture
import Foundation

/// ポイントClient
/// 外部境界（API/DB）を抽象化
struct PointClient {
    var getBalance: @Sendable () async throws -> PointBalance
    var getTransactionHistory: @Sendable (Int?) async throws -> [PointTransaction]
    var addPoints: @Sendable (PointAmount, TransactionReason) async throws -> Void
}

extension PointClient: DependencyKey {
    /// 本番実装（プロトタイプではインメモリ）
    static let liveValue = PointClient(
        getBalance: {
            try await Task.sleep(for: .milliseconds(300))
            return .sample
        },
        getTransactionHistory: { limit in
            try await Task.sleep(for: .milliseconds(300))
            if let limit {
                return Array(PointTransaction.samples.prefix(limit))
            }
            return PointTransaction.samples
        },
        addPoints: { _, _ in
            try await Task.sleep(for: .milliseconds(200))
        }
    )

    /// プレビュー用
    static let previewValue = PointClient(
        getBalance: { .sample },
        getTransactionHistory: { _ in PointTransaction.samples },
        addPoints: { _, _ in }
    )

    /// テスト用
    static let testValue = PointClient(
        getBalance: unimplemented("PointClient.getBalance"),
        getTransactionHistory: unimplemented("PointClient.getTransactionHistory"),
        addPoints: unimplemented("PointClient.addPoints")
    )
}

extension DependencyValues {
    var pointClient: PointClient {
        get { self[PointClient.self] }
        set { self[PointClient.self] = newValue }
    }
}
