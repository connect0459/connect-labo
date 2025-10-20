# Phase 3: IPv4パケットパーサー（TDDで）

## このフェーズで学ぶこと

このフェーズでは、IPv4プロトコルの構造と役割について学びます。具体的には、IPアドレスの扱い方を習得し、ヘッダー長の可変性への対応方法を理解します。また、チェックサムの計算と検証の実装を通じて、TDDでの複雑なロジックの構築方法を学びます。

---

## IPv4とは？

IPv4（Internet Protocol version 4）は、インターネット層で使用されるプロトコルで、異なるネットワーク間でデータを転送するための仕組みを提供します。

### IPv4の役割

1. アドレッシング: IPアドレスによるデバイスの識別
2. ルーティング: パケットを宛先まで届けるための経路選択
3. フラグメンテーション: パケットの分割と再構成
4. エラー検出: チェックサムによるヘッダーの整合性確認

### IPアドレスとは？

IPアドレスは、ネットワーク上のデバイスを識別するための論理的なアドレスです。

- 長さ: 32ビット（4バイト）
- 表記: ドット区切りの10進数（例：`192.168.1.1`）
- 構成: ネットワーク部 + ホスト部

MACアドレスとの違い：

- MACアドレス: 物理アドレス、同じネットワーク内の識別
- IPアドレス: 論理アドレス、異なるネットワーク間の識別

---

## IPv4パケットの構造

```text
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|Version|  IHL  |Type of Service|          Total Length         |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|         Identification        |Flags|      Fragment Offset    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|  Time to Live |    Protocol   |         Header Checksum       |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                       Source Address                          |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                    Destination Address                        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                    Options (可変長)                            |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                            Payload                            |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### 主要フィールド

1. Version（4ビット）: プロトコルバージョン（IPv4の場合は`4`）
2. IHL（Internet Header Length, 4ビット）: ヘッダー長（32ビットワード単位、最小値5 = 20バイト）
3. Total Length（16ビット）: パケット全体の長さ（ヘッダー + データ）
4. Protocol（8ビット）: 上位層のプロトコル（例：TCP=6, UDP=17, ICMP=1）
5. Header Checksum（16ビット）: ヘッダーの整合性確認
6. Source Address（32ビット）: 送信元IPアドレス
7. Destination Address（32ビット）: 宛先IPアドレス

### チェックサムとは？

チェックサム（Checksum）は、データの整合性を確認するための値です。送信時に計算し、受信時に再計算して一致するかを確認します。

IPv4のチェックサム計算：

1. ヘッダーを16ビットワードに分割
2. すべてを加算（桁あふれは折り返し）
3. 1の補数を取る

---

## プロトコル番号

IPv4の`Protocol`フィールドは、ペイロードに含まれる上位層のプロトコルを識別します。

| 値 | プロトコル | 説明 |
|----|----------|------|
| 1 | ICMP | Internet Control Message Protocol（ping等） |
| 6 | TCP | Transmission Control Protocol |
| 17 | UDP | User Datagram Protocol |

---

## TODOリスト（Phase 3）

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

---

## モジュールのセットアップ

`src/ipv4.rs`を作成します。

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

重要: モジュール宣言を忘れずに！

### ライブラリプロジェクトの場合（src/lib.rs）

```rust
pub mod ethernet;
pub mod ipv4;
```

### バイナリプロジェクトの場合（src/main.rs）

```rust
mod ethernet;
mod ipv4;

fn main() {
    println!("Hello, world!");
}
```

---

## Iteration 10: 20バイト未満のデータは拒否する

### Step 1-4: Red → Green

```rust
pub struct Ipv4Packet<'a> {
    data: &'a [u8],
}

impl<'a> Ipv4Packet<'a> {
    pub fn new(data: &'a [u8]) -> Option<Self> {
        if data.len() < 20 {
            return None;
        }
        Some(Ipv4Packet { data })
    }
}
```

---

## Iteration 11: バージョン4以外は拒否する

IPv4パケットは、最初の4ビットが`4`である必要があります。

### Step 1: テストを書く（Red）

```rust
#[test]
fn バージョンが4でない場合は拒否する() {
    let mut data = [0u8; 20];
    data[0] = 0x60; // バージョン6（IPv6）
    assert!(Ipv4Packet::new(&data).is_none());
}
```

### Step 2-4: Red → Green

```rust
impl<'a> Ipv4Packet<'a> {
    pub fn new(data: &'a [u8]) -> Option<Self> {
        if data.len() < 20 {
            return None;
        }

        let version = data[0] >> 4;
        if version != 4 {
            return None;
        }

        Some(Ipv4Packet { data })
    }
}
```

この実装では、ビット演算を使ってバージョンフィールドを取得しています。`data[0] >> 4`という記法で上位4ビットを取得できます。ここでの`>>`は右シフト演算子です。

---

## Iteration 12: 送信元・宛先IPアドレスを取得できる

### Step 1: テストを書く（Red）

```rust
#[test]
fn 送信元ipアドレスを取得できる() {
    let mut data = [0u8; 20];
    data[0] = 0x45; // バージョン4, IHL=5
    data[12..16].copy_from_slice(&[192, 168, 1, 1]);

    let packet = Ipv4Packet::new(&data).unwrap();
    assert_eq!(packet.source(), Ipv4Addr::new(192, 168, 1, 1));
}

#[test]
fn 宛先ipアドレスを取得できる() {
    let mut data = [0u8; 20];
    data[0] = 0x45; // バージョン4, IHL=5
    data[16..20].copy_from_slice(&[10, 0, 0, 1]);

    let packet = Ipv4Packet::new(&data).unwrap();
    assert_eq!(packet.destination(), Ipv4Addr::new(10, 0, 0, 1));
}
```

### Step 2-4: Red → Green

```rust
use std::net::Ipv4Addr;

impl<'a> Ipv4Packet<'a> {
    // ... 既存のメソッド ...

    pub fn source(&self) -> Ipv4Addr {
        Ipv4Addr::new(
            self.data[12],
            self.data[13],
            self.data[14],
            self.data[15],
        )
    }

    pub fn destination(&self) -> Ipv4Addr {
        Ipv4Addr::new(
            self.data[16],
            self.data[17],
            self.data[18],
            self.data[19],
        )
    }
}
```

この実装には3つのポイントがあります。まず、Rustの標準ライブラリで提供される`Ipv4Addr`型を使用しています。また、送信元アドレスは12〜15バイト目、宛先アドレスは16〜19バイト目に位置するというIPv4ヘッダーの仕様に従っています。

---

## Iteration 13: プロトコルを取得できる

### Step 1: テストを書く（Red）

```rust
#[test]
fn プロトコルがtcpの場合() {
    let mut data = [0u8; 20];
    data[0] = 0x45;
    data[9] = 6; // TCP

    let packet = Ipv4Packet::new(&data).unwrap();
    assert_eq!(packet.protocol(), IpProtocol::Tcp);
}
```

### Step 2-4: Red → Green

```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum IpProtocol {
    Icmp,
    Tcp,
    Udp,
    Unknown(u8),
}

impl<'a> Ipv4Packet<'a> {
    pub fn protocol(&self) -> IpProtocol {
        match self.data[9] {
            1 => IpProtocol::Icmp,
            6 => IpProtocol::Tcp,
            17 => IpProtocol::Udp,
            n => IpProtocol::Unknown(n),
        }
    }
}
```

---

## Iteration 14: ヘッダー長を取得・ペイロードを取得

### ヘッダー長（IHL）とは？

IPv4ヘッダーは可変長です。IHL（Internet Header Length）フィールドは、ヘッダー長を32ビットワード（4バイト）単位で示します。

- IHL=5 → 5 × 4 = 20バイト（最小）
- IHL=6 → 6 × 4 = 24バイト（オプション4バイト）

### Step 1: テストを書く（Red）

```rust
#[test]
fn ヘッダー長を取得できる() {
    let mut data = [0u8; 20];
    data[0] = 0x45; // バージョン4, IHL=5

    let packet = Ipv4Packet::new(&data).unwrap();
    assert_eq!(packet.header_length(), 20);
}

#[test]
fn ペイロードを取得できる() {
    let mut data = vec![0u8; 30];
    data[0] = 0x45; // IHL=5 → ヘッダー20バイト
    data[20..30].copy_from_slice(b"HelloWorld");

    let packet = Ipv4Packet::new(&data).unwrap();
    assert_eq!(packet.payload(), b"HelloWorld");
}
```

### Step 2-4: Red → Green

```rust
impl<'a> Ipv4Packet<'a> {
    pub fn header_length(&self) -> usize {
        let ihl = self.data[0] & 0x0f; // 下位4ビット
        (ihl as usize) * 4
    }

    pub fn payload(&self) -> &[u8] {
        let header_len = self.header_length();
        &self.data[header_len..]
    }
}
```

ヘッダー長の取得には、ビット演算を使用します。`data[0] & 0x0f`という記法で下位4ビット（IHLフィールド）を取得できます。ここでの`&`はAND演算子です。

---

## Iteration 15: チェックサムを計算・検証

### チェックサム計算の実装

チェックサムは、ヘッダーの整合性を確認するための重要な仕組みです。

### Step 1: テストを書く（Red）

```rust
#[test]
fn チェックサムを計算できる() {
    let data = vec![
        0x45, 0x00, 0x00, 0x28, // Version, IHL, ToS, Total Length
        0x00, 0x00, 0x00, 0x00, // Identification, Flags, Fragment Offset
        0x40, 0x06, 0x00, 0x00, // TTL, Protocol, Checksum (0で初期化)
        0xc0, 0xa8, 0x01, 0x01, // Source IP
        0xc0, 0xa8, 0x01, 0x02, // Destination IP
    ];

    let checksum = calculate_ipv4_checksum(&data);
    // 正しいチェックサム値を検証
    assert_ne!(checksum, 0);
}
```

### Step 2-4: Red → Green

```rust
pub fn calculate_ipv4_checksum(header: &[u8]) -> u16 {
    let mut sum: u32 = 0;

    // 16ビットワードごとに加算
    for i in (0..header.len()).step_by(2) {
        let word = if i + 1 < header.len() {
            u16::from_be_bytes([header[i], header[i + 1]]) as u32
        } else {
            (header[i] as u32) << 8
        };
        sum += word;
    }

    // キャリーを折り返す
    while (sum >> 16) != 0 {
        sum = (sum & 0xffff) + (sum >> 16);
    }

    // 1の補数を取る
    !(sum as u16)
}
```

チェックサム計算には3つの重要なステップがあります。まず、ヘッダーを16ビットワード単位で加算します。次に、キャリーの折り返しを行います。これは16ビットを超えた部分を下位に加算する処理です。最後に、1の補数を取ります。これはビット反転（`!`演算子）で実現できます。

### チェックサム検証

```rust
impl<'a> Ipv4Packet<'a> {
    pub fn verify_checksum(&self) -> bool {
        let header_len = self.header_length();
        let checksum = calculate_ipv4_checksum(&self.data[..header_len]);
        checksum == 0 // チェックサム含めて計算すると0になる
    }
}
```

---

## Phase 3のまとめ

このフェーズでは、以下を学びました：

### IPv4の理解

IPv4プロトコルの重要な特徴を学びました。IPアドレスによる論理的なアドレッシングの仕組みを理解し、可変長ヘッダー（IHL）の扱い方を習得しました。また、プロトコル番号による上位層の識別方法と、チェックサムによる整合性確認の重要性を学びました。

### Rustの機能

Rustの低レベルプログラミングに必要な機能を習得しました。ビット演算（`>>`、`<<`、`&`）の使い方を学び、標準ライブラリの`Ipv4Addr`型を活用しました。また、`u16::from_be_bytes`による数値変換の方法も理解しました。

### TDDの実践

TDDで複雑なロジックを構築する方法を実践しました。チェックサムのような複雑な計算処理も、TDDで段階的に構築することで確実に実装できることを体験しました。また、テストが仕様を文書化する役割を果たすことを再確認しました。

---

## 次のステップ

Phase 3が完了しました！次は[Phase 4: TCPパケットパーサー](./phase4-tcp-packet.md)に進みましょう。

TCPはトランスポート層のプロトコルで、信頼性のあるデータ転送を実現します。接続確立（3-wayハンドシェイク）、フロー制御、再送制御など、より高度な機能を持っています。

---

## ナビゲーション

- 前へ：[Phase 2: Ethernetフレームパーサー](./phase2-ethernet-frame.md)
- 次へ：[Phase 4: TCPパケットパーサー](./phase4-tcp-packet.md)
- ホーム：[README](../README.md)
