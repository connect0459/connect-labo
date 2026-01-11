# PointApp Prototype

ECナビアンケートアプリをベースにした、より良いユーザー体験を提供するポイ活アプリのプロトタイプ。

## 技術スタック

| 項目 | 技術 |
|------|------|
| 言語 | Swift 5.9+ |
| UI | SwiftUI |
| アーキテクチャ | TCA (The Composable Architecture) |
| テスト | Swift Testing + XCTest |
| 最小OS | iOS 17.0 |

## 設計哲学

- **TDD重視**: t-wada流TDD、デトロイト派（モック最小化）
- **Evergreen原則**: 実装詳細ではなく振る舞いをテスト
- **Rich Domain Objects**: データ + ロジックを凝集
- **単方向データフロー**: TCAによる予測可能な状態管理

## ディレクトリ構成

```
├── Sources/
│   ├── PointAppDomain/          # ドメイン層（Pure Swift）
│   │   ├── PointAmount.swift    # ポイント値オブジェクト
│   │   └── Survey.swift         # アンケートエンティティ
│   └── PointAppPrototype/       # アプリ層（SwiftUI + TCA）
│       └── ...
├── Tests/
│   ├── PointAppDomainTests/     # ドメインテスト
│   └── PointAppPrototypeTests/  # Featureテスト
├── docs/
│   ├── architecture.md          # アーキテクチャ設計書
│   ├── testing-strategy.md      # テスト戦略
│   └── research-ecnavi-survey-app.md  # 調査レポート
└── Package.swift
```

## テスト実行

### Swift Testing（CLIから）

```bash
# 全テスト実行
swift test

# ドメインテストのみ
swift test --filter PointAppDomainTests

# 特定のテストスイート
swift test --filter PointAmountTests
swift test --filter SurveyTests
```

### Xcodeから

1. `Package.swift`をXcodeで開く
2. `Cmd + U`でテスト実行

## TDDワークフロー

### Red-Green-Refactor サイクル

```
┌─────┐     ┌───────┐     ┌────────┐
│ Red │ ──▶ │ Green │ ──▶ │Refactor│
└─────┘     └───────┘     └────────┘
    ▲                          │
    └──────────────────────────┘
```

1. **Red**: 失敗するテストを書く
2. **Green**: テストを通す最小限の実装
3. **Refactor**: テストが通る状態を維持しながらリファクタリング

### テストの書き方（Swift Testing）

```swift
import Testing
@testable import PointAppDomain

@Suite("PointAmount - ポイント金額の値オブジェクト")
struct PointAmountTests {

    @Test("正の値でPointAmountを作成できる")
    func 正の値で作成できる() throws {
        // Arrange（準備）
        // なし

        // Act（実行）
        let points = try PointAmount(100)

        // Assert（検証）
        #expect(points.value == 100)
    }

    @Test("負の値の場合はエラー")
    func 負の値はエラー() {
        #expect(throws: PointAmountError.negativeValue) {
            try PointAmount(-1)
        }
    }
}
```

## ドメインモデル

### PointAmount（値オブジェクト）

```swift
let points = try PointAmount(100)
points.value          // 100
points.toYen()        // 10 (Decimal)
points.toYenString()  // "10円"
points.adding(other)  // 加算
```

### Survey（エンティティ）

```swift
let survey = Survey(
    title: "商品アンケート",
    reward: try PointAmount(150),
    estimatedMinutes: 5,
    expiresAt: Date().addingTimeInterval(86400)
)

survey.isAvailable()      // 期限内か？
survey.rewardEfficiency() // 30.0 (pt/分)
survey.isHighEfficiency() // true (20pt/分以上)
survey.remainingTime()    // 残り時間（秒）
```

## 参考資料

- [TCAアーキテクチャ設計書](docs/architecture.md)
- [テスト戦略](docs/testing-strategy.md)
- [ECナビアンケートアプリ調査](docs/research-ecnavi-survey-app.md)
- [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture)
