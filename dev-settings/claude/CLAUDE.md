# CLAUDE.md

## Primary Directive

- Think in English, interact with the user in Japanese.
- The following text will be written in Japanese so that the user can easily understand it.

## 開発者プロフィール

開発スタイル: 「とりあえずコード書いてみる」タイプ（探索的開発）
TDD実践度: がっつりTDD派 - 実装前にテスト作成を徹底し、Red、Green、Blueの各段階に分けてコミット
アーキテクチャ哲学: フロントエンドはPackage by Featuresパターンを、バックエンドはオニオンアーキテクチャなどのレイヤー境界の分離を重視

## 技術スタック & 設定

### 主要言語とフレームワーク

- フロントエンド: TypeScript (React, Astro, Qwik)
- バックエンド: Go (net/http, Echo), PHP (Laravel, Slim Framework), Rust
- 補助言語: Python (uv)
- データベース: MySQL, PostgreSQL, SQLite
- ツール: Docker, npm (nvmでNode.js管理), Vite, Vitest, Playwright

### パッケージ管理

- JavaScript/TypeScript: npm
- Python: uv
- Rust: cargo
- PHP: composer

## アーキテクチャパターン

### フロントエンド

フロントエンドはPackage by Featuresパターンでの構成を基本とします。

```txt
src/
├── features/
│   ├── auth/          # 認証関連ロジック
│   ├── users/         # ユーザー関連ロジック
│   └── ...
├── components/        # 純粋なUIコンポーネント
├── hooks/            # 共通フック
└── shared/           # 共通ロジック (ApiClient, CookieClient等)
```

プロジェクトによって、sharedやfeaturesの責務は調整してください。

### バックエンド

GoやRustの場合はオニオンアーキテクチャをベースに構成します。

```txt
internal/ (Go) または src/ (Rust)
├── application/      # アプリケーション層
│   ├── dtos/         # DTO
│   ├── errors/       # アプリケーション固有のエラー
│   └── services/     # アプリケーションサービス
├── domain/           # ドメイン層
│   ├── entities/     # ドメインオブジェクト
│   ├── repositories/ # 抽象型でリポジトリを定義
│   └── services/     # ドメインサービス
├── infrastructure/   # インフラ層
│   ├── configs/      # アプリケーション設定
│   ├── database/     # DB接続
│   ├── env/          # 環境変数管理
│   └── persistence/  # リポジトリの実装
├── presentation/     # プレゼンテーション層
│   ├── handlers/     # ハンドラー
│   ├── middlewares/  # ミドルウェア
│   └── routes/       # ルーティング設定
└── registry/         # DIコンテナ
```

ただ、規模が大きくなるとフラットなオニオンアーキテクチャはコードの凝集度が高くなる可能性もあるので、Package by Featuresパターンと組み合わせることも検討してください。

注意: フルスタックフレームワークの場合:

Laravelなどのフルスタックフレームワークを使用する場合は、オニオンアーキテクチャではなく、フレームワークの標準的な構成（MVC + Service層など）に従います。

```txt
app/ (Laravel の例)
├── Http/
│   ├── Controllers/  # コントローラー
│   ├── Middleware/   # ミドルウェア
│   └── Requests/     # フォームリクエスト
├── Models/           # Eloquent モデル
├── Services/         # ビジネスロジック層
└── Repositories/     # リポジトリ層（必要に応じて）
```

フレームワークの思想や慣習を尊重し、そのエコシステムの利点を最大限活用することを優先します。

## コーディング規約

### 命名とコメント

- コミットメッセージ: 日本語 + Conventional Commits準拠。ただし、UTF-8サポートのテキストのみを使用すること。
- コメント: 基本的に日本語で記述。
- エラーメッセージ: 指定がない限り英語（ユーザー向け・デバッグ用共に）
- ドキュメント: TSDocやGodocなど各言語で用意された機能で関数・クラスの説明を必ず記述

OSS開発の際はコミットメッセージやコメントも英語が推奨されますので、ユーザーに確認を取ることをお勧めします。

### ファイル構成とネーミング

- テストファイル:
  - TypeScript: `*.test.ts` (同階層) - `describe()`/`test()`で階層化
  - Go: `*_test.go` (同階層) - `t.Run()`で階層化
  - Rust: ユニットテスト（同ファイル内）+ 結合テスト（`tests/`以下） - `mod`/`#[test]`で階層化
  - PHP: PHPUnitの場合は慣習に従い、フラットな`test*`メソッド構造と`dataProvider`によるエッジケースの提供
- テスト構造: 原則としてTest Object Pattern + 階層的構造を推奨。ただし、フレームワーク・テストツールの標準スタイル（例: PHPUnitのフラット構造）がある場合はそれに従う
- テスト名: 日本語で仕様を自然言語として表現

### インデント設定

- 言語標準に準拠: 各言語のデフォルト設定を使用

## テスト戦略 & TDD実践

### テスト哲学: デトロイト派重視

- 基本方針: モックの使用は極力避け、実際のオブジェクトとの協調を重視
- モック使用判断: 外部システム（API、ファイルI/O、ネットワーク）との境界でのみ使用
- 内部協調: ドメインオブジェクト同士の協調は実際のインスタンスでテスト
- テスト対象: 行動（behavior）をテストし、実装の詳細ではなく結果を検証

### Evergreenテストの原則

テストは時間が経っても価値を保ち続ける「evergreen」な内容に焦点を当てる：

- 実装詳細ではなく振る舞いをテスト: 内部実装が変わってもテストが壊れないように、公開インターフェースと結果を検証
- ビジネスルールに焦点: 技術的な詳細ではなく、ビジネス上重要な振る舞いや制約をテスト
- 仕様を表現: テストコードそのものが仕様書として機能し、将来の開発者が理解できる内容に
- 不変の要件を優先: 変更されやすい実装の詳細よりも、長期的に変わらないビジネスルールを優先してテスト

#### 例: Evergreenなテスト vs 避けるべきテスト

Good: Evergreenなテスト:

```go
t.Run("注文金額が10000円以上の場合、送料が無料になる", func(t *testing.T) {
    // このテストはビジネスルール（送料無料の条件）を検証
    // 内部の計算ロジックが変わってもこの仕様は変わらない
})
```

Bad: 避けるべきテスト:

```go
t.Run("calculateShippingFee関数がsubtractメソッドを呼び出す", func(t *testing.T) {
    // このテストは実装の詳細に依存しており、リファクタリングで壊れやすい
})
```

### 構造化テスト設計（テスト兼ドキュメント）

#### テスト設計原則

- **Living Documentation**: テストコードそのものが仕様書として機能
- 階層的構造: `t.Run()`を使った論理的なテスト階層（Goの場合）。ただし、フレームワーク・テストツールが異なるスタイルを推奨する場合（例: PHPUnitのフラット構造）はそれに従う
- 日本語テスト名: 仕様を自然言語で表現
- **Test Object Pattern**: テストに必要なデータと設定を構造体で管理

#### 構造化テストパターン（ミニマム構成）

```go
package domain_test

import (
    "testing"
    "myapp/internal/domain"
)

// Test Object Pattern - テストに必要なデータと設定を構造体で管理
type UserServiceTest struct {
    userService domain.UserService
    userRepo    domain.UserRepository // 実際のインメモリ実装を使用
}

func TestUserService(t *testing.T) {
    setup := func(t *testing.T) *UserServiceTest {
        t.Helper()
        userRepo := memory.NewUserRepository() // 実際のインメモリ実装
        return &UserServiceTest{
            userService: domain.NewUserService(userRepo),
            userRepo:    userRepo,
        }
    }

    test := setup(t)

    t.Run("ユーザー作成機能", func(t *testing.T) {
        t.Run("有効な名前でユーザーを作成できる", func(t *testing.T) {
            // 準備
            name := "太郎"
            
            // 実行
            user, err := test.userService.CreateUser(name)
            
            // 検証
            if err != nil {
                t.Errorf("エラーが発生しました: %v", err)
            }
            if user.Name() != name {
                t.Errorf("名前が期待値と異なります: got %q, want %q", user.Name(), name)
            }
        })

        t.Run("空の名前の場合はエラーが返る", func(t *testing.T) {
            // 実行
            _, err := test.userService.CreateUser("")
            
            // 検証
            if err == nil {
                t.Error("エラーが期待されましたが、発生しませんでした")
            }
        })
    })
}
```

### テストカバレッジ計画と定量指標

#### カバレッジ目標設定プロセス

実装開始前に必ずユーザーとカバレッジ目標を協議し、定量的な指標を設定します。

1. ヒアリング項目

    ```markdown
    ## テストカバレッジ目標設定

    ### プロジェクト情報
    - プロジェクト種別: [新規開発/機能追加/リファクタリング/バグ修正]
    - 重要度: [高/中/低]
    - リスクレベル: [高/中/低]

    ### カバレッジ目標
    - 行カバレッジ目標: ____%
    - 分岐カバレッジ目標: ____%
    - 関数カバレッジ目標: ____%

    ### 特別な考慮事項
    - 除外対象ファイル: [設定ファイル/自動生成コード等]
    - 重点テスト対象: [コアビジネスロジック/セキュリティ関連等]
    ```

2. プロジェクト種別別の推奨カバレッジ

    | プロジェクト種別 | 行カバレッジ | 分岐カバレッジ | 関数カバレッジ |
    |------------------|--------------|----------------|----------------|
    | 新規開発（高重要度） | 90%以上 | 85%以上 | 95%以上 |
    | 新規開発（中重要度） | 80%以上 | 75%以上 | 90%以上 |
    | 機能追加 | 85%以上 | 80%以上 | 90%以上 |
    | リファクタリング | 95%以上 | 90%以上 | 98%以上 |
    | バグ修正 | 100% | 100% | 100% |

### TDD TODOリスト（t_wada流）

#### 基本方針

- **Red**: 失敗するテストを書く
- **Green**: テストを通す最小限の実装
- **Refactor**: リファクタリング
- 小さなステップで進める
- 仮実装（ベタ書き）から始める
- 三角測量で一般化する
- 明白な実装が分かる場合は直接実装してもOK
- テストリストを常に更新する
- 不安なところからテストを書く

#### TDDワークフロー

1. **RED**: テスト作成 → 失敗確認
2. **GREEN**: 最小限の実装
3. **REFACTOR**: リファクタリング

### テスト範囲

- 優先度: ユニットテスト > 結合テスト > E2Eテスト
- モック: 外部システムとの境界でのみ使用（デトロイト派重視）
- 必須: 実装前にテスト作成、実装後にテスト実行・確認
- 構造化: テストオブジェクトパターンで階層的に記述（原則）。ただし、フレームワーク・テストツールの標準スタイルがある場合はそれに従う
- ドキュメント: テスト名と構造で仕様を表現
- カバレッジ: 実装前にユーザーと目標設定、定量的指標で品質保証

## リファクタリング & コード改善（Kent Beck's Tidyings）

### 境界づけられたコンテキスト: Tidyings vs Refactoring

Kent Beckが提唱するTidyingsの概念を取り入れ、リファクタリングの意味を明確に区別します。

#### Tidyings（整理整頓）

定義: 機会主義的で軽量な日常的コード改善

特徴:

- 機能実装やバグ修正の「ついで」に行う
- 5分以内で完了する小さな改善
- レビューで指摘されるような明らかな問題の修正
- リスクが低く、即座に実行可能
- テストは既存のもので十分（新規テスト不要）

#### Refactoring（リファクタリング）

定義: 計画的で構造的なコード変更

特徴:

- 事前計画が必要な大きな変更
- 設計パターンやアーキテクチャの変更
- 新しいテストケースの追加が必要
- リスクを伴う可能性があり、慎重な実施が必要
- 専用の時間枠を確保して実行

### 実践ガイドライン

#### Tidyingsの実践ルール

1. 2分ルール: 2分以内で完了しない場合はリファクタリングとして別途計画
2. テスト実行: tidying後は必ず既存テストを実行して動作確認
3. 即座実行: 気づいたらその場で実行（後回しにしない）
4. コミット分離: tidyingは独立したコミットにする

#### Refactoringの計画フロー

1. 現状分析: 変更が必要な理由と範囲を明確化
2. テスト充実: リファクタリング前にテストカバレッジを向上
3. 段階的実行: 小さなステップに分けて実行
4. 継続テスト: 各ステップでテスト実行を確認

### コミットメッセージの使い分け

```bash
# Tidyings
git commit -m "tidy: remove unnecessary else clause in getUserName"
git commit -m "tidy: fix variable name typo in validation"

# Refactoring  
git commit -m "refactor: extract user validation logic to domain service"
git commit -m "refactor: implement repository pattern for user persistence"
```

## ドキュメント構成

### プロジェクトドキュメント

- README.md: 概要、詳細説明、インストール/セットアップ手順
- ARCHITECTURE.md: アーキテクチャ図、コードマップ、API仕様

### ADR（Architecture Decision Records）管理

ADRを残すプロジェクトの場合、検索性向上のために以下を実施：

- ファイルパス記録: 作成・更新したファイルのプロジェクトルートからのパスを箇条書きで記述
- 変更ファイル例:

  ```markdown
  ## 影響を受けるファイル
  - `internal/domain/user.go`
  - `internal/application/services/user_service.go`
  - `internal/infrastructure/persistence/user_repository.go`
  - `docs/adrs/001-user-domain-design.md`
  ```

### 関数・クラスドキュメント

- TSDoc形式: `@param`, `@returns`, `@see`を活用
- 日本語: 実際にできることと参照先を明記

### Evergreenドキュメントの原則

ドキュメントは時間が経っても価値を保ち続ける「evergreen」な内容に焦点を当てる：

- WHYを記述: HOWやWHATではなく、「なぜそうしたのか」という意思決定の背景や理由を記述
- 設計思想と意図: 実装の詳細ではなく、アーキテクチャの意図や設計上の判断基準を記述
- 不変のビジネスルール: 頻繁に変わる実装の詳細ではなく、長期的に変わらないビジネスの制約や要件を記述
- トレードオフの記録: 採用した設計の利点だけでなく、何を犠牲にしたかも記録（ADRの活用）
- コンテキストの提供: 将来の開発者が正しく判断できるよう、決定時の状況や制約を記録
- コード自体で表現できることは書かない: コードを読めば分かることはドキュメント化せず、コードで表現できない意図や背景を記述

#### 例: Evergreenなドキュメント vs 避けるべきドキュメント

Good: Evergreenな例:

```go
// User はシステムの利用者を表すドメインオブジェクト。
// ユーザーの生成時には必ず有効な認証情報が必要であり、
// これはセキュリティポリシーで定められた不変のビジネスルール。
// 認証情報のない「仮ユーザー」は、セキュリティ監査の要件により許可されない。
type User struct { ... }
```

Bad: 避けるべき例:

```go
// User 構造体には name, email, password フィールドがある
// NewUser 関数で User を作成する
type User struct { ... }
```

## セキュリティ & 安全性

### 依存関係管理

- アプリケーション: バージョン固定（キャレットなし）
- ライブラリ: キャレット付きバージョン指定
- 更新方針: 動作する最新バージョンを使用

## Git Hooks推奨設定

### コミットメッセージのUTF-8検証

コミットメッセージは必ずUTF-8エンコーディングで記述する必要があります（既に規約として94行目に記載）。これを自動的に検証するため、`commit-msg`フックの設定を推奨します。

#### セットアップ手順

1. フックファイルの作成

   ```bash
   touch .git/hooks/commit-msg
   chmod +x .git/hooks/commit-msg
   ```

2. フック内容の記述

   `.git/hooks/commit-msg`に以下を記述：

   ```bash
   #!/bin/sh
   # UTF-8エンコーディング検証フック

   commit_msg_file=$1

   if ! iconv -f UTF-8 -t UTF-8 "$commit_msg_file" > /dev/null 2>&1; then
       echo "Error: Commit messages must be in UTF-8 encoding"
       exit 1
   fi
   ```

#### 動作

- UTF-8以外のエンコーディングでコミットメッセージを書いた場合、コミットが拒否されます
- 日本語を含むConventional Commitsメッセージも正しく処理されます

#### 注意事項

- このフックはローカル環境のみで機能します（`.git/hooks`はリポジトリに含まれない）
- チーム開発の場合は、READMEやセットアップドキュメントにフックの設定手順を記載することを推奨

## Claude Code協働ルール

### 必須事項 (YOU MUST)

- **YOU MUST**: 実装前にテストを作成し、実装後にテスト実行してパスを確認
- **YOU MUST**: Test Object Pattern を使い、階層的構造でテストを記述（原則）。ただし、フレームワーク・テストツールの標準スタイルがある場合はそれに従う（例: PHPUnitのフラット構造）
- **YOU MUST**: テスト名は日本語で仕様を表現し、Living Documentationとして機能させる
- **YOU MUST**: 実装開始前にユーザーとカバレッジ目標を協議し、定量的指標を設定
- **YOU MUST**: デトロイト派の思想に従い、極力モックの使用は避ける（外部システムとの境界でのみ使用）
- **YOU MUST**: TypeScriptの複雑な型にはTSDocコメントと使用例を追加
- **YOU MUST**: リポジトリパターンは必ずレイヤー間の依存関係を守る（例: GORMでUser構造体の振る舞いを永続化する`NewGormUserRepository()`は抽象型を返す）
- **YOU MUST**: エラーメッセージとログは英語で統一
- **YOU MUST**: Tidyingsは2分以内で完了するもののみその場で実行、それ以上はRefactoringとして計画する
- **YOU MUST**: ADRを残すプロジェクトでは、作成・更新したファイルのプロジェクトルートからのパスを箇条書きで記述
- **YOU MUST**: テストは実装詳細ではなくビジネスルールと振る舞いに焦点を当て、evergreen（長期的に価値のある）な内容にする
- **YOU MUST**: ドキュメントはWHY（意思決定の背景）を記述し、コードで表現できることは書かない（evergreen原則）

### 重要事項 (IMPORTANT)

- **IMPORTANT**: ビジネスロジックの実装前にユーザーと方針を擦り合わせ
- **IMPORTANT**: ドメインオブジェクトはAnemic Domain Modelにならないよう、データ構造とドメインロジックを実装する
- **IMPORTANT**: ドメインオブジェクトはgetter/setterパターンを排除して、オブジェクトの振る舞いとして実装（例: `Person.getName()` → `Person.name()`）
- **IMPORTANT**: オニオンアーキテクチャのレイヤー境界を厳守
- **IMPORTANT**: Featuresパターンでビジネス機能を適切に分離
- **IMPORTANT**: TidyingsとRefactoringを明確に区別し、適切なコミットメッセージを使用
- **IMPORTANT**: カバレッジ目標未達成時は実装完了とみなさず、テスト追加で目標達成を必須とする
- **IMPORTANT**: GitHubのリソース（PR、Issue、リリース、タグなど）にアクセスする際は、WebFetchが失敗した場合に`gh`コマンド（GitHub CLI）の利用可能性を確認し、存在すれば`gh`コマンドで再試行する。可能であれば、最初から`gh`コマンドを優先的に使用することを推奨

### 絶対禁止 (NEVER)

- **NEVER**: `rm -rf`等のシステム破壊コマンドを独断実行（必ずユーザー確認）
- **NEVER**: テストなしでの実装
- **NEVER**: オニオンアーキテクチャにおけるレイヤー間の直接依存（必ずinterfaceなどの抽象型を介す）
- **NEVER**: ハードコーディングでの機密情報埋め込み
- **NEVER**: TidyingsとRefactoringの境界を曖昧にする
- **NEVER**: 外部システム以外でのモック使用（デトロイト派重視）

### 実装パターン

#### オニオンアーキテクチャ実装時

```go
// Good: 正しい例
import (
    "myapp/internal/domain/repository"
)

type gormUserRepository struct {
  db *gorm.DB
}

func NewGormUserRepository(db *gorm.DB) repository.UserRepository {
    return &gormUserRepository{db: db}
}
```

```go
// Bad: 避けるべき例
type GormUserRepository struct {
  db *gorm.DB
}

func NewGormUserRepository(db *gorm.DB) *GormUserRepository {
    return &GormUserRepository{db: db}
}
```

#### ドメインオブジェクトの振る舞い（Rich Domain Objects重視）

```go
// Good: 推奨（Rich Domain Objects）
func (p Person) name() string { return p.name }

// Bad: 避ける（Anemic Domain Model）
func (p Person) getName() string { return p.name }
```

---

## ワークフローのポイント

このメモリ設定により、Claude Codeは以下を自動的に：

- t_wada流TDD重視の開発フロー（デトロイト派思想）
- オニオンアーキテクチャの厳格な実装
- 適切な日本語コメント付与
- テスト必須の実装サイクル
- セキュリティを意識した慎重な操作
- Kent BeckのTidyings概念に基づく適切なコード改善の判断
- ADRプロジェクトでの検索性向上
- Evergreenな原則に基づく長期的に価値のあるテストとドキュメントの作成

**品質 > 速度** の哲学で、持続可能で保守性の高いコードを一緒に作りましょう！
