# オニオンアーキテクチャ実装ガイド

## 概要

GoやRustでのバックエンド開発では、オニオンアーキテクチャをベースに構成します。
レイヤー間の依存関係を厳格に管理し、ドメイン層を中心とした設計を行います。

## ディレクトリ構造

### Go プロジェクト

```text
internal/
├── application/      # アプリケーション層
│   ├── dtos/         # DTO (Data Transfer Objects)
│   ├── errors/       # アプリケーション固有のエラー
│   └── services/     # アプリケーションサービス
├── domain/           # ドメイン層（コア）
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

### Rust プロジェクト

```text
src/
├── application/      # アプリケーション層
├── domain/           # ドメイン層
├── infrastructure/   # インフラ層
├── presentation/     # プレゼンテーション層
└── registry/         # DIコンテナ
```

## レイヤー間の依存関係ルール

### 依存方向

```text
Presentation → Application → Domain ← Infrastructure
```

- **ドメイン層**: 他のレイヤーに依存しない（最も内側）
- **アプリケーション層**: ドメイン層のみに依存
- **インフラ層**: ドメイン層の抽象型を実装（依存性逆転）
- **プレゼンテーション層**: アプリケーション層に依存

### 重要原則

1. **依存性逆転の原則**: インフラ層はドメイン層で定義されたinterfaceを実装
2. **抽象型経由**: レイヤー間の通信は必ず抽象型（interface）を介す
3. **Rich Domain Objects**: ドメイン層にビジネスロジックを集約

## リポジトリパターンの実装

詳細な実装例は `agent_docs/examples/repository-pattern.md` を参照してください。

### 基本方針

```go
// domain/repositories/user_repository.go（抽象型定義）
package repositories

type UserRepository interface {
    FindByID(id string) (*entities.User, error)
    Save(user *entities.User) error
}
```

```go
// infrastructure/persistence/user_repository.go（実装）
package persistence

import "myapp/internal/domain/repositories"

type gormUserRepository struct {
    db *gorm.DB
}

// 戻り値は抽象型（interface）
func NewGormUserRepository(db *gorm.DB) repositories.UserRepository {
    return &gormUserRepository{db: db}
}
```

## スケールを考慮した構成

規模が大きくなるとフラットなオニオンアーキテクチャはコードの凝集度が低下する可能性があります。
その場合、Package by Featuresパターンと組み合わせることを検討してください。

```text
internal/
├── features/
│   ├── users/
│   │   ├── domain/
│   │   ├── application/
│   │   ├── infrastructure/
│   │   └── presentation/
│   └── orders/
│       ├── domain/
│       ├── application/
│       ├── infrastructure/
│       └── presentation/
└── shared/
    └── domain/
```

## フルスタックフレームワークの扱い

Laravelなどのフルスタックフレームワークを使用する場合は、オニオンアーキテクチャではなく、
**フレームワークの標準的な構成（MVC + Service層など）に従います**。

```text
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
