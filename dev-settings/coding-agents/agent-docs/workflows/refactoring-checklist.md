# リファクタリングチェックリスト

## 概要

リファクタリングとリネーム作業では、**全参照を一度に完全に更新**することで、複数回の修正ラウンドを回避し、効率的に作業を進めます。

## 基本原則

### 1. 実装前にチェックリストを作成

コード変更を行う前に、**変更対象の完全なリストを作成**し、ユーザーの承認を得ます。

❌ **避けるべき**:

1. とりあえず主要なファイルを変更
2. テストが失敗
3. 追加の変更対象を発見
4. 再度修正
5. また別の変更漏れを発見...

✅ **推奨**:

1. 全変更対象をリストアップ
2. ユーザーに提示して承認を得る
3. 一度にすべてを変更
4. テスト実行

### 2. 検索を徹底する

変更対象を見落とさないため、複数の検索手段を組み合わせます。

```bash
# ファイル名検索
find . -name "*OldName*"

# コード内検索
grep -r "OldName" --include="*.ts" --include="*.tsx"

# 大文字小文字を区別しない検索
grep -ri "oldname"

# 特定の拡張子を対象
rg "OldName" -t typescript -t tsx
```

## リファクタリング種別別チェックリスト

### コンポーネント/クラス/関数のリネーム

#### リネームの検索対象

- [ ] **ファイル名**: `OldName.tsx`, `OldName.ts`
- [ ] **import文**: `import { OldName } from ...`
- [ ] **export文**: `export { OldName }`
- [ ] **型定義**: `type OldName = ...`, `interface OldName { ... }`
- [ ] **使用箇所**: `<OldName />`, `new OldName()`, `OldName()`
- [ ] **テストファイル**: `OldName.test.tsx`, `OldName.spec.ts`
- [ ] **テストケース内**: `describe('OldName', ...)`
- [ ] **Storybook**: `OldName.stories.tsx`, `title: 'OldName'`
- [ ] **コメント・ドキュメント**: JSDoc, README等
- [ ] **型アサーション**: `as OldName`, `: OldName`

#### リネームの検索コマンド例

```bash
# ファイル名
find . -name "*OldName*" -not -path "*/node_modules/*"

# コード内
rg "OldName" --type-add 'web:*.{ts,tsx,js,jsx}' -t web

# Storybook
rg "title:.*OldName" -g "*.stories.*"

# テスト
rg "describe\(.*OldName" -g "*.test.*" -g "*.spec.*"
```

### ディレクトリ構造の変更

#### ディレクトリ変更の検索対象

- [ ] **import path**: 相対パス、絶対パス
- [ ] **動的import**: `import()`, `require()`
- [ ] **設定ファイル**: tsconfig.json の paths, webpack alias等
- [ ] **テストのモックパス**: `jest.mock()`
- [ ] **ドキュメントのリンク**: README, コメント内のパス参照

#### ディレクトリ変更の検索コマンド例

```bash
# 旧パスの検索
rg "from.*old/path"
rg "import.*old/path"
rg "require.*old/path"

# 設定ファイル内のパス
rg "old/path" -g "*.json" -g "*.config.*"
```

### バリデーションロジック・エラーメッセージの汎化

#### 汎化の検索対象

- [ ] **ハードコードされたメッセージ**: 文字列リテラル
- [ ] **条件分岐**: if/switch による個別処理
- [ ] **重複コード**: 同様の処理の繰り返し
- [ ] **フィールド固有の処理**: 特定フィールドのみの実装

#### 汎化のパターン検索例

```bash
# エラーメッセージのハードコード
rg "エラー.*です" --type typescript

# 重複パターン
rg "if.*email.*required" -A 2 -B 2

# フィールド固有バリデーション
rg "validate(Email|Password|Name)" --type typescript
```

### メソッド/関数のシグネチャ変更

#### シグネチャ変更の検索対象

- [ ] **関数呼び出し**: 全呼び出し箇所
- [ ] **型定義**: 引数・戻り値の型
- [ ] **モック**: テストでのモック定義
- [ ] **コールバック**: 高階関数での使用
- [ ] **型アサーション**: 戻り値の型アサーション

#### シグネチャ変更の検索コマンド例

```bash
# 関数呼び出し
rg "oldFunctionName\("

# 型定義
rg ":\s*\(.*\)\s*=>\s*OldReturnType"

# モック
rg "mock.*oldFunctionName" -g "*.test.*"
```

## リファクタリングワークフロー

### Phase 1: 調査・計画

```markdown
## リファクタリング計画

### 目的
[何を、なぜリファクタリングするか]

### 影響範囲の調査

#### ファイル名の変更
- [ ] `src/components/OldName.tsx` → `NewName.tsx`
- [ ] `src/components/OldName.test.tsx` → `NewName.test.tsx`

#### import文の更新（20箇所）
- [ ] `src/pages/Home.tsx` (line 5)
- [ ] `src/pages/About.tsx` (line 8)
- ...

#### Storybook
- [ ] `src/stories/OldName.stories.tsx` (title変更)

#### 型定義
- [ ] `src/types/index.ts` (export名変更)

### リスク評価
- テストカバレッジ: 80%
- 外部依存: なし
- 推定作業時間: 30分
```

### Phase 2: ユーザー承認

計画をユーザーに提示し、承認を得ます。

```text
以下のリファクタリング計画を作成しました。
実行前に確認をお願いします。

[計画の内容を提示]

承認いただければ、一括で実行します。
```

### Phase 3: 一括実行

承認後、**全ての変更を一度に実行**します。

```bash
# ファイルリネーム
mv src/components/OldName.tsx src/components/NewName.tsx

# 全importの更新
rg -l "from.*OldName" | xargs sed -i 's/OldName/NewName/g'

# テスト実行
npm test
```

### Phase 4: 検証

- [ ] 全テストがパス
- [ ] ビルドが成功
- [ ] 型エラーがない
- [ ] リンターエラーがない

## チェックリストテンプレート

### コンポーネントリネーム

```markdown
## コンポーネントリネーム: OldName → NewName

### ファイル
- [ ] コンポーネント本体
- [ ] テストファイル
- [ ] Storybookファイル

### import/export
- [ ] import文（全XX箇所）
- [ ] export文
- [ ] re-export (index.ts等)

### 使用箇所
- [ ] JSX内での使用
- [ ] 型定義での参照

### テスト
- [ ] describe/test名
- [ ] モックの型定義

### Storybook
- [ ] title
- [ ] storyName

### ドキュメント
- [ ] README
- [ ] JSDocコメント
```

### ディレクトリ移動

```markdown
## ディレクトリ移動: old/path → new/path

### ファイル移動
- [ ] 対象ファイル（全XX個）

### import path更新
- [ ] 相対パス（全XX箇所）
- [ ] 絶対パス（全XX箇所）
- [ ] 動的import

### 設定ファイル
- [ ] tsconfig.json paths
- [ ] jest.config.js
- [ ] webpack config

### テスト
- [ ] モックパス
- [ ] スナップショット

### ドキュメント
- [ ] README内のパス参照
```

### バリデーション汎化

```markdown
## バリデーション汎化: ハードコード → 汎用関数

### 対象フィールド
- [ ] email
- [ ] password
- [ ] name
- [ ] prefecture
- [ ] phoneNumber
- [ ] ...（全XXフィールド）

### 変更内容
- [ ] エラーメッセージの汎化
- [ ] バリデーション関数の統一
- [ ] 重複コードの削除

### テスト
- [ ] 各フィールドのテスト更新
- [ ] エッジケースの確認
```

## 命名規則の尊重

既存コードベースの命名パターンを確認し、それに従います。

### 調査方法

```bash
# 同一ディレクトリの命名パターン確認
ls src/components/

# prefixパターンの確認
rg "^(export )?(const|function|class) \w+" -g "*.tsx" | head -20

# Storybookのタイトルパターン
rg "title:\s*'" -g "*.stories.*"
```

### 例

既存コード:

```typescript
// 既存の命名パターン
UserCard.tsx
UserList.tsx
UserProfile.tsx
```

リネーム時:

❌ 避けるべき:

```typescript
GuestConvertUserCard.tsx  // 過度に冗長
```

✅ 推奨:

```typescript
UserCard.tsx  // 既存パターンに従う
```

## よくある見落とし

### 1. Storybookのtitle

```typescript
// ファイル名は変更したが、titleが古いまま
export default {
  title: 'Components/OldName',  // ← 更新漏れ
  component: NewName,
} as Meta;
```

### 2. テストのdescribe

```typescript
// コンポーネント名は変更したが、describeが古いまま
describe('OldName', () => {  // ← 更新漏れ
  it('should render', () => {
    render(<NewName />);
  });
});
```

### 3. 型定義のre-export

```typescript
// types/index.ts
export type { OldName } from './OldName';  // ← 更新漏れ
```

### 4. 動的import

```typescript
// 静的importは更新したが、動的importが漏れる
const OldName = lazy(() => import('./OldName'));  // ← 更新漏れ
```

### 5. コメント内の参照

```typescript
/**
 * OldName コンポーネントを使用してユーザー情報を表示
 * ↑ 更新漏れ
 */
```

## Coding Agentでの実践

### リファクタリング依頼の例

```text
UserCard を UserProfile にリネームしたいです。
実装前に以下を行ってください:

1. 全ての変更対象箇所を検索（ファイル名、import、型定義、テスト、Storybook等）
2. 完全なチェックリストを作成
3. 私の承認を待つ
4. 承認後、一度に全て変更
5. テスト実行で検証
```

### バリデーション汎化の依頼例

```text
エラーメッセージのハードコードを汎化したいです。

1. 全てのフィールドで使用されているエラーメッセージパターンをリストアップ
2. どのフィールドが未汎化か特定
3. 汎化方針を提示
4. 承認後、全フィールドを一括更新
```

## まとめ

- **調査→計画→承認→一括実行**の順で進める
- 複数の検索手段を組み合わせて漏れを防ぐ
- 既存の命名規則を尊重
- よくある見落としポイントを意識する
- 変更後は必ずテストで検証

---

**参考資料**:

- `dev-settings/coding-agents/agent-docs/conventions/tidyings-vs-refactoring.md` - リファクタリングの判断基準
- `dev-settings/coding-agents/agent-docs/testing/tdd-workflow.md` - テスト駆動開発
