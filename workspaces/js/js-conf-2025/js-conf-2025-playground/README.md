# ECMAScript `using` 宣言とJSリソース管理のサンプルコード

ECMAScriptの「明示的リソース管理（Explicit Resource Management, ERM）」仕様、特に`using`宣言と`DisposableStack`の実践的なサンプルコード集です。

## 📚 概要

このプロジェクトは、以下のトピックをカバーしています：

1. **基本的な`using`宣言** - 同期リソースの自動破棄
2. **`await using`宣言** - 非同期リソースの自動破棄
3. **`DisposableStack`** - 複数リソースの一元管理
4. **Reactイベントハンドラ** - `await using`の実践的活用
5. **React useEffect** - `DisposableStack`によるクリーンアップ改善

## 🚀 セットアップ

### 必要な環境

- Node.js 18以上
- npm または yarn

### インストール

```bash
npm install
```

## 🧪 テスト実行

```bash
# 全てのテストを実行
npm test

# テストをwatchモードで実行
npm test -- --watch

# カバレッジレポートを生成
npm test -- --coverage
```

## 📖 サンプルコード

### 1. 基本的な`using`宣言

**ファイル**: `src/examples/01-basic-using.ts`

`using`宣言の基本的な使い方を学べます：

- `Symbol.dispose`プロトコルの実装
- レキシカルスコープによる自動破棄
- LIFO順（後入れ先出し）でのリソース破棄
- 例外発生時の安全な破棄

```typescript
export class ManagedResource {
  [Symbol.dispose](): void {
    // クリーンアップ処理
  }
}

{
  using resource = new ManagedResource("example");
  resource.doWork();
  // スコープ終了時に自動的に破棄される
}
```

### 2. `await using`宣言

**ファイル**: `src/examples/02-await-using.ts`

非同期リソースの管理方法を学べます：

- `Symbol.asyncDispose`プロトコルの実装
- データベース接続の管理
- トランザクションの自動コミット/ロールバック

```typescript
export class DatabaseConnection {
  async [Symbol.asyncDispose](): Promise<void> {
    // 非同期のクリーンアップ処理
  }
}

{
  await using db = await DatabaseConnection.connect("mydb");
  await db.query("SELECT * FROM users");
  // スコープ終了時に自動的にクローズ
}
```

### 3. `DisposableStack`

**ファイル**: `src/examples/03-disposable-stack.ts`

複数のリソースを命令的に管理する方法を学べます：

- `.use()` - Disposableプロトコルを持つリソースの追加
- `.adopt()` - 任意の値とクリーンアップ関数のペア登録
- LIFO順での一括破棄

```typescript
{
  using stack = new DisposableStack();

  // タイマーを管理
  const timerId = setTimeout(() => {}, 1000);
  stack.adopt(timerId, clearTimeout);

  // Disposableリソースを管理
  const resource = createResource();
  stack.use(resource);

  // スコープ終了時、LIFO順で全て破棄
}
```

### 4. Reactイベントハンドラでの`await using`

**ファイル**: `src/examples/04-react-event-handler.tsx`

イベントハンドラ内での実践的な使用例：

- フォーム送信時のAPI接続管理
- `try...finally`との比較
- `AsyncDisposableStack`による複数リソース管理

```typescript
async function handleSubmit(event: React.FormEvent) {
  event.preventDefault();

  try {
    await using api = await ApiClient.connect("/api/users");
    await api.post(formData);
    // 成功・失敗に関わらず、API接続は自動的にクローズ
  } catch (err) {
    setError(err.message);
  }
}
```

### 5. React useEffectでの`DisposableStack`

**ファイル**: `src/examples/05-react-useeffect.tsx`

`useEffect`のクリーンアップパターン改善：

- 従来の手動クリーンアップとの比較
- WebSocket接続の管理
- 条件付きリソース管理
- カスタムフックでの活用

```typescript
useEffect(() => {
  const stack = new DisposableStack();

  // タイマー
  const timerId = setTimeout(() => {}, 5000);
  stack.adopt(timerId, clearTimeout);

  // イベントリスナー
  const handleResize = () => {};
  window.addEventListener("resize", handleResize);
  stack.adopt(handleResize, (listener) => {
    window.removeEventListener("resize", listener);
  });

  // クリーンアップは1行！
  return () => stack.dispose();
}, [dependency]);
```

## 🎯 主なメリット

### 1. `try...finally`の問題を解決

- ❌ 冗長なコード
- ❌ Nullチェックが必須
- ❌ エラー隠蔽のリスク

↓

- ✅ 簡潔なコード
- ✅ Nullチェック不要
- ✅ `SuppressedError`による安全なエラーチェーン

### 2. Reactのアンチパターンを解消

#### イベントハンドラ

- ❌ 手動の`try...finally`
- ❌ クリーンアップの書き忘れ

↓

- ✅ `await using`で自動クリーンアップ
- ✅ スコープベースの安全な管理

#### useEffect

- ❌ 複数のクリーンアップを個別に管理
- ❌ クリーンアップ漏れのリスク

↓

- ✅ `DisposableStack`で一元管理
- ✅ `return () => stack.dispose()`の1行で完結

## 🔧 技術スタック

- **Runtime**: Node.js 18+
- **Framework**: React 19
- **Build Tool**: Vite 7
- **Testing**: Vitest 4
- **Language**: TypeScript 5.9

## 📝 TypeScript設定のポイント

`using`と`await using`を使用するために、以下の設定が必要です：

```json
{
  "compilerOptions": {
    "target": "ESNext",
    "lib": ["ESNext", "DOM", "DOM.Iterable"],
    "module": "ESNext"
  }
}
```

**重要**: `erasableSyntaxOnly`オプションは`using`構文と互換性がないため、無効にしてください。

## 🌟 ベストプラクティス

### 1. イベントハンドラでは`await using`を使う

短命な非同期リソース（API接続、ファイル操作など）は、イベントハンドラ内で`await using`を使って管理します。

### 2. useEffectでは`DisposableStack`を使う

複数のリソース（タイマー、リスナー、サブスクリプションなど）を管理する場合は、`DisposableStack`で一元管理します。

### 3. `using`は`useEffect`の代替ではない

`using`はレキシカルスコープでリソースを管理します。`useEffect`のようなコンポーネントライフサイクルとは異なる概念です。

### 4. デトロイト派のテスト思想

テストでは極力モックを避け、実際のオブジェクトとの協調を重視しています。

## 📚 参考資料

- [TC39 Proposal: Explicit Resource Management](https://github.com/tc39/proposal-explicit-resource-management)
- [MDN: using statement](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Statements/using)
- [V8.dev: JavaScript's New Superpower](https://v8.dev/features/explicit-resource-management)

## 📄 ライセンス

MIT
