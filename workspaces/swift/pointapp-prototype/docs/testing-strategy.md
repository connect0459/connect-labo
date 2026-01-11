# テスト戦略ドキュメント

## 1. 概要

本プロジェクトでは、t-wada流TDDとデトロイト派の思想に基づいたテスト駆動開発を採用する。

### 1.1 基本方針

| 原則 | 説明 |
|------|------|
| **TDD** | Red → Green → Refactor サイクル |
| **デトロイト派** | モックは外部境界のみ、内部は実オブジェクト |
| **Evergreen** | 実装詳細ではなく振る舞いをテスト |
| **Living Documentation** | 日本語テスト名で仕様を表現 |

## 2. TDDワークフロー

### 2.1 Red-Green-Refactor サイクル

```
┌─────────────────────────────────────────┐
│                                         │
│    ┌─────┐     ┌───────┐     ┌────────┐│
│    │ Red │ ──▶ │ Green │ ──▶ │Refactor││
│    └─────┘     └───────┘     └────────┘│
│        ▲                          │     │
│        └──────────────────────────┘     │
│                                         │
└─────────────────────────────────────────┘
```

1. **Red**: 失敗するテストを書く（まだ実装がない）
2. **Green**: テストを通す最小限の実装を書く
3. **Refactor**: テストが通る状態を維持しながらリファクタリング

### 2.2 TDDの心得

- **小さなステップで進める**: 一度に多くを実装しない
- **仮実装（ベタ書き）から始める**: まず動くコードを書く
- **三角測量で一般化する**: 複数のテストケースから共通ロジックを抽出
- **明白な実装が分かる場合は直接実装してもOK**
- **テストリストを常に更新する**: 思いついたテストケースをメモ
- **不安なところからテストを書く**: 最もリスクの高い部分から始める

### 2.3 TODOリスト駆動開発

実装前に、必要なテストケースをリストアップする。

```markdown
## PointAmount（値オブジェクト）TODO

- [x] 正の値でPointAmountを作成できる
- [x] 0でPointAmountを作成できる
- [x] 負の値の場合はエラー
- [x] 2つのPointAmountを加算できる
- [x] 円換算（10pt = 1円）ができる
- [ ] 2つのPointAmountを比較できる
```

### 2.4 TODOの優先順位

1. **ハッピーパス**: 正常系のテストから始める
2. **エッジケース**: 境界値のテスト
3. **異常系**: エラーケースのテスト

## 3. デトロイト派のテスト哲学

### 3.1 基本方針

```
┌─────────────────────────────────────────────────────┐
│                    テスト対象                        │
│  ┌─────────────────────────────────────────────┐   │
│  │              Domain Layer                    │   │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐     │   │
│  │  │ Survey  │──│ Point   │──│ User    │     │   │
│  │  └─────────┘  └─────────┘  └─────────┘     │   │
│  │         実オブジェクトで協調テスト            │   │
│  └─────────────────────────────────────────────┘   │
│                        │                            │
│                        ▼                            │
│  ┌─────────────────────────────────────────────┐   │
│  │           Infrastructure Layer               │   │
│  │  ┌─────────────┐    ┌─────────────┐         │   │
│  │  │ API Client  │    │ Database    │         │   │
│  │  └─────────────┘    └─────────────┘         │   │
│  │         ここだけモック/スタブを使用           │   │
│  └─────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

### 3.2 モック使用の判断基準

| 使用する場合 | 使用しない場合 |
|--------------|----------------|
| API通信 | ドメインオブジェクト間の協調 |
| データベース接続 | 値オブジェクト |
| ファイルI/O | ユースケース内のロジック |
| 外部サービス | ViewModel |

### 3.3 良い例・悪い例

```swift
// Good: 実際のインメモリリポジトリを使用
func test_アンケート回答でポイントが付与される() async throws {
    // Arrange
    let surveyRepo = InMemorySurveyRepository()
    let pointRepo = InMemoryPointRepository()
    let useCase = AnswerSurveyUseCase(
        surveyRepository: surveyRepo,
        pointRepository: pointRepo
    )

    let survey = Survey.fixture(reward: try PointAmount(100))
    surveyRepo.save(survey)

    // Act
    try await useCase.execute(surveyId: survey.id, answers: [...])

    // Assert
    let balance = try await pointRepo.getBalance()
    XCTAssertEqual(balance.total.value, 100)
}

// Bad: 不必要なモック
func test_アンケート回答でポイントが付与される_BAD() async throws {
    let mockSurveyRepo = MockSurveyRepository()
    let mockPointRepo = MockPointRepository()

    mockSurveyRepo.findByIdReturnValue = Survey.fixture()
    mockPointRepo.addPointsExpectation = expectation(description: "addPoints called")

    // ... テストコード ...

    // モックの検証（実装詳細に依存）
    XCTAssertTrue(mockPointRepo.addPointsCalled)
}
```

## 4. Evergreenテスト設計

### 4.1 基本原則

Evergreenテストとは、時間が経っても価値を保ち続けるテストのこと。

| 原則 | 説明 |
|------|------|
| **振る舞いをテスト** | 実装詳細ではなく、期待される振る舞いを検証 |
| **ビジネスルールに焦点** | 技術的な詳細ではなく、ビジネス上重要な振る舞い |
| **仕様を表現** | テストコードそのものが仕様書として機能 |
| **不変の要件を優先** | 長期的に変わらないビジネスルールを優先 |

### 4.2 良いテストと悪いテストの比較

```swift
// ✅ Evergreen: 振る舞いをテスト
func test_10000円以上の購入で送料が無料になる() {
    let order = Order(items: [
        OrderItem(price: try! PointAmount(100000)) // 10000円相当
    ])

    XCTAssertTrue(order.isFreeShipping())
}

// ❌ Fragile: 実装詳細をテスト
func test_ShippingCalculatorのcalculateメソッドが正しく呼ばれる() {
    let mockCalculator = MockShippingCalculator()
    // ... 実装が変わると壊れる
}
```

### 4.3 テスト名の命名規則

テスト名は日本語で仕様を表現する。

```swift
// Good: 仕様が明確
func test_期限切れのアンケートは回答できない() { }
func test_ポイント残高が不足している場合は交換できない() { }
func test_連続7日ログインでボーナスポイントが付与される() { }

// Bad: 何をテストしているか不明
func testSurvey1() { }
func testValidation() { }
func testCalculate() { }
```

## 5. Test Object Pattern

### 5.1 基本構造

```swift
import XCTest
@testable import PointAppPrototype

final class PointBalanceTests: XCTestCase {

    // MARK: - Test Context

    /// テストに必要なオブジェクトをまとめた構造体
    struct TestContext {
        let pointRepository: InMemoryPointRepository
        let earnPointsUseCase: EarnPointsUseCase

        init() {
            pointRepository = InMemoryPointRepository()
            earnPointsUseCase = EarnPointsUseCase(repository: pointRepository)
        }

        /// 初期ポイントを設定するヘルパー
        func setInitialBalance(_ amount: Int) throws {
            let points = try PointAmount(amount)
            pointRepository.setBalance(PointBalance(total: points))
        }
    }

    private func makeContext() -> TestContext {
        TestContext()
    }

    // MARK: - ポイント獲得機能

    func test_アンケート回答でポイントを獲得できる() async throws {
        // Arrange
        let context = makeContext()
        let reward = try PointAmount(100)

        // Act
        try await context.earnPointsUseCase.execute(
            amount: reward,
            reason: .surveyCompletion(surveyId: "survey-1")
        )

        // Assert
        let balance = try await context.pointRepository.getBalance()
        XCTAssertEqual(balance.total.value, 100)
    }

    func test_複数回のポイント獲得が累積される() async throws {
        // Arrange
        let context = makeContext()
        try context.setInitialBalance(500)

        // Act
        try await context.earnPointsUseCase.execute(
            amount: try PointAmount(100),
            reason: .surveyCompletion(surveyId: "survey-1")
        )

        // Assert
        let balance = try await context.pointRepository.getBalance()
        XCTAssertEqual(balance.total.value, 600)
    }

    // MARK: - ポイント残高表示機能

    func test_ポイント残高を円換算で表示できる() throws {
        // Arrange
        let balance = PointBalance(total: try PointAmount(1000))

        // Act
        let yenAmount = balance.total.toYen()

        // Assert
        XCTAssertEqual(yenAmount, 100) // 1000pt = 100円
    }
}
```

### 5.2 テストフィクスチャ

```swift
// Domain/Models/Survey+Fixture.swift (テストターゲットのみ)
extension Survey {
    /// テスト用のフィクスチャを生成
    static func fixture(
        id: SurveyID = SurveyID(),
        title: String = "テストアンケート",
        questions: [SurveyQuestion] = [],
        reward: PointAmount = try! PointAmount(100),
        estimatedMinutes: Int = 5,
        expiresAt: Date = Date().addingTimeInterval(86400)
    ) -> Survey {
        Survey(
            id: id,
            title: title,
            questions: questions,
            reward: reward,
            estimatedMinutes: estimatedMinutes,
            expiresAt: expiresAt
        )
    }
}
```

## 6. AAA パターン

各テストは以下の3段階で構成する：

```swift
func test_期限内のアンケートは回答可能() throws {
    // ===== Arrange（準備）=====
    let futureDate = Date().addingTimeInterval(86400) // 24時間後
    let survey = Survey.fixture(expiresAt: futureDate)

    // ===== Act（実行）=====
    let isAvailable = survey.isAvailable()

    // ===== Assert（検証）=====
    XCTAssertTrue(isAvailable)
}
```

## 7. テストカバレッジ目標

### 7.1 レイヤー別目標

| レイヤー | カバレッジ目標 | 理由 |
|----------|---------------|------|
| **Domain** | 90%以上 | ビジネスロジックの中核 |
| **Application** | 80%以上 | ユースケースのフロー |
| **Infrastructure** | 60%以上 | 外部依存、統合テストで補完 |
| **Presentation** | 50%以上 | UIロジック、手動テストで補完 |

### 7.2 カバレッジ測定

```bash
# Xcodeでカバレッジを有効化してテスト実行
xcodebuild test \
  -scheme PointAppPrototype \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -enableCodeCoverage YES
```

## 8. テストの優先度

```
Unit Tests > Integration Tests > E2E Tests
   高速         中速            低速
   多数         適度            少数
```

### 8.1 テストピラミッド

```
        /\
       /  \     E2E Tests (少数)
      /    \    - 重要なユーザーフロー
     /------\
    /        \  Integration Tests (適度)
   /          \ - Repository + UseCase
  /------------\
 /              \ Unit Tests (多数)
/                \- Domain Models, Value Objects
------------------
```

## 9. 実践チェックリスト

### 実装前

- [ ] テストリスト（TODO）を作成したか
- [ ] カバレッジ目標を設定したか
- [ ] 最初のテスト（Red）を書いたか

### 実装中

- [ ] 小さなステップで進めているか
- [ ] テストが通ったらすぐRefactorしているか
- [ ] モックは外部境界のみか

### 実装後

- [ ] すべてのテストが通るか
- [ ] カバレッジ目標を達成したか
- [ ] テスト名が仕様を表現しているか
- [ ] 実装詳細ではなく振る舞いをテストしているか

## 10. 参考資料

- [TDD ワークフロー](../../dev-settings/claude/agent-docs/testing/tdd-workflow.md)
- [Test Object Pattern](../../dev-settings/claude/agent-docs/testing/test-object-pattern.md)
- [カバレッジ目標](../../dev-settings/claude/agent-docs/testing/coverage-goals.md)
- t-wada『テスト駆動開発』
