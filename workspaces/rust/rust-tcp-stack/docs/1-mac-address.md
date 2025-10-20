# Phase 1: MACアドレス実装（TDDで）

## このフェーズで学ぶこと

このフェーズでは、MACアドレスの基礎知識を学びながら、TDDのRed → Green → Refactorサイクルを実践します。また、Rustでの構造体定義とトレイト実装の方法、そしてテストの書き方を習得します。

---

## MACアドレスとは？

MAC（Media Access Control）アドレスは、ネットワークインターフェースカード（NIC）に割り当てられた物理アドレスです。Ethernet通信において、同じネットワーク内のデバイスを識別するために使用されます。

### MACアドレスの特徴

- 長さ：48ビット（6バイト）
- 表記：16進数で表記され、通常は`:`（コロン）または`-`（ハイフン）で区切られます
  - 例：`00:11:22:33:44:55` または `00-11-22-33-44-55`
- 一意性：製造時にハードウェアに割り当てられ、世界中で一意であることが期待されます（実際には変更可能）

### MACアドレスの構造

48ビットのMACアドレスは、以下の2つの部分から構成されています：

```text
+------------------------+------------------------+
|   OUI (24ビット)       |   NIC固有 (24ビット)   |
+------------------------+------------------------+

OUI (Organizationally Unique Identifier): ベンダー（製造者）を識別
NIC固有: そのベンダー内で一意な識別子
```

### 特別なMACアドレス

- ブロードキャストアドレス：`ff:ff:ff:ff:ff:ff`
  - 同じネットワーク内のすべてのデバイスに送信する際に使用
  - 例：ARP（Address Resolution Protocol）リクエスト

- マルチキャストアドレス：最下位バイトの最下位ビットが1
  - 特定のグループに属するデバイスに送信

---

## TODOリスト（Phase 1）

TDDでは、実装前にTODOリストを作成します。これにより、何をすべきかが明確になり、進捗も把握しやすくなります。

```text
MACアドレス
□ MACアドレスを表現できる
□ MACアドレスを文字列表示できる
□ ブロードキャストMACアドレスを作れる
```

---

## Iteration 1: MACアドレスを表現できる

### Step 1: テストを書く（Red）

まず、`src/ethernet.rs`を作成します。

```rust
// まだ何もない状態

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn macアドレスを作成できる() {
        let mac = MacAddress::new([0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
        assert_eq!(mac.bytes(), [0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
    }
}
```

重要: モジュールを認識させるために、プロジェクトのエントリーポイントでモジュール宣言が必要です。

#### ライブラリプロジェクト（`cargo new --lib`）の場合

`src/lib.rs`:

```rust
pub mod ethernet;
```

#### バイナリプロジェクト（`cargo new`）の場合

`src/main.rs`:

```rust
mod ethernet;

fn main() {
    println!("Hello, world!");
}
```

### Step 2: テスト実行（Red確認）

```bash
cargo test
```

期待される結果: コンパイルエラー（`MacAddress`が存在しない）

```text
error[E0425]: cannot find type `MacAddress` in this scope
  --> src/ethernet.rs:8:18
   |
8  |         let mac = MacAddress::new([0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
   |                   ^^^^^^^^^^ not found in this scope
```

✅ これでいい！ テストが失敗することを確認しました。これがRedの状態です。

### Step 3: テストを通す最小限のコード（Green）

次に、このテストだけを通すための最小限のコードを書きます。

```rust
pub struct MacAddress {
    bytes: [u8; 6],
}

impl MacAddress {
    pub fn new(bytes: [u8; 6]) -> Self {
        MacAddress { bytes }
    }

    pub fn bytes(&self) -> [u8; 6] {
        self.bytes
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn macアドレスを作成できる() {
        let mac = MacAddress::new([0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
        assert_eq!(mac.bytes(), [0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
    }
}
```

### Step 4: テスト実行（Green確認）

```bash
cargo test
```

期待される結果: テスト成功

```text
running 1 test
test ethernet::tests::macアドレスを作成できる ... ok

test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s
```

✅ Green！ テストが通りました。

### Step 5: リファクタリング（Refactor）

今の段階では特にリファクタリングの必要はありません。次のテストへ進みましょう。

TODOリストを更新:

```text
MACアドレス
☑ MACアドレスを表現できる
□ MACアドレスを文字列表示できる
□ ブロードキャストMACアドレスを作れる
```

---

## Iteration 2: MACアドレスを文字列表示できる

### Step 1: テストを書く（Red）

MACアドレスは人間が読みやすい形式で表示できるべきです。`Display`トレイトを実装して、`aa:bb:cc:dd:ee:ff`のような形式で表示できるようにします。

```rust
use std::fmt;

pub struct MacAddress {
    bytes: [u8; 6],
}

impl MacAddress {
    pub fn new(bytes: [u8; 6]) -> Self {
        MacAddress { bytes }
    }

    pub fn bytes(&self) -> [u8; 6] {
        self.bytes
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn macアドレスを作成できる() {
        let mac = MacAddress::new([0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
        assert_eq!(mac.bytes(), [0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
    }

    #[test]
    fn macアドレスを文字列表示できる() {
        let mac = MacAddress::new([0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]);
        assert_eq!(format!("{}", mac), "aa:bb:cc:dd:ee:ff");
    }
}
```

### Step 2: テスト実行（Red確認）

```bash
cargo test
```

期待される結果: コンパイルエラー（`Display`トレイトが実装されていない）

```text
error[E0277]: `MacAddress` doesn't implement `std::fmt::Display`
  --> src/ethernet.rs:25:29
   |
25 |         assert_eq!(format!("{}", mac), "aa:bb:cc:dd:ee:ff");
   |                             ^^^ `MacAddress` cannot be formatted with the default formatter
```

✅ Red！ 期待通りエラーが出ました。

### Step 3: テストを通す最小限のコード（Green）

`Display`トレイトを実装します。

```rust
use std::fmt;

pub struct MacAddress {
    bytes: [u8; 6],
}

impl MacAddress {
    pub fn new(bytes: [u8; 6]) -> Self {
        MacAddress { bytes }
    }

    pub fn bytes(&self) -> [u8; 6] {
        self.bytes
    }
}

impl fmt::Display for MacAddress {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(
            f,
            "{:02x}:{:02x}:{:02x}:{:02x}:{:02x}:{:02x}",
            self.bytes[0],
            self.bytes[1],
            self.bytes[2],
            self.bytes[3],
            self.bytes[4],
            self.bytes[5]
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn macアドレスを作成できる() {
        let mac = MacAddress::new([0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
        assert_eq!(mac.bytes(), [0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
    }

    #[test]
    fn macアドレスを文字列表示できる() {
        let mac = MacAddress::new([0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]);
        assert_eq!(format!("{}", mac), "aa:bb:cc:dd:ee:ff");
    }
}
```

このコードでは、`{:02x}`というフォーマット指定子を使用しています。これは、16進数で2桁表示し、必要に応じて0で埋める指定です（例：`0a`のように表示されます）。

### Step 4: テスト実行（Green確認）

```bash
cargo test
```

期待される結果: 全テスト成功

```text
running 2 tests
test ethernet::tests::macアドレスを作成できる ... ok
test ethernet::tests::macアドレスを文字列表示できる ... ok

test result: ok. 2 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s
```

✅ Green！ すべてのテストが通りました。

### Step 5: リファクタリング（Refactor）

特になし。次へ進みましょう。

TODOリストを更新:

```text
MACアドレス
☑ MACアドレスを表現できる
☑ MACアドレスを文字列表示できる
□ ブロードキャストMACアドレスを作れる
```

---

## Iteration 3: ブロードキャストMACアドレスを作れる

### ブロードキャストアドレスとは？

ブロードキャストアドレス（`ff:ff:ff:ff:ff:ff`）は、同じネットワーク内のすべてのデバイスに対してメッセージを送信する際に使用される特別なMACアドレスです。

代表的な使用例：

- ARP（Address Resolution Protocol）：IPアドレスからMACアドレスを問い合わせる際に使用
- DHCP（Dynamic Host Configuration Protocol）：IPアドレスの割り当てリクエスト

### Step 1: テストを書く（Red）

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn macアドレスを作成できる() {
        let mac = MacAddress::new([0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
        assert_eq!(mac.bytes(), [0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
    }

    #[test]
    fn macアドレスを文字列表示できる() {
        let mac = MacAddress::new([0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]);
        assert_eq!(format!("{}", mac), "aa:bb:cc:dd:ee:ff");
    }

    #[test]
    fn ブロードキャストアドレスを作成できる() {
        let broadcast = MacAddress::broadcast();
        assert_eq!(broadcast.bytes(), [0xff, 0xff, 0xff, 0xff, 0xff, 0xff]);
    }
}
```

### Step 2: テスト実行（Red確認）

```bash
cargo test
```

期待される結果: コンパイルエラー

```text
error[E0599]: no function or associated item named `broadcast` found for struct `MacAddress` in the current scope
  --> src/ethernet.rs:XX:YY
   |
XX |         let broadcast = MacAddress::broadcast();
   |                                     ^^^^^^^^^ function or associated item not found in `MacAddress`
```

✅ Red！ 期待通りエラーが出ました。

### Step 3: テストを通す最小限のコード（Green）

```rust
impl MacAddress {
    pub fn new(bytes: [u8; 6]) -> Self {
        MacAddress { bytes }
    }

    pub fn bytes(&self) -> [u8; 6] {
        self.bytes
    }

    pub fn broadcast() -> Self {
        MacAddress {
            bytes: [0xff, 0xff, 0xff, 0xff, 0xff, 0xff],
        }
    }
}
```

### Step 4: テスト実行（Green確認）

```bash
cargo test
```

✅ Green！ 全テスト成功。

### Step 5: リファクタリング（Refactor）

ここでリファクタリングの機会があります。現在の実装では、`bytes`フィールドにアクセスするための`bytes()`メソッドが必要ですが、フィールドを公開してタプル構造体にすることで、よりシンプルにできます。

また、`[0xff; 6]`という配列リテラルを使うことで、繰り返しを避けられます。

リファクタリング前のテスト実行: ✅ 全部通る

リファクタリング:

```rust
use std::fmt;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct MacAddress(pub [u8; 6]);

impl MacAddress {
    pub fn new(bytes: [u8; 6]) -> Self {
        MacAddress(bytes)
    }

    pub fn broadcast() -> Self {
        MacAddress([0xff; 6])
    }
}

impl fmt::Display for MacAddress {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(
            f,
            "{:02x}:{:02x}:{:02x}:{:02x}:{:02x}:{:02x}",
            self.0[0], self.0[1], self.0[2], self.0[3], self.0[4], self.0[5]
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn macアドレスを作成できる() {
        let mac = MacAddress::new([0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
        assert_eq!(mac.0, [0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
    }

    #[test]
    fn macアドレスを文字列表示できる() {
        let mac = MacAddress::new([0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]);
        assert_eq!(format!("{}", mac), "aa:bb:cc:dd:ee:ff");
    }

    #[test]
    fn ブロードキャストアドレスを作成できる() {
        let broadcast = MacAddress::broadcast();
        assert_eq!(broadcast.0, [0xff; 6]);
    }
}
```

このリファクタリングにはいくつかの重要なポイントがあります。まず、タプル構造体（`MacAddress(pub [u8; 6])`）を使用することで、`.0`で直接バイト配列にアクセスできるようになります。次に、derive属性を使って複数のトレイトを自動実装しています。`Debug`トレイトは`{:?}`でのデバッグ出力を可能にし、`Clone`と`Copy`トレイトは値のコピーを簡単にし、`PartialEq`と`Eq`トレイトは`==`での比較を可能にします。最後に、配列リテラル`[0xff; 6]`を使うことで、同じ要素を繰り返す配列を簡潔に記述できます。

リファクタリング後のテスト実行:

```bash
cargo test
```

✅ 全テスト成功！ リファクタリング成功です。

TODOリストを更新:

```text
MACアドレス
☑ MACアドレスを表現できる
☑ MACアドレスを文字列表示できる
☑ ブロードキャストMACアドレスを作れる
```

---

## Phase 1のまとめ

このフェーズでは、以下を学びました：

### TDDのサイクルを体験

TDDの基本サイクルを実践しました。まずテストを書いて失敗を確認（Red）し、次に最小限のコードでテストを通し（Green）、最後にテストを保ったままコードを改善（Refactor）するという流れを体験しました。

### Rustの基本

Rustの基本的な機能を学びました。構造体の定義方法として、通常の構造体からタプル構造体へのリファクタリングを経験し、`Display`トレイトの実装方法を習得しました。また、derive属性を使って`Debug`、`Clone`、`Copy`、`PartialEq`、`Eq`トレイトを自動実装する方法も学びました。

### MACアドレスの理解

MACアドレスの本質的な特徴を理解しました。MACアドレスは6バイトの物理アドレスであり、ブロードキャストアドレスは`ff:ff:ff:ff:ff:ff`で表現されます。また、文字列表記では16進数でコロン区切りの形式を使用します。

---

## 次のステップ

Phase 1が完了しました！次は[Phase 2: Ethernetフレームパーサー](./phase2-ethernet-frame.md)に進みましょう。

Ethernetフレームは、MACアドレスを使ってデータを送受信するための基本単位です。同じTDDのリズムで実装していきます。

---

## ナビゲーション

- 前へ：[概要とTDD基礎](./index.md)
- 次へ：[Phase 2: Ethernetフレームパーサー](./phase2-ethernet-frame.md)
- ホーム：[README](../README.md)
