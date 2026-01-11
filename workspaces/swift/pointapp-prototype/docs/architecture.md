# PointApp Prototype アーキテクチャ設計書

## 1. 概要

ECナビアンケートアプリをベースに、より良いユーザー体験を提供するポイ活アプリのプロトタイプ。

### 1.1 設計哲学

本プロジェクトでは以下の設計哲学を採用する：

- **TDD重視**: デトロイト派（モック最小化、実際のオブジェクト協調）
- **Evergreen原則**: 実装詳細ではなく振る舞いをテスト、長期的に価値を保つ
- **Rich Domain Objects**: データ + ロジックを凝集、getter/setter排除
- **単方向データフロー**: TCAによる予測可能な状態管理
- **品質 > 速度**: 持続可能性と保守性を優先

### 1.2 技術スタック

| 項目 | 技術 |
|------|------|
| 言語 | Swift 5.9+ |
| UI | SwiftUI |
| アーキテクチャ | **TCA (The Composable Architecture)** |
| テスト | XCTest + TCA TestStore (TDD) |
| 最小OS | iOS 17.0 |
| パッケージ管理 | Swift Package Manager |

### 1.3 TCAを選択した理由

| 理由 | 説明 |
|------|------|
| **単方向データフロー** | 状態の変化が予測可能で、デバッグが容易 |
| **高いテスタビリティ** | Reducerは純粋関数、TestStoreで振る舞いをテスト |
| **デトロイト派との親和性** | Dependencyで副作用を分離、内部ロジックは実オブジェクトでテスト |
| **コンポーザビリティ** | 機能を小さなReducerに分割し、組み合わせ可能 |
| **Evergreen原則との相性** | ActionとStateで仕様を表現、実装詳細から分離 |

## 2. TCA基本概念

### 2.1 単方向データフロー

```
┌─────────────────────────────────────────────────────┐
│                                                     │
│    ┌───────┐   Action   ┌─────────┐   State    ┌──────┐
│    │ View  │ ─────────▶ │ Reducer │ ─────────▶ │ View │
│    └───────┘            └─────────┘            └──────┘
│        ▲                     │
│        │                     │ Effect
│        │                     ▼
│        │              ┌─────────────┐
│        └───────────── │ Environment │
│           Action      │ (API, DB)   │
│                       └─────────────┘
│                                                     │
└─────────────────────────────────────────────────────┘
```

### 2.2 主要コンポーネント

| コンポーネント | 役割 | TDD観点 |
|---------------|------|---------|
| **State** | アプリの状態を表す不変の値型 | テストで期待状態を検証 |
| **Action** | ユーザー操作やシステムイベント | テストでActionを送信 |
| **Reducer** | StateとActionから新Stateを生成 | 純粋関数なのでテスト容易 |
| **Effect** | 副作用（API、タイマー等） | Dependencyで注入、テスト時はモック |
| **Dependency** | 外部依存の注入 | デトロイト派: 外部境界のみモック |

## 3. ディレクトリ構造

```
PointAppPrototype/
├── App/
│   └── PointAppPrototypeApp.swift    # エントリーポイント
│
├── Features/
│   ├── Survey/                       # アンケート機能
│   │   ├── Domain/
│   │   │   └── Models/               # ドメインモデル（Rich Domain Objects）
│   │   │       ├── Survey.swift
│   │   │       ├── SurveyQuestion.swift
│   │   │       └── SurveyAnswer.swift
│   │   ├── SurveyList/               # アンケート一覧Feature
│   │   │   ├── SurveyListFeature.swift    # State, Action, Reducer
│   │   │   └── SurveyListView.swift       # SwiftUI View
│   │   ├── SurveyDetail/             # アンケート詳細Feature
│   │   │   ├── SurveyDetailFeature.swift
│   │   │   └── SurveyDetailView.swift
│   │   └── SurveyClient/             # 外部依存（API）
│   │       └── SurveyClient.swift
│   │
│   ├── Points/                       # ポイント機能
│   │   ├── Domain/
│   │   │   └── Models/
│   │   │       ├── PointBalance.swift
│   │   │       └── PointTransaction.swift
│   │   ├── PointDashboard/           # ポイントダッシュボードFeature
│   │   │   ├── PointDashboardFeature.swift
│   │   │   └── PointDashboardView.swift
│   │   ├── PointHistory/             # ポイント履歴Feature
│   │   │   ├── PointHistoryFeature.swift
│   │   │   └── PointHistoryView.swift
│   │   └── PointClient/
│   │       └── PointClient.swift
│   │
│   ├── Gamification/                 # ゲーミフィケーション機能
│   │   ├── Domain/
│   │   │   └── Models/
│   │   │       ├── DailyMission.swift
│   │   │       ├── Streak.swift
│   │   │       └── Achievement.swift
│   │   ├── DailyMission/
│   │   │   ├── DailyMissionFeature.swift
│   │   │   └── DailyMissionView.swift
│   │   ├── StreakFeature/
│   │   │   ├── StreakFeature.swift
│   │   │   └── StreakView.swift
│   │   └── GamificationClient/
│   │       └── GamificationClient.swift
│   │
│   └── App/                          # アプリ全体Feature
│       ├── AppFeature.swift          # ルートReducer
│       └── AppView.swift             # ルートView（TabView）
│
├── Shared/
│   ├── Domain/
│   │   └── Models/
│   │       └── ValueObjects/
│   │           └── PointAmount.swift
│   ├── Dependencies/                 # 共通Dependency
│   │   ├── StorageClient.swift
│   │   └── DateClient.swift
│   └── UI/
│       ├── Components/               # 共通UIコンポーネント
│       │   ├── PointBadge.swift
│       │   └── ProgressCard.swift
│       └── Theme/
│           └── AppTheme.swift
│
└── Tests/
    └── PointAppPrototypeTests/
        ├── Features/
        │   ├── Survey/
        │   │   ├── Domain/
        │   │   │   └── SurveyTests.swift
        │   │   └── SurveyListFeatureTests.swift
        │   └── Points/
        │       ├── Domain/
        │       │   └── PointBalanceTests.swift
        │       └── PointDashboardFeatureTests.swift
        └── Shared/
            └── Domain/
                └── PointAmountTests.swift
```

## 4. TCA Feature設計

### 4.1 基本構造

```swift
import ComposableArchitecture

@Reducer
struct SurveyListFeature {
    // MARK: - State
    @ObservableState
    struct State: Equatable {
        var surveys: [Survey] = []
        var isLoading = false
        var selectedCategory: SurveyCategory?
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
                state.isLoading = true
                return .run { send in
                    await send(.surveysLoaded(
                        Result { try await surveyClient.fetchAvailable() }
                    ))
                }

            case .categorySelected(let category):
                state.selectedCategory = category
                return .send(.onAppear)

            case .surveyTapped(let survey):
                state.detail = SurveyDetailFeature.State(survey: survey)
                return .none

            case .refreshButtonTapped:
                return .send(.onAppear)

            case .surveysLoaded(.success(let surveys)):
                state.isLoading = false
                state.surveys = surveys
                return .none

            case .surveysLoaded(.failure):
                state.isLoading = false
                return .none

            case .detail:
                return .none
            }
        }
        .ifLet(\.$detail, action: \.detail) {
            SurveyDetailFeature()
        }
    }
}
```

### 4.2 View実装

```swift
import ComposableArchitecture
import SwiftUI

struct SurveyListView: View {
    @Bindable var store: StoreOf<SurveyListFeature>

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.surveys) { survey in
                    SurveyRow(survey: survey)
                        .onTapGesture {
                            store.send(.surveyTapped(survey))
                        }
                }
            }
            .navigationTitle("アンケート一覧")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.send(.refreshButtonTapped)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .overlay {
                if store.isLoading {
                    ProgressView()
                }
            }
        }
        .sheet(item: $store.scope(state: \.detail, action: \.detail)) { store in
            SurveyDetailView(store: store)
        }
        .task {
            store.send(.onAppear)
        }
    }
}
```

## 5. Dependency設計（デトロイト派）

### 5.1 Clientプロトコル

```swift
import ComposableArchitecture

/// アンケートClient
/// 外部境界（API/DB）を抽象化
struct SurveyClient {
    var fetchAvailable: @Sendable () async throws -> [Survey]
    var fetchByCategory: @Sendable (SurveyCategory) async throws -> [Survey]
    var findById: @Sendable (SurveyID) async throws -> Survey?
    var submitAnswer: @Sendable (SurveyID, [SurveyAnswer]) async throws -> PointAmount
}

extension SurveyClient: DependencyKey {
    /// 本番実装
    static let liveValue = SurveyClient(
        fetchAvailable: {
            // API呼び出し
            try await APIClient.shared.fetch("/surveys/available")
        },
        fetchByCategory: { category in
            try await APIClient.shared.fetch("/surveys?category=\(category.rawValue)")
        },
        findById: { id in
            try await APIClient.shared.fetch("/surveys/\(id.value)")
        },
        submitAnswer: { surveyId, answers in
            try await APIClient.shared.post("/surveys/\(surveyId.value)/answer", body: answers)
        }
    )

    /// プレビュー/プロトタイプ用（インメモリ）
    static let previewValue = SurveyClient(
        fetchAvailable: {
            try await Task.sleep(for: .milliseconds(500))
            return Survey.samples
        },
        fetchByCategory: { _ in Survey.samples },
        findById: { id in Survey.samples.first { $0.id == id } },
        submitAnswer: { _, _ in try! PointAmount(100) }
    )

    /// テスト用（デフォルトは未実装でクラッシュ）
    static let testValue = SurveyClient(
        fetchAvailable: unimplemented("SurveyClient.fetchAvailable"),
        fetchByCategory: unimplemented("SurveyClient.fetchByCategory"),
        findById: unimplemented("SurveyClient.findById"),
        submitAnswer: unimplemented("SurveyClient.submitAnswer")
    )
}

extension DependencyValues {
    var surveyClient: SurveyClient {
        get { self[SurveyClient.self] }
        set { self[SurveyClient.self] = newValue }
    }
}
```

### 5.2 デトロイト派の適用

```swift
// ✅ Good: ドメインロジックは実オブジェクトでテスト
func test_アンケートの報酬効率を計算できる() throws {
    let survey = Survey(
        id: SurveyID(),
        title: "テスト",
        reward: try PointAmount(100),
        estimatedMinutes: 5,
        // ...
    )

    XCTAssertEqual(survey.rewardEfficiency(), 20.0)
}

// ✅ Good: 外部境界（Client）はモック/スタブ
@MainActor
func test_アンケート一覧を読み込める() async {
    let store = TestStore(
        initialState: SurveyListFeature.State()
    ) {
        SurveyListFeature()
    } withDependencies: {
        $0.surveyClient.fetchAvailable = { Survey.samples }
    }

    await store.send(.onAppear) {
        $0.isLoading = true
    }

    await store.receive(\.surveysLoaded.success) {
        $0.isLoading = false
        $0.surveys = Survey.samples
    }
}
```

## 6. テスト戦略（TCA + TDD）

### 6.1 テストの種類

| テスト種類 | 対象 | ツール | モック |
|-----------|------|--------|--------|
| **ドメインテスト** | Rich Domain Objects | XCTest | なし |
| **Reducerテスト** | State遷移、Effect | TestStore | Dependency |
| **統合テスト** | Feature間の連携 | TestStore | 最小限 |

### 6.2 TestStoreの使い方

```swift
import ComposableArchitecture
import XCTest

final class SurveyListFeatureTests: XCTestCase {

    @MainActor
    func test_アンケート一覧を表示できる() async {
        // Arrange
        let expectedSurveys = [
            Survey.fixture(title: "アンケート1"),
            Survey.fixture(title: "アンケート2")
        ]

        let store = TestStore(
            initialState: SurveyListFeature.State()
        ) {
            SurveyListFeature()
        } withDependencies: {
            // 外部境界のみモック（デトロイト派）
            $0.surveyClient.fetchAvailable = { expectedSurveys }
        }

        // Act & Assert
        await store.send(.onAppear) {
            $0.isLoading = true
        }

        await store.receive(\.surveysLoaded.success) {
            $0.isLoading = false
            $0.surveys = expectedSurveys
        }
    }

    @MainActor
    func test_アンケートをタップすると詳細画面に遷移する() async {
        let survey = Survey.fixture()

        let store = TestStore(
            initialState: SurveyListFeature.State(surveys: [survey])
        ) {
            SurveyListFeature()
        }

        await store.send(.surveyTapped(survey)) {
            $0.detail = SurveyDetailFeature.State(survey: survey)
        }
    }

    @MainActor
    func test_カテゴリ選択でフィルタリングされる() async {
        let store = TestStore(
            initialState: SurveyListFeature.State()
        ) {
            SurveyListFeature()
        } withDependencies: {
            $0.surveyClient.fetchAvailable = { [] }
        }

        await store.send(.categorySelected(.product)) {
            $0.selectedCategory = .product
        }

        await store.receive(\.onAppear)
        // ...
    }
}
```

### 6.3 Evergreenテストの例

```swift
// ✅ Evergreen: ビジネスルール（振る舞い）をテスト
func test_アンケート回答完了時にポイントが付与される() async {
    let earnedPoints = try! PointAmount(150)

    let store = TestStore(
        initialState: SurveyDetailFeature.State(
            survey: Survey.fixture(reward: earnedPoints)
        )
    ) {
        SurveyDetailFeature()
    } withDependencies: {
        $0.surveyClient.submitAnswer = { _, _ in earnedPoints }
        $0.pointClient.addPoints = { _, _ in }
    }

    await store.send(.submitButtonTapped) {
        $0.isSubmitting = true
    }

    await store.receive(\.submitCompleted.success) {
        $0.isSubmitting = false
        $0.earnedPoints = earnedPoints
    }
}

// ❌ Fragile: 実装詳細をテスト
func test_APIが正しいエンドポイントを呼ぶ() async {
    // これは実装が変わると壊れる
}
```

## 7. ドメインモデル設計

### 7.1 Rich Domain Objects

TCAを使っても、ドメインモデルはRich Domain Objectsとして設計する。

```swift
/// アンケートを表すドメインオブジェクト
struct Survey: Identifiable, Equatable, Sendable {
    let id: SurveyID
    let title: String
    let description: String
    let questions: [SurveyQuestion]
    let reward: PointAmount
    let estimatedMinutes: Int
    let expiresAt: Date
    let category: SurveyCategory

    /// アンケートが回答可能かどうか
    func isAvailable(at date: Date = .now) -> Bool {
        date < expiresAt
    }

    /// 報酬効率（ポイント/分）を計算
    func rewardEfficiency() -> Double {
        guard estimatedMinutes > 0 else { return 0 }
        return Double(reward.value) / Double(estimatedMinutes)
    }

    /// 回答の妥当性を検証
    func validateAnswers(_ answers: [SurveyAnswer]) -> Result<Void, SurveyError> {
        guard answers.count == questions.count else {
            return .failure(.incompleteAnswers)
        }
        // ...
        return .success(())
    }
}
```

### 7.2 値オブジェクト

```swift
/// ポイント金額を表す値オブジェクト
struct PointAmount: Equatable, Comparable, Sendable {
    let value: Int

    init(_ value: Int) throws {
        guard value >= 0 else {
            throw PointAmountError.negativeValue
        }
        self.value = value
    }

    func toYen() -> Decimal {
        Decimal(value) / 10
    }

    func adding(_ other: PointAmount) -> PointAmount {
        try! PointAmount(value + other.value)
    }

    static let zero = try! PointAmount(0)
}
```

## 8. Feature一覧

### 8.1 MVP機能

| Feature | State | 主なAction |
|---------|-------|-----------|
| **SurveyList** | surveys, isLoading, selectedCategory | onAppear, categorySelected, surveyTapped |
| **SurveyDetail** | survey, answers, isSubmitting | answerChanged, submitButtonTapped |
| **PointDashboard** | balance, isLoading | onAppear, refreshTapped |
| **PointHistory** | transactions, isLoading | onAppear, loadMore |

### 8.2 追加機能（Phase 2）

| Feature | 説明 |
|---------|------|
| **DailyMission** | 今日のミッション一覧と進捗 |
| **Streak** | 連続ログイン表示 |
| **Achievement** | アチーブメント一覧 |

## 9. Package.swift

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PointAppPrototype",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "PointAppPrototype", targets: ["PointAppPrototype"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            from: "1.15.0"
        )
    ],
    targets: [
        .target(
            name: "PointAppPrototype",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]
        ),
        .testTarget(
            name: "PointAppPrototypeTests",
            dependencies: ["PointAppPrototype"]
        )
    ]
)
```

## 10. 参考資料

- [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture)
- [Point-Free TCA Episodes](https://www.pointfree.co/collections/composable-architecture)
- [CLAUDE.md](../../dev-settings/claude/CLAUDE.md) - 開発哲学
- [TDD ワークフロー](../../dev-settings/claude/agent-docs/testing/tdd-workflow.md)
- [ECナビアンケートアプリ調査レポート](./research-ecnavi-survey-app.md)
