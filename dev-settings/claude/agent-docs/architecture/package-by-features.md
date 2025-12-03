# Package by Features パターン

## 概要

フロントエンド開発では、Package by Featuresパターンでの構成を基本とします。
機能（feature）ごとにコードを整理し、関連するロジックを凝集させます。

## 基本構造

```text
src/
├── features/
│   ├── auth/          # 認証関連ロジック
│   │   ├── components/
│   │   ├── hooks/
│   │   ├── stores/
│   │   └── types/
│   ├── users/         # ユーザー関連ロジック
│   │   ├── components/
│   │   ├── hooks/
│   │   ├── stores/
│   │   └── types/
│   └── products/      # 製品関連ロジック
│       ├── components/
│       ├── hooks/
│       ├── stores/
│       └── types/
├── components/        # 純粋なUIコンポーネント（共通）
├── hooks/            # 共通フック
└── shared/           # 共通ロジック
    ├── api/          # ApiClient
    ├── storage/      # CookieClient, LocalStorage等
    └── utils/        # ユーティリティ関数
```

## レイヤー責務の調整

プロジェクトによって、`shared/` や `features/` の責務は調整してください。

### 小規模プロジェクト

```text
src/
├── features/
│   └── auth/
├── components/       # すべての共通コンポーネント
└── lib/             # すべての共通ロジック
```

### 中規模プロジェクト（推奨）

```text
src/
├── features/        # 機能ごとの凝集
├── components/      # 純粋なUIコンポーネント
├── hooks/          # 共通フック
└── shared/         # 共通ロジック
```

### 大規模プロジェクト

```text
src/
├── features/
│   └── users/
│       ├── domain/          # ドメインロジック
│       ├── application/     # ユースケース
│       ├── infrastructure/  # API通信等
│       └── presentation/    # コンポーネント
├── components/
└── shared/
```

## 特徴（Feature）の分け方

### 良い分け方

- **ビジネスドメインに基づく**: `users/`, `orders/`, `products/`
- **ユーザーのタスクに基づく**: `checkout/`, `search/`, `dashboard/`

### 避けるべき分け方

- **技術的な分類**: `forms/`, `modals/`, `tables/`（これらは `components/` へ）
- **小さすぎる分割**: 1-2コンポーネントしかない feature

## 依存関係ルール

```text
Features → Shared
```

- **Features間の依存は避ける**: feature同士は独立させる
- **Shared層への依存はOK**: 共通ロジックは `shared/` に配置
- **Componentsへの依存はOK**: 純粋なUIコンポーネントは共通化

## 実践ガイドライン

### Feature内の構成例

```text
features/users/
├── components/
│   ├── UserList.tsx
│   ├── UserDetail.tsx
│   └── UserForm.tsx
├── hooks/
│   ├── useUserList.ts
│   └── useUserForm.ts
├── stores/
│   └── userStore.ts
├── types/
│   └── user.ts
└── index.ts          # Public API
```

### Public API パターン

各featureは `index.ts` でエクスポートを制限し、カプセル化を保ちます。

```typescript
// features/users/index.ts
export { UserList } from './components/UserList'
export { useUserList } from './hooks/useUserList'
export type { User } from './types/user'

// 内部実装は公開しない
```

## フレームワークとの組み合わせ

### React (Vite)

推奨: Package by Features

### Astro

推奨: `src/features/` + `src/components/`（Astroコンポーネント）

### Qwik

推奨: `src/features/` + `src/components/`（Qwikコンポーネント）

## Package by Features + オニオンアーキテクチャ

大規模なフロントエンドでは、feature内でオニオンアーキテクチャを採用することも検討できます。
詳細は `agent-docs/architecture/onion-architecture.md` を参照してください。
