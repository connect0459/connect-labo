import Foundation

/// ポイント取引ID
struct PointTransactionID: Hashable, Sendable {
    let value: String

    init(_ value: String = UUID().uuidString) {
        self.value = value
    }
}

/// ポイント取引を表すドメインオブジェクト
struct PointTransaction: Identifiable, Sendable, Equatable {
    let id: PointTransactionID
    let type: TransactionType
    let amount: PointAmount
    let reason: TransactionReason
    let createdAt: Date
    let status: TransactionStatus

    /// 取引が獲得か消費かを判定
    var isEarning: Bool {
        type == .earn
    }

    /// 表示用の符号付き金額
    var signedAmount: Int {
        isEarning ? amount.value : -amount.value
    }

    /// 表示用の符号付き文字列
    var signedAmountString: String {
        isEarning ? "+\(amount.value)pt" : "-\(amount.value)pt"
    }
}

/// 取引タイプ
enum TransactionType: String, Sendable {
    case earn = "獲得"
    case spend = "使用"
}

/// 取引理由
enum TransactionReason: Sendable, Equatable {
    case surveyCompletion(surveyId: String)
    case dailyLogin
    case streakBonus(days: Int)
    case achievementUnlock(achievementId: String)
    case exchange(destination: String)
    case expiration
    case other(description: String)

    var displayText: String {
        switch self {
        case .surveyCompletion:
            return "アンケート回答"
        case .dailyLogin:
            return "デイリーログイン"
        case .streakBonus(let days):
            return "\(days)日連続ログインボーナス"
        case .achievementUnlock:
            return "アチーブメント達成"
        case .exchange(let destination):
            return "\(destination)へ交換"
        case .expiration:
            return "ポイント期限切れ"
        case .other(let description):
            return description
        }
    }

    var iconName: String {
        switch self {
        case .surveyCompletion:
            return "doc.text.fill"
        case .dailyLogin:
            return "calendar"
        case .streakBonus:
            return "flame.fill"
        case .achievementUnlock:
            return "star.fill"
        case .exchange:
            return "arrow.right.arrow.left"
        case .expiration:
            return "clock.badge.xmark"
        case .other:
            return "circle.fill"
        }
    }
}

/// 取引ステータス
enum TransactionStatus: String, Sendable {
    case pending = "処理中"
    case completed = "完了"
    case cancelled = "キャンセル"
}

// MARK: - Sample Data

extension PointTransaction {
    static let samples: [PointTransaction] = [
        PointTransaction(
            id: PointTransactionID(),
            type: .earn,
            amount: try! PointAmount(150),
            reason: .surveyCompletion(surveyId: "survey-1"),
            createdAt: Date().addingTimeInterval(-3600),
            status: .completed
        ),
        PointTransaction(
            id: PointTransactionID(),
            type: .earn,
            amount: try! PointAmount(10),
            reason: .dailyLogin,
            createdAt: Date().addingTimeInterval(-86400),
            status: .completed
        ),
        PointTransaction(
            id: PointTransactionID(),
            type: .earn,
            amount: try! PointAmount(50),
            reason: .streakBonus(days: 7),
            createdAt: Date().addingTimeInterval(-86400 * 2),
            status: .completed
        ),
        PointTransaction(
            id: PointTransactionID(),
            type: .spend,
            amount: try! PointAmount(500),
            reason: .exchange(destination: "Amazonギフト券"),
            createdAt: Date().addingTimeInterval(-86400 * 7),
            status: .completed
        )
    ]
}
