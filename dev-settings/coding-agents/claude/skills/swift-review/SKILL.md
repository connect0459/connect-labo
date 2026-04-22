---
name: swift-review
description: >
  Performs Swift code review for iOS apps. Use whenever reviewing Swift code,
  providing feedback on a PR diff, or checking Swift files for correctness and stability.
  Always trigger this skill when asked to review Swift code in an iOS app, especially changes involving
  Presenters, ViewControllers, ViewModels, Reducers, Stores, NotificationCenter observers,
  threading/DispatchQueue, or test code (XCTest, Nimble, TCA TestStore, etc.).
  Also trigger when checking architecture layer boundaries in MVP, MVVM, TCA, or any other pattern.
---

# Swift コードレビュースキル

このスキルは、iOSアプリのSwiftコードレビューを行う。アーキテクチャは MVP / MVVM / TCA など問わない。
以下の観点を順番に確認し、問題があれば指摘する。

## レビューの進め方

1. 変更されたファイルをすべて読む
2. 以下の各観点を確認する
3. 問題を重要度（🔴 クラッシュリスク / 🟡 設計上の問題 / 🔵 改善提案）でラベリングして報告する
4. 問題がない場合は「✅ 問題なし」と明示する

---

## 観点 1: ライフサイクル管理

### NotificationCenter の addObserver / removeObserver の対称性

- `addObserver` が `init` に置かれているなら `removeObserver` は `deinit` にあるか
- `addObserver` が `viewDidLoad` に置かれているなら `removeObserver` は対応するタイミング（`viewWillDisappear` など）にあるか
- `deinit` が実装されていない場合、オブザーバー解除漏れのリスクがないか

`init`/`deinit` での対称性が最も安全なパターン：

```swift
// Good
init(..., notificationCenter: NotificationCenter) {
    notificationCenter.addObserver(self, selector: #selector(handle), name: .foo, object: nil)
}
deinit {
    notificationCenter.removeObserver(self)
}
```

`viewDidLoad` に `addObserver` を置くと `deinit` との非対称が生まれやすい。既存コードで `viewDidLoad` に置かれている場合、`deinit` での解除漏れに特に注意する。

### View 未ロード時の通知ハンドラガード（isViewLoaded）

- MainTabBarController のタブとして生成される VC など、`viewDidLoad` が呼ばれる前に通知を受信しうるケースがある
- 通知ハンドラ内で IBOutlet や View のメソッドを呼ぶ前に `isViewLoaded()` チェックが入っているか
- View プロトコルに `isViewLoaded() -> Bool` が定義されており、通知ハンドラ内でガードされているか

```swift
// Good
@objc private func handleNotification() {
    DispatchQueue.main.async { [weak self] in
        guard let view = self?.view else { return }
        guard view.isViewLoaded() else { return }
        view.updateBadge(value: 5)
    }
}
```

---

## 観点 2: nil チェック / 強制アンラップによるクラッシュリスク

### weak var view の nil チェック

- `private weak var view: ViewProtocol?` はオプショナル型が望ましい
- `private weak var view: ConcreteVC!`（weak + IUO）のパターンは、VC が Presenter より先に解放されたとき `nil` に強制アンラップしてクラッシュするリスクがある
- 通知ハンドラ・API コールバック内での `view` 参照には `guard let view = self?.view` または optional chaining が入っているか

```swift
// Bad - IUO のまま nil チェックなし
@objc private func handle() {
    view.reload()  // view が nil なのでクラッシュ
}

// Good
@objc private func handle() {
    DispatchQueue.main.async { [weak self] in
        guard let view = self?.view else { return }
        view.reload()
    }
}
```

### IBOutlet / UIコンポーネントへのアクセス

- IBOutlet は `viewDidLoad` 前は `nil` であることに注意
- `isViewLoaded` ガードなしに IBOutlet を参照するメソッドが通知ハンドラから呼ばれていないか

### その他の強制アンラップ

- `!` による強制アンラップは、`nil` になり得ない根拠が明確か
- `URL(string:)!` や `as!` キャストは定数・信頼できる値に限定されているか

---

## 観点 3: スレッド安全性

### UIKit / WebKit 操作はメインスレッドで行われているか

特定のクラスがバックグラウンドのシリアルキュー上でトークン更新完了通知を送信する仕組みを採用している場合、通知ハンドラ `didAccessTokenRefreshedByAPIAccess` 内の UI 操作はバックグラウンドスレッドで呼ばれる可能性がある。

確認ポイント：

- API コールバック（completion ハンドラ）内で UIKit / WebKit を操作している箇所に `DispatchQueue.main.async` が入っているか
- 通知ハンドラ内の UIKit 操作が `DispatchQueue.main.async { [weak self] in ... }` でラップされているか
- `[weak self]` を忘れずに付けているか（メモリリーク防止）

```swift
// Bad - バックグラウンドスレッドから WKWebView を操作
@objc private func didAccessTokenRefreshedByAPIAccess() {
    view?.reload(withCookie: token.cookie())
}

// Good
@objc private func didAccessTokenRefreshedByAPIAccess() {
    DispatchQueue.main.async { [weak self] in
        guard let view = self?.view else { return }
        guard view.isViewLoaded() else { return }
        view.reload(withCookie: token.cookie())
    }
}
```

---

## 観点 4: アーキテクチャのレイヤー境界

採用しているアーキテクチャ（MVP / MVVM / TCA など）に応じて、各レイヤーの責務が守られているかを確認する。

### ロジック層の責務（Presenter / ViewModel / Reducer）

- ロジック層は UIKit に依存しないことが望ましい（`import UIKit` が不要な処理は避ける）
- ビジネスロジックはロジック層に、UI 更新は View 層（VC / SwiftUI View）に委譲されているか
- 画面遷移がルーター・コーディネーター経由で行われているか（VC 内から直接 push/present していないか）
- **TCA の場合**: 副作用は `Effect` として `Reducer` に閉じ込め、`Store` 経由でのみ状態変更が行われているか

### View 層とのインターフェース

- **MVP**: `private weak var view: ConcreteViewController!` ではなく `private weak var view: ViewProtocol?` になっているか
  - プロトコル化でテストにモックを注入できる
  - オプショナル型（`?`）で IUO クラッシュを防止できる
  - View プロトコルには UI 更新メソッドのみが定義されているか（ビジネスロジックが混入していないか）
- **MVVM**: VC が ViewModel を購読しているか（binding / Combine / RxSwift など）。VC が直接ビジネスロジックを持っていないか
- **TCA**: VC / View が `store.send(_:)` を通じてのみアクションを発行しているか

### ViewController の責務

- VC がビジネスロジックを直接持っていないか（API 呼び出し、データ変換など）
- ユーザーアクションはロジック層（Presenter / ViewModel / Store）に委譲されているか

### 依存性の注入

- `NotificationCenter`、API クライアント、ストア等はイニシャライザで注入されているか
- シングルトン（`NotificationCenter.default` など）を直接使うとテストが書きにくくなる

### Protocol Oriented Programming による抽象化

- フレームワーク型（`WKNavigationAction`・`WKFrameInfo` など）を Presenter やハンドラが直接受け取っていないか
  - 直接受け取ると、テストで具象クラスをサブクラス化せざるを得なくなり、フレームワーク内部の初期化処理に起因するクラッシュを招く
  - 対象の型をラップするプロトコルを定義し、Presenter はプロトコルのみに依存させること
  - 本番コードでは実型を extension でプロトコルに準拠させ、テストではプロトコルに準拠した軽量 Mock を使う

```swift
// Bad - Presenter が WKNavigationAction（具象クラス）に直接依存
func handleWebNavigation(for action: WKNavigationAction, ...) { ... }

// Good - プロトコル経由で依存を抽象化
protocol NavigationActionProtocol {
    var url: URL? { get }
    var navigationType: WKNavigationType { get }
    var targetFrame: FrameInfoProtocol? { get }
}
extension WKNavigationAction: NavigationActionProtocol {
    var url: URL? { request.url }
    var targetFrame: FrameInfoProtocol? { ... }
}
func handleWebNavigation(for action: NavigationActionProtocol, ...) { ... }
```

---

## 観点 5: テストの品質（Evergreen）

使用しているテストフレームワーク（XCTest / Nimble / TCA `TestStore` など）を考慮した上で以下を確認する。

### テスト名の命名規則

`test_<イベント名またはメソッド名>_<期待されるビジネスルール>` の形式（日本語）になっているか。

```swift
// Bad - 実装詳細を説明している
func test_notificationReceived_viewReloaded() { ... }

// Good - ビジネスルールを表現している
func test_アクセストークン更新通知受信_Presenter生存中はWebViewがリロードされる() { ... }
func test_アクセストークン更新通知受信_Presenter解放後はWebViewがリロードされない() { ... }
func test_アクセストークン更新通知受信_View解放後もクラッシュしない() { ... }
```

### 境界条件のカバレッジ

NotificationCenter や非同期処理を含むロジック層（Presenter / ViewModel / Reducer）のテストでは、以下の境界条件をカバーしているか：

- ✅ 正常系：Presenter / ViewModel 生存中、View ロード済み
- ✅ Presenter / ViewModel 解放後：`sut = nil` してから通知を送信し、View が更新されないことを確認
- ✅ View 解放後：`mockView = nil` してもクラッシュしないことを確認
- ✅ View 未ロード時：`mockView.isViewLoadedResult = false` で早期リターンすることを確認
- ✅ **TCA の場合**: `TestStore` を使ったアクション→状態遷移の網羅、`receive(_:)` / `assert` での副作用検証

### モックの設計

- Mock の completion クロージャが `ScreenRouter.shared` などの本番コードを呼んでいないか
  - 例：`MockXxxViewController.dismissViewController` が `completion?()` を呼ぶと、その先の `ScreenRouter.shared.showLoginScreen()` が実行されてクラッシュする

```swift
// Bad - completion がテスト中に本番の画面遷移コードを呼ぶ
class MockGuestConvertViewController: GuestConvertView {
    func dismissViewController(completion: (() -> Void)?) {
        isDismissed = true
        completion?()  // navigateToLoginScreen() が呼ばれてクラッシュ
    }
}

// Good
class MockGuestConvertViewController: GuestConvertView {
    func dismissViewController(completion: (() -> Void)?) {
        isDismissed = true
        // completion は呼ばない（テスト対象外の副作用を防ぐ）
    }
}
```

### フレームワーク由来の具象クラスの不正継承

- テスト用 Mock が `WKFrameInfo`・`WKNavigationAction`・`WKWebView` などの WebKit / UIKit 具象クラスを継承していないか
  - これらは内部で C++ オブジェクトを非同期初期化するため、`super.init()` だけで生成した Mock に対してフレームワークがバックグラウンドでアクセスした瞬間にクラッシュする
  - テスト数が少ない頃は全テストが非同期アクセス開始前に終わるため通過していたが、テスト数が増えると猶予時間を超えてフレイキー→再現性ありへと悪化する
  - 根本対応は後述の「Protocol Oriented Programming による抽象化」でプロトコルに差し替えること

```swift
// Bad - WKFrameInfo をサブクラス化すると C++ バックグラウンド処理でクラッシュする
class MockWKFrameInfo: WKFrameInfo {
    private let _isMainFrame: Bool
    init(isMainFrame: Bool) {
        self._isMainFrame = isMainFrame
        super.init()  // C++ オブジェクトが存在しないため後でクラッシュ
    }
    override var isMainFrame: Bool { _isMainFrame }
}

// Good - プロトコルを介して軽量な Mock を定義する
protocol FrameInfoProtocol {
    var isMainFrame: Bool { get }
}
class MockFrameInfo: FrameInfoProtocol {
    let isMainFrame: Bool
    init(isMainFrame: Bool) { self.isMainFrame = isMainFrame }
}
```

---

## 観点 6: テストの非同期対応

### 同期的アサーションと非同期処理のミスマッチ

- Presenter / ViewModel の通知ハンドラが `DispatchQueue.main.async` を使っている場合、テストで `to(equal(...))` を同期的に使っても検証できない
- **Nimble**: `toEventually` または `waitUntil` で非同期処理の完了を待ってからアサーションを行っているか
- **XCTest**: `XCTestExpectation` + `waitForExpectations(timeout:)` が正しく使われているか
- **TCA TestStore**: `await store.receive(_:)` / `await store.finish()` など、TCA の同期制御 API が活用されているか

```swift
// Bad - main.async 内の処理がまだ実行されていない状態で検証
notificationCenter.post(name: .foo, object: nil)
expect(mockView.reloadedCookie).to(equal(cookie))  // タイミング依存で失敗する

// Good - 非同期処理の完了を待つ（正常系）
notificationCenter.post(name: .foo, object: nil)
expect(self.mockView.reloadedCookie).toEventuallyNot(beNil())

// Good - 「呼ばれないこと」を検証する場合（waitUntil でメインキューのフラッシュを待つ）
notificationCenter.post(name: .foo, object: nil)
waitUntil { done in
    DispatchQueue.main.async { done() }
}
expect(self.mockView.reloadedCookie).to(beNil())
```

### `waitUntil` vs `toEventually` の使い分け

completion callback がある非同期処理には `waitUntil` を使う。 `done()` が呼ばれた後にアサーションするため決定的に検証できる。

| | `waitUntil { done in ... }` | `toEventually(...)` |
|---|---|---|
| 向き | completion callback がある非同期処理 | 外から完了を知れない状態変化 |
| 仕組み | `done()` が呼ばれるまでブロック（決定的） | タイムアウトまでポーリング（非決定的） |
| 適用例 | `fetchXxx(completion:)` | NotificationCenter 通知後の状態変化 |

```swift
// ✅ completion callback がある場合 - waitUntil で「完了後にアサート」が明確
waitUntil { done in
    presenter.fetchBingoTabVisibility { done() }
}
expect(presenter.isBingoEnabled).to(beTrue())

// △ 動くが非決定的 - 「いつか true になるはず」とポーリング
presenter.fetchBingoTabVisibility {}
expect(presenter.isBingoEnabled).toEventually(beTrue())

// ✅ toEventually が自然なケース - NotificationCenter のように完了タイミングが外から不明な場合
notificationCenter.post(name: .foo, object: nil)
expect(mockView.reloadedCookie).toEventuallyNot(beNil())
```

### 「何も起きないこと」の検証

- 「View が更新されない」「クラッシュしない」を検証するテストでは、`waitUntil { done in DispatchQueue.main.async { done() } }` でメインキューをフラッシュしてからアサーションする

---

## 観点の横展開

変更ファイルで問題が見つかった場合、**同一パターンを持つ他のクラス**に同様の問題が残っていないかも確認する。

例：

- `BaseWebViewPresenter` を継承するサブクラス（`PointLimitPresenter`、`ContactPresenter` など）
- 同じ通知を購読している Presenter / ViewModel 群
- 同じ `private weak var view: ConcreteVC!` パターンを持つ Presenter
- 同じ Reducer を利用する複数の Feature（TCA の場合）

横展開漏れがある場合は「他に同様の問題を抱えているファイル」として別途報告する。
