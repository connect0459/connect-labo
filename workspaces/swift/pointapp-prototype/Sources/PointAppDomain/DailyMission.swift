import Foundation

// MARK: - MissionID

/// ミッションの識別子
public struct MissionID: Equatable, Hashable, Sendable {
    public let value: String

    public init(_ value: String = UUID().uuidString) {
        self.value = value
    }
}

// MARK: - DailyMission

/// デイリーミッションを表すドメインオブジェクト
/// ビジネスルール: 毎日リセットされるミッションを達成するとボーナスポイント獲得
public struct DailyMission: Identifiable, Equatable, Sendable {
    public let id: MissionID
    public let title: String
    public let description: String
    public let requiredCount: Int
    public let reward: PointAmount
    public private(set) var currentProgress: Int

    public init(
        id: MissionID = MissionID(),
        title: String,
        description: String = "",
        requiredCount: Int,
        reward: PointAmount
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.requiredCount = requiredCount
        self.reward = reward
        self.currentProgress = 0
    }

    // MARK: - ビジネスロジック

    /// ミッションが完了しているかどうか
    public var isCompleted: Bool {
        currentProgress >= requiredCount
    }

    /// 進捗を1つ進める
    public mutating func incrementProgress() {
        guard !isCompleted else { return }
        currentProgress += 1
    }

    /// 進捗率（0.0〜1.0）
    public func progressPercentage() -> Double {
        guard requiredCount > 0 else { return 0.0 }
        return Double(currentProgress) / Double(requiredCount)
    }

    /// 残り回数
    public func remainingCount() -> Int {
        max(0, requiredCount - currentProgress)
    }

    /// 進捗をリセット
    public mutating func reset() {
        currentProgress = 0
    }
}

// MARK: - DailyMissionTracker

/// デイリーミッションの追跡を管理
public struct DailyMissionTracker: Equatable, Sendable {
    public private(set) var missions: [DailyMission]

    public init() {
        self.missions = []
    }

    /// ミッションを追加
    public mutating func addMission(_ mission: DailyMission) {
        missions.append(mission)
    }

    /// 全ミッションが完了しているか
    public func allCompleted() -> Bool {
        guard !missions.isEmpty else { return false }
        return missions.allSatisfy { $0.isCompleted }
    }

    /// 完了したミッションの合計報酬
    public func completedReward() -> PointAmount {
        let total = missions
            .filter { $0.isCompleted }
            .reduce(0) { $0 + $1.reward.value }
        return try! PointAmount(total)
    }

    /// 全ミッションの進捗をリセット
    public mutating func reset() {
        for i in missions.indices {
            missions[i].reset()
        }
    }
}
