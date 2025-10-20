# RustでTCP/IPスタックをt-wada流TDDで実装する

このハンズオンでは、TDD（テスト駆動開発）のプロセスを体験します。完成したコードを見るのではなく、Red → Green → Refactor のサイクルを一歩ずつ進めていきます。

## TDDの心構え

```text
「動作するきれいなコード」がゴール。
でも一度には作らない。

1. まず「動作する」を作る（テストを通す）
2. 次に「きれい」にする（リファクタリング）

この順番を守る。
```

## TDDのサイクル

```text
1. TODOリストを書く（頭の整理）
2. テストを一つだけ選んで書く（Red）
3. テストを実行して、失敗することを確認（Red確認）
4. テストを通す最小限のコードを書く（Green）
5. テストを実行して、成功を確認（Green確認）
6. リファクタリング（Refactor）
7. すべてのテストを実行して、壊れていないことを確認
8. 次のテストへ戻る
```

## 環境セットアップ

ライブラリプロジェクトとして作成する場合:

```bash
cargo new rust-tcp-stack --lib
cd rust-tcp-stack
```

バイナリプロジェクトとして作成する場合:

```bash
cargo new rust-tcp-stack
cd rust-tcp-stack
```

**注意**: ライブラリプロジェクトの場合は`src/lib.rs`、バイナリプロジェクトの場合は`src/main.rs`がエントリーポイントになります。

新しいモジュール（`ethernet.rs`など）を追加したら、必ずエントリーポイントに`mod モジュール名;`を追加する必要があります。

Cargo.toml:

```toml
[package]
name = "rust-tcp-stack"
version = "0.1.0"
edition = "2021"

[dependencies]

[dev-dependencies]
```

## Phase 1: MACアドレス実装（TDDで）

### TODOリスト（Phase 1）

```text
MACアドレス
□ MACアドレスを表現できる
□ MACアドレスを文字列表示できる
□ ブロードキャストMACアドレスを作れる
```

### Iteration 1: MACアドレスを表現できる

#### Step 1: テストを書く（Red）

src/ethernet.rsを作成:

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

**重要**: モジュールを認識させるために、プロジェクトのエントリーポイントでモジュール宣言が必要です。

- ライブラリプロジェクト（`cargo new --lib`）の場合、src/lib.rs:

```rust
pub mod ethernet;
```

- バイナリプロジェクト（`cargo new`）の場合、src/main.rs:

```rust
mod ethernet;

fn main() {
    println!("Hello, world!");
}
```

#### Step 2: テスト実行（Red確認）

```bash
cargo test
```

期待される結果: コンパイルエラー（MacAddressが存在しない）

```text
error[E0425]: cannot find type `MacAddress` in this scope
```

✅ これでいい！テストが失敗することを確認した。

#### Step 3: テストを通す最小限のコード（Green）

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

#### Step 4: テスト実行（Green確認）

```bash
cargo test
```

期待される結果: テスト成功

```text
running 1 test
test ethernet::tests::macアドレスを作成できる ... ok
```

✅ Green！ テストが通った。

#### Step 5: リファクタリング（Refactor）

今の段階では特にリファクタリングの必要はない。次へ。

TODOリストを更新:

```text
MACアドレス
☑ MACアドレスを表現できる
□ MACアドレスを文字列表示できる
□ ブロードキャストMACアドレスを作れる
```

### Iteration 2: MACアドレスを文字列表示できる

#### Step 1: テストを書く（Red）

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

#### Step 2: テスト実行（Red確認）

```bash
cargo test
```

期待される結果: コンパイルエラー（Displayトレイトが実装されていない）

```text
error[E0277]: `MacAddress` doesn't implement `std::fmt::Display`
```

✅ Red！

#### Step 3: テストを通す最小限のコード（Green）

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

#### Step 4: テスト実行（Green確認）

```bash
cargo test
```

期待される結果: 全テスト成功

```text
running 2 tests
test ethernet::tests::macアドレスを作成できる ... ok
test ethernet::tests::macアドレスを文字列表示できる ... ok
```

✅ Green！

#### Step 5: リファクタリング（Refactor）

特になし。次へ。

TODOリストを更新:

```text
MACアドレス
☑ MACアドレスを表現できる
☑ MACアドレスを文字列表示できる
□ ブロードキャストMACアドレスを作れる
```

### Iteration 3: ブロードキャストMACアドレスを作れる

#### Step 1: テストを書く（Red）

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

#### Step 2: テスト実行（Red確認）

```bash
cargo test
```

期待される結果: コンパイルエラー

```text
error[E0599]: no function or associated item named `broadcast` found for struct `MacAddress`
```

✅ Red！

#### Step 3: テストを通す最小限のコード（Green）

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

#### Step 4: テスト実行（Green確認）

```bash
cargo test
```

✅ Green！ 全テスト成功。

#### Step 5: リファクタリング（Refactor）

ここでリファクタリングの機会：`bytes`フィールドを公開して、`bytes()`メソッドを削除できる。

リファクタリング前のテスト実行: ✅ 全部通る

リファクタリング:

```rust
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

リファクタリング後のテスト実行:

```bash
cargo test
```

✅ 全テスト成功！ リファクタリング成功。

TODOリストを更新:

```text
MACアドレス
☑ MACアドレスを表現できる
☑ MACアドレスを文字列表示できる
☑ ブロードキャストMACアドレスを作れる
```

---

## Phase 2: Ethernetフレームパーサー（TDDで）

### TODOリスト（Phase 2）

```text
Ethernetフレームパーサー
□ 14バイト未満のデータは拒否する
□ 14バイト以上のデータは受け入れる
□ 宛先MACアドレスを取得できる
□ 送信元MACアドレスを取得できる
□ EtherTypeを取得できる
□ ペイロードを取得できる
```

### Iteration 4: 14バイト未満のデータは拒否する

#### Step 1: テストを書く（Red）

src/ethernet.rsに追加:

```rust
pub struct EthernetFrame<'a> {
    data: &'a [u8],
}

impl<'a> EthernetFrame<'a> {
    pub fn new(data: &'a [u8]) -> Option<Self> {
        // まだ実装しない
        todo!()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // ... 既存のMACアドレステスト ...

    #[test]
    fn ethernetフレームは14バイト未満を拒否する() {
        let short_data = [0u8; 13];
        assert!(EthernetFrame::new(&short_data).is_none());
    }
}
```

#### Step 2: テスト実行（Red確認）

```bash
cargo test ethernetフレームは14バイト未満を拒否する
```

期待される結果: `todo!()`でパニック

```text
thread 'ethernet::tests::ethernetフレームは14バイト未満を拒否する' panicked at 'not yet implemented'
```

✅ Red！

#### Step 3: テストを通す最小限のコード（Green）

```rust
impl<'a> EthernetFrame<'a> {
    pub fn new(data: &'a [u8]) -> Option<Self> {
        if data.len() < 14 {
            return None;
        }
        Some(EthernetFrame { data })
    }
}
```

#### Step 4: テスト実行（Green確認）

```bash
cargo test ethernetフレームは14バイト未満を拒否する
```

✅ Green！

TODOリストを更新:

```text
Ethernetフレームパーサー
☑ 14バイト未満のデータは拒否する
□ 14バイト以上のデータは受け入れる
□ 宛先MACアドレスを取得できる
...
```

### Iteration 5: 14バイト以上のデータは受け入れる

#### Step 1: テストを書く（Red）

```rust
#[test]
fn ethernetフレームは14バイト以上を受け入れる() {
    let valid_data = [0u8; 14];
    assert!(EthernetFrame::new(&valid_data).is_some());
}
```

#### Step 2: テスト実行（Red確認）

```bash
cargo test ethernetフレームは14バイト以上を受け入れる
```

実はこれは通ってしまう！

```text
test ethernet::tests::ethernetフレームは14バイト以上を受け入れる ... ok
```

これは、前のテストを通すために書いたコードが、このテストも通してしまったケース。これでOK！

✅ テストが既にGreen。次へ。

### Iteration 6: 宛先MACアドレスを取得できる

#### Step 1: テストを書く（Red）

```rust
#[test]
fn 宛先macアドレスを取得できる() {
    let mut data = [0u8; 14];
    data[0..6].copy_from_slice(&[0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]);
    
    let frame = EthernetFrame::new(&data).unwrap();
    let expected = MacAddress::new([0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]);
    assert_eq!(frame.destination(), expected);
}
```

#### Step 2: テスト実行（Red確認）

```bash
cargo test 宛先macアドレスを取得できる
```

期待される結果: コンパイルエラー

```text
error[E0599]: no method named `destination` found for struct `EthernetFrame`
```

✅ Red！

#### Step 3: テストを通す最小限のコード（Green）

```rust
impl<'a> EthernetFrame<'a> {
    pub fn new(data: &'a [u8]) -> Option<Self> {
        if data.len() < 14 {
            return None;
        }
        Some(EthernetFrame { data })
    }

    pub fn destination(&self) -> MacAddress {
        let mut bytes = [0u8; 6];
        bytes.copy_from_slice(&self.data[0..6]);
        MacAddress(bytes)
    }
}
```

#### Step 4: テスト実行（Green確認）

```bash
cargo test
```

✅ Green！ 全テスト成功。

---

## TDDの重要ポイント

ここまでで、TDDの本質が見えてきたはずです：

### 1. 小さく進む

一度に全部を実装しない。一つのテストケースだけに集中する。

### 2. Red → Green → Refactor のリズム

- Red: テストを書いて失敗を確認（コンパイルエラーも"Red"）
- Green: そのテストだけを通す最小限のコード
- Refactor: テストを保ったままコードをきれいにする

### 3. 「最小限」の実装

例えば、こんなコードでもいい（実際のTDDではよくやる）：

```rust
// 最初のテストを通すための「仮実装」
pub fn broadcast() -> Self {
    MacAddress([0xff, 0xff, 0xff, 0xff, 0xff, 0xff])  // ベタ書き
}

// 次のテストで一般化が必要になったら、その時リファクタリング
```

### 4. TODOリストは生きている

テストを書いていて気づいたことは、すぐにTODOリストに追加する。

---

## 続きの実装（同じパターンで）

### 進捗確認

```text
Ethernetフレームパーサー
☑ 14バイト未満のデータは拒否する
☑ 14バイト以上のデータは受け入れる
☑ 宛先MACアドレスを取得できる
□ 送信元MACアドレスを取得できる
□ EtherTypeを取得できる
□ ペイロードを取得できる
```

### Iteration 7-9: あなたの番

以下のテストを一つずつ、Red → Green → Refactor で実装してください：

#### Iteration 7: 送信元MACアドレスを取得できる

```rust
#[test]
fn 送信元macアドレスを取得できる() {
    let mut data = [0u8; 14];
    data[6..12].copy_from_slice(&[0x11, 0x22, 0x33, 0x44, 0x55, 0x66]);
    
    let frame = EthernetFrame::new(&data).unwrap();
    let expected = MacAddress::new([0x11, 0x22, 0x33, 0x44, 0x55, 0x66]);
    assert_eq!(frame.source(), expected);
}
```

ヒント: `destination()`と同じパターンで実装できます。

#### Iteration 8: EtherTypeを取得できる

まずEtherType型を定義する必要があります。

Step 1: テストを書く（Red）:

```rust
#[test]
fn ethertypeがipv4の場合() {
    let mut data = [0u8; 14];
    data[12] = 0x08;
    data[13] = 0x00;
    
    let frame = EthernetFrame::new(&data).unwrap();
    // まだEtherType型がないのでコンパイルエラーになる
    assert_eq!(frame.ether_type(), EtherType::Ipv4);
}
```

Step 2: 最小限の実装:

```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EtherType {
    Ipv4,
}

impl<'a> EthernetFrame<'a> {
    // ... 既存のメソッド ...
    
    pub fn ether_type(&self) -> EtherType {
        EtherType::Ipv4  // とりあえずこれで通る
    }
}
```

Step 3: 次のテストを追加して一般化:

```rust
#[test]
fn ethertypeがarpの場合() {
    let mut data = [0u8; 14];
    data[12] = 0x08;
    data[13] = 0x06;
    
    let frame = EthernetFrame::new(&data).unwrap();
    assert_eq!(frame.ether_type(), EtherType::Arp);
}
```

これで初めて、実際にバイト列を読む実装が必要になります。

#### Iteration 9: ペイロードを取得できる

```rust
#[test]
fn ペイロードを取得できる() {
    let mut data = vec![0u8; 20];
    data[14..20].copy_from_slice(b"Hello!");
    
    let frame = EthernetFrame::new(&data).unwrap();
    assert_eq!(frame.payload(), b"Hello!");
}
```

---

## Phase 3: IPv4パケットパーサー（TDDで）

### TODOリスト（Phase 3）

```text
IPv4パケットパーサー
□ 20バイト未満のデータは拒否する
□ バージョン4以外は拒否する
□ 20バイト以上のバージョン4データは受け入れる
□ 送信元IPアドレスを取得できる
□ 宛先IPアドレスを取得できる
□ プロトコルを取得できる
□ ヘッダー長を取得できる
□ ペイロードを取得できる
□ チェックサムを計算できる
□ チェックサムを検証できる
```

src/ipv4.rsを作成:

```rust
use std::net::Ipv4Addr;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ipv4パケットは20バイト未満を拒否する() {
        let short_data = [0u8; 19];
        assert!(Ipv4Packet::new(&short_data).is_none());
    }
}
```

**重要**: `ipv4`モジュールも同様に宣言が必要です。

- ライブラリプロジェクトの場合、src/lib.rs:

```rust
pub mod ethernet;
pub mod ipv4;
```

- バイナリプロジェクトの場合、src/main.rs:

```rust
mod ethernet;
mod ipv4;

fn main() {
    println!("Hello, world!");
}
```

### あなたの番：Iteration 10-19

同じTDDサイクルで、IPv4パケットパーサーを実装してください。

重要なヒント:

1. 一つずつ進める
2. テストが失敗することを必ず確認する
3. そのテストだけを通す最小限のコード
4. 全テストを実行して壊れていないか確認
5. リファクタリングのチャンスがあれば実施

---

## Phase 4: TCPパケットパーサー（TDDで）

### TODOリスト（Phase 4）

```text
TCPパケットパーサー
□ 20バイト未満のデータは拒否する
□ 20バイト以上のデータは受け入れる
□ 送信元ポート番号を取得できる
□ 宛先ポート番号を取得できる
□ シーケンス番号を取得できる
□ 確認応答番号を取得できる
□ SYNフラグを判定できる
□ ACKフラグを判定できる
□ FINフラグを判定できる
□ ウィンドウサイズを取得できる
□ ペイロードを取得できる
□ チェックサムを計算できる（疑似ヘッダー含む）
□ チェックサムを検証できる
```

src/tcp.rsを作成して、同じようにTDDで進めてください。

**重要**: `tcp`モジュールも忘れずに宣言してください。

- ライブラリプロジェクトの場合、src/lib.rs:

```rust
pub mod ethernet;
pub mod ipv4;
pub mod tcp;
```

- バイナリプロジェクトの場合、src/main.rs:

```rust
mod ethernet;
mod ipv4;
mod tcp;

fn main() {
    println!("Hello, world!");
}
```

---

## Phase 5: パケットビルダー（TDDで）

パーサーができたら、今度はパケットを作る機能をTDDで実装します。

### TODOリスト（Phase 5）

```text
Ethernetフレームビルダー
□ ヘッダーのみのフレームを構築できる
□ ペイロード付きフレームを構築できる
□ 構築したフレームをパースして検証できる
```

### Iteration 20: ヘッダーのみのフレームを構築できる

#### Step 1: テストを書く（Red）

```rust
#[test]
fn ethernetフレームを構築できる() {
    let src = MacAddress::new([0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
    let dst = MacAddress::broadcast();
    
    let builder = EthernetFrameBuilder::new(dst, src, EtherType::Ipv4);
    let frame_bytes = builder.build();
    
    assert_eq!(frame_bytes.len(), 14);
}
```

#### Step 2-5: Red → Green → Refactor

あなたの番です！

---

## 完全なTDDサイクルの実践例

### 実際のTDDの様子を見てみましょう

チェックサム計算機能を例に、完全なTDDサイクルを示します。

#### TODOリスト

```text
チェックサム計算
□ 空データのチェックサムは0xffffになる
□ 単純なデータのチェックサムを計算できる
□ 16ビット境界のデータを扱える
□ キャリーを折り返せる
□ 奇数長データを扱える
```

#### Iteration: 空データのチェックサム

Red: テストを書く

```rust
#[test]
fn 空データのチェックサムは0xffffになる() {
    let data = [];
    assert_eq!(calculate_checksum(&data), 0xffff);
}
```

Red確認: 実行

```bash
cargo test 空データのチェックサムは0xffffになる
# エラー: calculate_checksum関数が存在しない
```

Green: 最小限の実装

```rust
pub fn calculate_checksum(data: &[u8]) -> u16 {
    0xffff  // ベタ書き！これで最初のテストは通る
}
```

Green確認: 実行

```bash
cargo test 空データのチェックサムは0xffffになる
# 成功！
```

Refactor: 今のところ不要

#### Iteration: 単純なデータ

Red: テストを追加

```rust
#[test]
fn 単純なデータのチェックサム() {
    let data = [0x00, 0x01];
    assert_eq!(calculate_checksum(&data), 0xfffe);
}
```

Red確認: 実行

```bash
cargo test 単純なデータのチェックサム
# 失敗: expected 0xfffe, got 0xffff
```

✅ 失敗を確認した！

Green: 実装を一般化

```rust
pub fn calculate_checksum(data: &[u8]) -> u16 {
    if data.is_empty() {
        return 0xffff;
    }
    
    let mut sum: u32 = 0;
    
    for i in (0..data.len()).step_by(2) {
        let word = if i + 1 < data.len() {
            u16::from_be_bytes([data[i], data[i + 1]]) as u32
        } else {
            (data[i] as u32) << 8
        };
        sum += word;
    }
    
    !sum as u16
}
```

Green確認: 全テスト実行

```bash
cargo test
# 全部通る！
```

Refactor: まだ不要

#### Iteration: キャリーを折り返す

Red: テストを追加

```rust
#[test]
fn キャリーを折り返せる() {
    let data = [0xff, 0xff, 0xff, 0xff];
    assert_eq!(calculate_checksum(&data), 0x0000);
}
```

Red確認: 実行

```bash
cargo test キャリーを折り返せる
# 失敗！キャリーが処理されていない
```

Green: キャリー処理を追加

```rust
pub fn calculate_checksum(data: &[u8]) -> u16 {
    if data.is_empty() {
        return 0xffff;
    }
    
    let mut sum: u32 = 0;
    
    for i in (0..data.len()).step_by(2) {
        let word = if i + 1 < data.len() {
            u16::from_be_bytes([data[i], data[i + 1]]) as u32
        } else {
            (data[i] as u32) << 8
        };
        sum += word;
    }
    
    // キャリーを折り返す
    while (sum >> 16) != 0 {
        sum = (sum & 0xffff) + (sum >> 16);
    }
    
    !sum as u16
}
```

Green確認

```bash
cargo test
# 全部通る！
```

---

## TDDのメリットを実感する瞬間

### 1. リファクタリングの安心感

全テストが通っているので、自信を持ってコードを変更できる。

### 2. 設計へのフィードバック

テストを書きながら「このAPIは使いにくい」と気づける。

例：

```rust
// 使いにくい
let packet = Ipv4Packet::new(&data).unwrap();
packet.verify_checksum(src_ip, dst_ip);  // IPアドレスが必要...

// テストを書いていて気づく
// → 設計を改善
```

### 3. 実装の進捗が明確

TODOリストにチェックが入っていくことで、確実に前進している実感。

### 4. バグの早期発見

新しいテストを追加したら既存のテストが壊れた → 設計ミスに気づける。

---

## 統合テスト（TDDで）

最後に、スタック全体をつなげるテストをTDDで書きます。

### TODOリスト（統合テスト）

```text
統合テスト
□ Ethernet → IPv4 → TCP とパースできる
□ 逆順（TCP → IPv4 → Ethernet）で構築できる
□ 構築とパースの往復で同じになる
□ 3-way handshakeをシミュレートできる
```

### Iteration: Ethernet → IPv4 → TCP とパースできる

tests/integration_test.rsを作成:

```rust
use rust_tcp_tdd::ethernet::{EthernetFrame, MacAddress, EtherType};
use rust_tcp_tdd::ipv4::{Ipv4Packet, IpProtocol};
use rust_tcp_tdd::tcp::TcpPacket;
use std::net::Ipv4Addr;

#[test]
fn スタック全体をパースできる() {
    // 実際のパケットバイト列（手動で構築）
    let packet = [
        // Ethernet header
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff,  // Dst MAC
        0x00, 0x11, 0x22, 0x33, 0x44, 0x55,  // Src MAC
        0x08, 0x00,                          // EtherType: IPv4
        // IPv4 header
        0x45, 0x00, 0x00, 0x28,              // Version, IHL, Length
        // ... (省略) ...
    ];
    
    // Ethernetパース
    let eth = EthernetFrame::new(&packet).unwrap();
    assert_eq!(eth.ether_type(), EtherType::Ipv4);
    
    // IPv4パース
    let ip = Ipv4Packet::new(eth.payload()).unwrap();
    assert_eq!(ip.protocol(), IpProtocol::Tcp);
    
    // TCPパース
    let tcp = TcpPacket::new(ip.payload()).unwrap();
    assert_eq!(tcp.destination_port(), 80);
}
```

このテストをGreenにするために、各レイヤーを実装していく。

---

## まとめ：t-wada流TDDの本質

### 1. 小さく、速く

一度に完璧を目指さない。一つのテストだけに集中。

### 2. サイクルを守る

Red → Green → Refactor のサイクルを守ることで、「動作する」と「きれい」を両立。

### 3. TODOリストは羅針盤

迷ったらTODOリストを見る。次に何をすべきか明確。

### 4. テストは「動く仕様書」

コードの使い方と振る舞いがテストに書かれている。

### 5. 最小限の実装から始める

「ベタ書き」でも最初はOK。次のテストで一般化すればいい。

---

## 次のステップ

このハンズオンを完了したら：

1. TUN/TAPデバイスをTDDで実装
2. TCP状態機械をTDDで実装
3. 実際のエコーサーバーをTDDで実装
4. 既存のコードをTDDでリファクタリング

---

## 参考資料

- Kent Beck『テスト駆動開発』（オーム社） - 必読
- t-wadaさんのブログ「テスト駆動開発の定義」
- TDD Boot Camp の動画・資料

---

## 付録: よくある間違い

### ❌ 間違い1: テストを先にたくさん書く

```rust
// これはTDDではない
#[test] fn test1() { ... }
#[test] fn test2() { ... }
#[test] fn test3() { ... }
// ↑ 全部書いてから実装開始
```

✅ 正しい: 一つ書いて、実装して、次のテストへ。

### ❌ 間違い2: 実装を先に書いてからテスト

```rust
// 実装してからテストを書くのはTDDではない
pub fn my_function() { ... }

#[test]
fn test_my_function() { ... }
```

✅ 正しい: テストファースト。テストが先。

### ❌ 間違い3: Redを確認しない

「このテストは失敗するはず」と思い込んで実行せずに実装開始。

✅ 正しい: 必ず実行してRedを確認する。

### ❌ 間違い4: 大きく作りすぎる

「将来必要になりそうだから」と、今のテストに不要な機能を実装。

✅ 正しい: そのテストだけを通す最小限のコード。YAGNI（You Aren't Gonna Need It）。

---

## TDDは「技」である

TDDは知識ではなく技術です。

読むだけでは身につかない。
実際に手を動かして、Red → Green → Refactor のリズムを体で覚える。

さあ、始めましょう！

最初は慣れなくて遅く感じるかもしれません。
でも、続けていくうちに、不安なくコードを書ける感覚が身についてきます。

それがTDDの最大の価値です。
