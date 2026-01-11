import Testing
@testable import PointAppDomain

/// DailyMission（デイリーミッション）のテスト
/// ビジネスルール: 毎日リセットされるミッションを達成するとボーナスポイント獲得
@Suite("DailyMission Tests")
struct DailyMissionTests {

    // MARK: - ミッション生成

    @Test("ミッションを作成できる")
    func createMission() throws {
        // Act
        let mission = DailyMission(
            id: MissionID("mission-1"),
            title: "アンケートに3回答える",
            description: "今日中にアンケートに3回答えよう",
            requiredCount: 3,
            reward: try PointAmount(50)
        )

        // Assert
        #expect(mission.title == "アンケートに3回答える")
        #expect(mission.requiredCount == 3)
        #expect(mission.reward.value == 50)
    }

    @Test("初期状態では進捗は0")
    func initialProgressIsZero() throws {
        // Arrange
        let mission = try createTestMission(requiredCount: 3)

        // Assert
        #expect(mission.currentProgress == 0)
    }

    @Test("初期状態では未完了")
    func initiallyNotCompleted() throws {
        // Arrange
        let mission = try createTestMission(requiredCount: 3)

        // Assert
        #expect(!mission.isCompleted)
    }

    // MARK: - 進捗更新

    @Test("進捗を更新できる")
    func incrementProgress() throws {
        // Arrange
        var mission = try createTestMission(requiredCount: 3)

        // Act
        mission.incrementProgress()

        // Assert
        #expect(mission.currentProgress == 1)
    }

    @Test("進捗が目標に達すると完了になる")
    func completedWhenTargetReached() throws {
        // Arrange
        var mission = try createTestMission(requiredCount: 3)

        // Act
        mission.incrementProgress()
        mission.incrementProgress()
        mission.incrementProgress()

        // Assert
        #expect(mission.isCompleted)
    }

    @Test("目標を超えて進捗しても目標値で止まる")
    func progressCapsAtTarget() throws {
        // Arrange
        var mission = try createTestMission(requiredCount: 2)

        // Act
        mission.incrementProgress()
        mission.incrementProgress()
        mission.incrementProgress()
        mission.incrementProgress()

        // Assert
        #expect(mission.currentProgress == 2)
    }

    // MARK: - 進捗率

    @Test("進捗率を計算できる")
    func calculateProgressPercentage() throws {
        // Arrange
        var mission = try createTestMission(requiredCount: 4)
        mission.incrementProgress()
        mission.incrementProgress()

        // Act
        let progress = mission.progressPercentage()

        // Assert
        #expect(progress == 0.5)
    }

    @Test("進捗0の場合の進捗率は0")
    func zeroProgressPercentage() throws {
        // Arrange
        let mission = try createTestMission(requiredCount: 3)

        // Act
        let progress = mission.progressPercentage()

        // Assert
        #expect(progress == 0.0)
    }

    @Test("完了時の進捗率は1")
    func completedProgressPercentageIsOne() throws {
        // Arrange
        var mission = try createTestMission(requiredCount: 2)
        mission.incrementProgress()
        mission.incrementProgress()

        // Act
        let progress = mission.progressPercentage()

        // Assert
        #expect(progress == 1.0)
    }

    // MARK: - 残り回数

    @Test("残り回数を取得できる")
    func getRemainingCount() throws {
        // Arrange
        var mission = try createTestMission(requiredCount: 5)
        mission.incrementProgress()
        mission.incrementProgress()

        // Act
        let remaining = mission.remainingCount()

        // Assert
        #expect(remaining == 3)
    }

    @Test("完了時の残り回数は0")
    func completedRemainingCountIsZero() throws {
        // Arrange
        var mission = try createTestMission(requiredCount: 2)
        mission.incrementProgress()
        mission.incrementProgress()

        // Act
        let remaining = mission.remainingCount()

        // Assert
        #expect(remaining == 0)
    }

    // MARK: - Helper

    private func createTestMission(requiredCount: Int) throws -> DailyMission {
        DailyMission(
            id: MissionID(),
            title: "テストミッション",
            description: "テスト用の説明",
            requiredCount: requiredCount,
            reward: try PointAmount(30)
        )
    }
}

// MARK: - DailyMissionTracker Tests

/// デイリーミッションの追跡を管理するテスト
@Suite("DailyMissionTracker Tests")
struct DailyMissionTrackerTests {

    @Test("空のトラッカーを作成できる")
    func createEmptyTracker() {
        // Arrange & Act
        let tracker = DailyMissionTracker()

        // Assert
        #expect(tracker.missions.count == 0)
    }

    @Test("ミッションを追加できる")
    func addMission() throws {
        // Arrange
        var tracker = DailyMissionTracker()
        let mission = DailyMission(
            id: MissionID("m1"),
            title: "アンケートに答える",
            description: "",
            requiredCount: 3,
            reward: try PointAmount(30)
        )

        // Act
        tracker.addMission(mission)

        // Assert
        #expect(tracker.missions.count == 1)
    }

    @Test("全ミッション完了を判定できる")
    func allMissionsCompleted() throws {
        // Arrange
        var tracker = DailyMissionTracker()
        var mission1 = DailyMission(
            id: MissionID("m1"),
            title: "ミッション1",
            description: "",
            requiredCount: 1,
            reward: try PointAmount(10)
        )
        var mission2 = DailyMission(
            id: MissionID("m2"),
            title: "ミッション2",
            description: "",
            requiredCount: 1,
            reward: try PointAmount(10)
        )

        mission1.incrementProgress()
        mission2.incrementProgress()

        tracker.addMission(mission1)
        tracker.addMission(mission2)

        // Assert
        #expect(tracker.allCompleted())
    }

    @Test("未完了ミッションがあれば全完了ではない")
    func notAllCompletedWhenSomePending() throws {
        // Arrange
        var tracker = DailyMissionTracker()
        var mission1 = DailyMission(
            id: MissionID("m1"),
            title: "ミッション1",
            description: "",
            requiredCount: 1,
            reward: try PointAmount(10)
        )
        let mission2 = DailyMission(
            id: MissionID("m2"),
            title: "ミッション2",
            description: "",
            requiredCount: 1,
            reward: try PointAmount(10)
        )

        mission1.incrementProgress()
        // mission2は未完了

        tracker.addMission(mission1)
        tracker.addMission(mission2)

        // Assert
        #expect(!tracker.allCompleted())
    }

    @Test("完了ミッションの合計報酬を取得できる")
    func getCompletedReward() throws {
        // Arrange
        var tracker = DailyMissionTracker()
        var mission1 = DailyMission(
            id: MissionID("m1"),
            title: "ミッション1",
            description: "",
            requiredCount: 1,
            reward: try PointAmount(20)
        )
        var mission2 = DailyMission(
            id: MissionID("m2"),
            title: "ミッション2",
            description: "",
            requiredCount: 1,
            reward: try PointAmount(30)
        )
        let mission3 = DailyMission(
            id: MissionID("m3"),
            title: "ミッション3",
            description: "",
            requiredCount: 2,
            reward: try PointAmount(50)
        )

        mission1.incrementProgress()
        mission2.incrementProgress()
        // mission3は未完了

        tracker.addMission(mission1)
        tracker.addMission(mission2)
        tracker.addMission(mission3)

        // Act
        let totalReward = tracker.completedReward()

        // Assert
        #expect(totalReward.value == 50) // 20 + 30
    }

    @Test("リセットで全ミッションの進捗がクリアされる")
    func resetClearsProgress() throws {
        // Arrange
        var tracker = DailyMissionTracker()
        var mission = DailyMission(
            id: MissionID("m1"),
            title: "ミッション",
            description: "",
            requiredCount: 2,
            reward: try PointAmount(30)
        )
        mission.incrementProgress()
        tracker.addMission(mission)

        // Act
        tracker.reset()

        // Assert
        #expect(tracker.missions.first?.currentProgress == 0)
    }
}
