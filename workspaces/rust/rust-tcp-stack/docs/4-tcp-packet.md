# Phase 4: TCPパケットパーサー（TDDで）

## このフェーズで学ぶこと

このフェーズでは、TCPプロトコルの構造と役割について学びます。具体的には、SYN、ACK、FINなどのフラグの扱い方を習得し、疑似ヘッダーを使ったチェックサム計算の実装方法を理解します。また、3-wayハンドシェイクの仕組みを学びます。

---

## TCPとは？

TCP（Transmission Control Protocol）は、トランスポート層で使用されるプロトコルで、信頼性のあるデータ転送を実現します。

### TCPの主な特徴

1. コネクション型: 通信前に接続を確立
2. 信頼性: データの到達を保証（再送制御）
3. 順序保証: パケットの順序を保証
4. フロー制御: 受信側の処理能力に応じて送信速度を調整
5. 輻輳制御: ネットワークの混雑を回避

UDPとの違い：

- TCP: 信頼性重視、オーバーヘッドあり（Web、メール、ファイル転送等）
- UDP: 速度重視、オーバーヘッド小（動画ストリーミング、ゲーム等）

---

## TCPセグメントの構造

```text
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|          Source Port          |       Destination Port        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                        Sequence Number                        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                    Acknowledgment Number                      |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|  Data |           |U|A|P|R|S|F|                               |
| Offset| Reserved  |R|C|S|S|Y|I|            Window             |
|       |           |G|K|H|T|N|N|                               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|           Checksum            |         Urgent Pointer        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                    Options (可変長)                            |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                             Data                              |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### 主要フィールド

1. Source Port（16ビット）: 送信元ポート番号
2. Destination Port（16ビット）: 宛先ポート番号
3. Sequence Number（32ビット）: データの位置を示す番号
4. Acknowledgment Number（32ビット）: 次に受信したいデータの位置
5. Data Offset（4ビット）: ヘッダー長（32ビットワード単位、最小値5 = 20バイト）
6. Flags（6ビット）: 制御フラグ（SYN、ACK、FIN等）
7. Window（16ビット）: 受信可能なデータ量（フロー制御）
8. Checksum（16ビット）: データの整合性確認

---

## ポート番号とは？

ポート番号は、1台のコンピュータ内でどのアプリケーションが通信するかを識別するための番号です。

### ポート番号の範囲

| 範囲 | 分類 | 用途 |
|------|------|------|
| 0〜1023 | ウェルノウンポート | 標準的なサービス（HTTP:80, HTTPS:443, SSH:22等） |
| 1024〜49151 | 登録済みポート | 特定のアプリケーション |
| 49152〜65535 | 動的ポート | クライアントが一時的に使用 |

例：Webブラウザ（ポート49152）→ Webサーバー（ポート80）

---

## TCPフラグ

TCPフラグは、接続の制御に使用されます。

| フラグ | 名前 | 意味 |
|--------|------|------|
| SYN | Synchronize | 接続確立の開始 |
| ACK | Acknowledgment | 確認応答 |
| FIN | Finish | 接続終了 |
| RST | Reset | 接続リセット |
| PSH | Push | データを即座に送信 |
| URG | Urgent | 緊急データ |

---

## 3-wayハンドシェイク

TCPは接続確立時に3-wayハンドシェイクを行います。

```text
クライアント                        サーバー
    |                                  |
    |  (1) SYN (Seq=100)               |
    |--------------------------------->|
    |                                  |
    |  (2) SYN-ACK (Seq=200, Ack=101)  |
    |<---------------------------------|
    |                                  |
    |  (3) ACK (Seq=101, Ack=201)      |
    |--------------------------------->|
    |                                  |
    |        接続確立完了               |
```

1. SYN: クライアントが接続要求（SYNフラグをセット）
2. SYN-ACK: サーバーが接続受諾（SYNとACKフラグをセット）
3. ACK: クライアントが確認応答（ACKフラグをセット）

---

## 疑似ヘッダーとは？

TCPのチェックサムは、TCPヘッダーとデータだけでなく、疑似ヘッダーも含めて計算します。疑似ヘッダーは、IPヘッダーの一部情報を含み、パケットが正しい宛先に届いたかを検証します。

```text
+--------+--------+--------+--------+
|           Source Address          |  (IPv4から)
+--------+--------+--------+--------+
|        Destination Address        |  (IPv4から)
+--------+--------+--------+--------+
|  zero  |  PTCL  |    TCP Length   |
+--------+--------+--------+--------+
```

---

## TODOリスト（Phase 4）

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
```

---

## モジュールのセットアップ

`src/tcp.rs`を作成します。

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn tcpパケットは20バイト未満を拒否する() {
        let short_data = [0u8; 19];
        assert!(TcpPacket::new(&short_data).is_none());
    }
}
```

重要: モジュール宣言を忘れずに！

### ライブラリプロジェクトの場合（src/lib.rs）

```rust
pub mod ethernet;
pub mod ipv4;
pub mod tcp;
```

### バイナリプロジェクトの場合（src/main.rs）

```rust
mod ethernet;
mod ipv4;
mod tcp;

fn main() {
    println!("Hello, world!");
}
```

---

## Iteration 16-20: 基本的なパーサー実装

### 構造体とnewメソッド

```rust
pub struct TcpPacket<'a> {
    data: &'a [u8],
}

impl<'a> TcpPacket<'a> {
    pub fn new(data: &'a [u8]) -> Option<Self> {
        if data.len() < 20 {
            return None;
        }
        Some(TcpPacket { data })
    }
}
```

### ポート番号の取得

```rust
#[test]
fn 送信元ポート番号を取得できる() {
    let mut data = [0u8; 20];
    data[0] = 0x00;
    data[1] = 0x50; // ポート80 (HTTP)

    let packet = TcpPacket::new(&data).unwrap();
    assert_eq!(packet.source_port(), 80);
}

#[test]
fn 宛先ポート番号を取得できる() {
    let mut data = [0u8; 20];
    data[2] = 0x1f;
    data[3] = 0x90; // ポート8080

    let packet = TcpPacket::new(&data).unwrap();
    assert_eq!(packet.destination_port(), 8080);
}
```

実装：

```rust
impl<'a> TcpPacket<'a> {
    pub fn source_port(&self) -> u16 {
        u16::from_be_bytes([self.data[0], self.data[1]])
    }

    pub fn destination_port(&self) -> u16 {
        u16::from_be_bytes([self.data[2], self.data[3]])
    }
}
```

---

## Iteration 21-23: シーケンス番号と確認応答番号

### テスト

```rust
#[test]
fn シーケンス番号を取得できる() {
    let mut data = [0u8; 20];
    data[4..8].copy_from_slice(&[0x00, 0x00, 0x00, 0x64]); // 100

    let packet = TcpPacket::new(&data).unwrap();
    assert_eq!(packet.sequence_number(), 100);
}

#[test]
fn 確認応答番号を取得できる() {
    let mut data = [0u8; 20];
    data[8..12].copy_from_slice(&[0x00, 0x00, 0x00, 0xc9]); // 201

    let packet = TcpPacket::new(&data).unwrap();
    assert_eq!(packet.acknowledgment_number(), 201);
}
```

### 実装

```rust
impl<'a> TcpPacket<'a> {
    pub fn sequence_number(&self) -> u32 {
        u32::from_be_bytes([
            self.data[4],
            self.data[5],
            self.data[6],
            self.data[7],
        ])
    }

    pub fn acknowledgment_number(&self) -> u32 {
        u32::from_be_bytes([
            self.data[8],
            self.data[9],
            self.data[10],
            self.data[11],
        ])
    }
}
```

---

## Iteration 24-26: フラグの判定

### TCPフラグのビット位置

```text
13バイト目のビット配置:
7 6 5 4 3 2 1 0
- - U A P R S F
      R C S S Y I
      G K H T N N
```

### テスト

```rust
#[test]
fn synフラグを判定できる() {
    let mut data = [0u8; 20];
    data[13] = 0x02; // SYNフラグ

    let packet = TcpPacket::new(&data).unwrap();
    assert!(packet.is_syn());
    assert!(!packet.is_ack());
}

#[test]
fn ackフラグを判定できる() {
    let mut data = [0u8; 20];
    data[13] = 0x10; // ACKフラグ

    let packet = TcpPacket::new(&data).unwrap();
    assert!(packet.is_ack());
    assert!(!packet.is_syn());
}

#[test]
fn syn_ackフラグを判定できる() {
    let mut data = [0u8; 20];
    data[13] = 0x12; // SYN + ACKフラグ

    let packet = TcpPacket::new(&data).unwrap();
    assert!(packet.is_syn());
    assert!(packet.is_ack());
}

#[test]
fn finフラグを判定できる() {
    let mut data = [0u8; 20];
    data[13] = 0x01; // FINフラグ

    let packet = TcpPacket::new(&data).unwrap();
    assert!(packet.is_fin());
}
```

### 実装

```rust
impl<'a> TcpPacket<'a> {
    pub fn is_syn(&self) -> bool {
        (self.data[13] & 0x02) != 0
    }

    pub fn is_ack(&self) -> bool {
        (self.data[13] & 0x10) != 0
    }

    pub fn is_fin(&self) -> bool {
        (self.data[13] & 0x01) != 0
    }

    pub fn is_rst(&self) -> bool {
        (self.data[13] & 0x04) != 0
    }
}
```

フラグの判定には、ビットマスクを使用します。`&`演算子でビットANDを取ることで、特定のフラグをチェックできます。具体的には、`0x02`はSYNフラグ（ビット1）、`0x10`はACKフラグ（ビット4）、`0x01`はFINフラグ（ビット0）を表しています。

---

## Iteration 27: ウィンドウサイズ

### テスト

```rust
#[test]
fn ウィンドウサイズを取得できる() {
    let mut data = [0u8; 20];
    data[14] = 0xff;
    data[15] = 0xff; // 65535

    let packet = TcpPacket::new(&data).unwrap();
    assert_eq!(packet.window_size(), 65535);
}
```

### 実装

```rust
impl<'a> TcpPacket<'a> {
    pub fn window_size(&self) -> u16 {
        u16::from_be_bytes([self.data[14], self.data[15]])
    }
}
```

---

## Iteration 28: ペイロードの取得

### テスト

```rust
#[test]
fn ペイロードを取得できる() {
    let mut data = vec![0u8; 30];
    data[12] = 0x50; // Data Offset = 5 (20バイト)
    data[20..30].copy_from_slice(b"HelloWorld");

    let packet = TcpPacket::new(&data).unwrap();
    assert_eq!(packet.payload(), b"HelloWorld");
}
```

### 実装

```rust
impl<'a> TcpPacket<'a> {
    pub fn header_length(&self) -> usize {
        let data_offset = (self.data[12] >> 4) as usize;
        data_offset * 4
    }

    pub fn payload(&self) -> &[u8] {
        let header_len = self.header_length();
        &self.data[header_len..]
    }
}
```

---

## Iteration 29: チェックサムの計算（疑似ヘッダー）

### 疑似ヘッダーを使ったチェックサム

TCPのチェックサムは、疑似ヘッダー + TCPヘッダー + データを含めて計算します。

### テスト

```rust
use std::net::Ipv4Addr;

#[test]
fn チェックサムを計算できる() {
    let tcp_data = vec![
        0x00, 0x50, // Source Port: 80
        0x1f, 0x90, // Destination Port: 8080
        0x00, 0x00, 0x00, 0x64, // Sequence: 100
        0x00, 0x00, 0x00, 0x00, // Acknowledgment: 0
        0x50, 0x02, // Data Offset: 5, Flags: SYN
        0xff, 0xff, // Window: 65535
        0x00, 0x00, // Checksum: 0 (計算前)
        0x00, 0x00, // Urgent Pointer: 0
    ];

    let src_ip = Ipv4Addr::new(192, 168, 1, 1);
    let dst_ip = Ipv4Addr::new(192, 168, 1, 2);

    let checksum = calculate_tcp_checksum(&tcp_data, src_ip, dst_ip);
    assert_ne!(checksum, 0);
}
```

### 実装

```rust
use std::net::Ipv4Addr;

pub fn calculate_tcp_checksum(tcp_segment: &[u8], src_ip: Ipv4Addr, dst_ip: Ipv4Addr) -> u16 {
    let mut sum: u32 = 0;

    // 疑似ヘッダーの追加
    for &byte in src_ip.octets().iter() {
        sum += byte as u32;
    }
    for &byte in dst_ip.octets().iter() {
        sum += byte as u32;
    }
    sum += 6; // Protocol: TCP
    sum += tcp_segment.len() as u32;

    // TCPセグメント全体を16ビットワードで加算
    for i in (0..tcp_segment.len()).step_by(2) {
        let word = if i + 1 < tcp_segment.len() {
            u16::from_be_bytes([tcp_segment[i], tcp_segment[i + 1]]) as u32
        } else {
            (tcp_segment[i] as u32) << 8
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

TCPチェックサムの計算には重要な特徴があります。疑似ヘッダーは実際のパケットには含まれず送信されませんが、チェックサム計算には含める必要があります。このため、IPv4ヘッダーから送信元IPアドレスと宛先IPアドレスを取得して使用します。

---

## Phase 4のまとめ

このフェーズでは、以下を学びました：

### TCPの理解

TCPプロトコルの核心的な機能を学びました。ポート番号によるアプリケーションの識別方法を理解し、SYN、ACK、FINなどのフラグによる接続制御の仕組みを習得しました。また、3-wayハンドシェイクによる接続確立のプロセスと、疑似ヘッダーを使ったチェックサム計算の実装方法を学びました。

### Rustの機能

Rustを使った実装技術を習得しました。ビット演算を使ったフラグの判定方法を学び、シーケンス番号などの32ビット整数の扱い方を理解しました。また、複雑なチェックサム計算を正確に実装する方法も習得しました。

### TDDの実践

TDDでの効果的な開発手法を実践しました。機能を段階的に追加することで、複雑な実装を確実に進められることを体験しました。また、各フラグごとに個別のテストを作成することで、複雑なロジック（チェックサム計算など）も小さく分割して実装できることを学びました。

---

## 次のステップ

Phase 4が完了しました！次は[Phase 5: パケットビルダー](./phase5-packet-builder.md)に進みましょう。

これまでパーサー（データの読み取り）を実装してきましたが、次はビルダー（データの構築）を実装します。パケットを自分で作れるようになることで、スタックの理解がさらに深まります。

---

## ナビゲーション

- 前へ：[Phase 3: IPv4パケットパーサー](./phase3-ipv4-packet.md)
- 次へ：[Phase 5: パケットビルダー](./phase5-packet-builder.md)
- ホーム：[README](../README.md)
