# Compose UI Playground

このディレクトリには、MVI + Jetpack Composeの実装例が含まれています。

## 📁 ファイル

### CounterMviExample.kt

シンプルなカウンターアプリのMVI実装例です。以下の要素が含まれています：

1. **Intent** - ユーザーの意図を表現するsealed class
2. **State** - 画面の状態を表現するdata class
3. **ViewModel** - ビジネスロジックと状態管理
4. **UI** - Compose UIの実装
5. **Previews** - 複数の状態パターンのプレビュー

## 🎨 Android Studioでプレビューを表示する方法

### 方法1: Split モード

1. Android Studioで `CounterMviExample.kt` を開く
2. エディタ右上の **「Split」** ボタンをクリック
3. エディタが左右に分割され、右側にプレビューが表示されます

### 方法2: Design モード

1. Android Studioで `CounterMviExample.kt` を開く
2. エディタ右上の **「Design」** ボタンをクリック
3. コードエディタがプレビュー表示に切り替わります

### 方法3: ショートカットキー

- macOS: `Cmd + Option + P`
- Windows/Linux: `Ctrl + Alt + P`

## 📸 プレビューの種類

このファイルには、以下の5つのプレビューが定義されています：

1. **初期状態（カウント0）** - アプリ起動時の状態
2. **正の偶数（カウント10）** - 正の偶数の状態
3. **正の奇数（カウント7）** - 正の奇数の状態
4. **負の偶数（カウント-4）** - 負の数の状態
5. **ダークモード（カウント42）** - ダークモードでの表示

プレビュー画面では、これらすべてを一度に確認できます。

## 🔍 プレビューのメリット

### 1. エミュレータ不要

エミュレータを起動することなく、Android Studio内でUIを即座に確認できます。

### 2. 複数の状態を同時確認

異なる状態パターンを並べて表示できるため、デザインの一貫性を保ちやすくなります。

### 3. 高速なイテレーション

コードを変更すると、プレビューがすぐに更新されるため、デザインの微調整が効率的に行えます。

### 4. インタラクティブモード

プレビュー画面の「Interactive」ボタンをクリックすると、ボタンのクリックなどの操作を実際に試すことができます。

## 🎯 MVIアーキテクチャのポイント

### 単方向データフロー

```text
User Action → Intent → ViewModel → State → UI
                ↑                            ↓
                └────────────────────────────┘
```

### 状態の一元管理

すべての状態情報が`CounterUiState`に集約されているため：

- 状態の不整合が発生しない
- テストが容易
- デバッグがしやすい

### Intentによる明示的なアクション

すべてのユーザーアクションが`CounterIntent`として定義されているため：

- どのような操作が可能か一目瞭然
- 状態遷移の追跡が容易
- テストケースの網羅が簡単

## 🧪 テスト例

このMVI実装は、以下のようにテストできます：

```kotlin
@Test
fun `Increment Intentでカウントが1増えること`() = runTest {
    val viewModel = CounterMviViewModel()

    viewModel.processIntent(CounterIntent.Increment)

    val state = viewModel.uiState.value
    assertEquals(1, state.count)
    assertEquals(false, state.isEven)
    assertEquals("カウントは正の奇数です", state.message)
}
```

## 📚 参考資料

- [Jetpack Compose 公式ドキュメント](https://developer.android.com/jetpack/compose)
- [Preview in Compose](https://developer.android.com/jetpack/compose/tooling/previews)
- [State and Jetpack Compose](https://developer.android.com/jetpack/compose/state)
- [MVI Architecture](https://cycle.js.org/model-view-intent.html)

## 💡 次のステップ

このシンプルな例を理解したら、以下の機能を追加してみてください：

1. **非同期処理** - API呼び出しをシミュレート
2. **エラーハンドリング** - エラー状態の管理
3. **ローディング状態** - 処理中の表示
4. **永続化** - カウント値の保存と復元
5. **アニメーション** - 状態変化時のアニメーション

これらはすべて、MVIアーキテクチャのパターンに従って実装できます。
