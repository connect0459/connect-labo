# 統合テスト

## このセクションで学ぶこと

このセクションでは、スタック全体を使った統合テストの方法を学びます。具体的には、3-wayハンドシェイクのシミュレーションを実装し、実践的なシナリオテストの書き方を習得します。また、Rustにおける統合テストの構成方法を理解します。

---

## 統合テストとは？

統合テスト（Integration Test）は、複数のモジュールやコンポーネントが正しく連携することを確認するテストです。

### ユニットテスト vs 統合テスト

| 項目 | ユニットテスト | 統合テスト |
|------|---------------|-----------|
| 対象 | 個別の関数・構造体 | 複数のモジュールの連携 |
| 粒度 | 小さい（関数レベル） | 大きい（機能レベル） |
| 実行速度 | 速い | 遅い |
| 目的 | ロジックの正しさ | 統合後の動作確認 |

TDDでは、ユニットテストを中心に進めつつ、最後に統合テストで全体の動作を確認します。

---

## Rustの統合テストディレクトリ

Rustでは、`tests/`ディレクトリに統合テストを配置します。

### プロジェクト構造

```text
rust-tcp-stack/
├── Cargo.toml
├── src/
│   ├── lib.rs または main.rs
│   ├── ethernet.rs
│   ├── ipv4.rs
│   └── tcp.rs
└── tests/
    └── integration_test.rs
```

### `tests/integration_test.rs`の作成

```rust
use rust_tcp_stack::ethernet::{EthernetFrame, EthernetFrameBuilder, MacAddress, EtherType};
use rust_tcp_stack::ipv4::{Ipv4Packet, Ipv4PacketBuilder, IpProtocol};
use rust_tcp_stack::tcp::{TcpPacket, TcpPacketBuilder, TcpFlags};
use std::net::Ipv4Addr;

#[test]
fn スタック全体をパースできる() {
    // テストコード
}
```

注意: 統合テストでは`use rust_tcp_stack::`のように、クレート名からインポートします。

---

## TODOリスト（統合テスト）

```text
統合テスト
□ Ethernet → IPv4 → TCP とパースできる
□ 逆順（TCP → IPv4 → Ethernet）で構築できる
□ 構築とパースの往復で同じになる
□ 3-wayハンドシェイクをシミュレートできる
```

---

## テスト1: スタック全体のパース

### 実際のパケットバイト列をパース

```rust
#[test]
fn スタック全体をパースできる() {
    // 実際のパケットバイト列を手動で構築
    let mut packet = Vec::new();

    // Ethernetヘッダー
    packet.extend_from_slice(&[0xff, 0xff, 0xff, 0xff, 0xff, 0xff]); // Dst MAC
    packet.extend_from_slice(&[0x00, 0x11, 0x22, 0x33, 0x44, 0x55]); // Src MAC
    packet.extend_from_slice(&[0x08, 0x00]); // EtherType: IPv4

    // IPv4ヘッダー (20バイト)
    packet.extend_from_slice(&[
        0x45, 0x00, 0x00, 0x28, // Version, IHL, ToS, Total Length (40バイト)
        0x00, 0x01, 0x00, 0x00, // Identification, Flags, Fragment Offset
        0x40, 0x06, 0x00, 0x00, // TTL (64), Protocol (TCP=6), Checksum
        0xc0, 0xa8, 0x01, 0x01, // Source IP: 192.168.1.1
        0xc0, 0xa8, 0x01, 0x02, // Destination IP: 192.168.1.2
    ]);

    // チェックサム計算して更新
    let ipv4_checksum = rust_tcp_stack::ipv4::calculate_ipv4_checksum(&packet[14..34]);
    packet[24..26].copy_from_slice(&ipv4_checksum.to_be_bytes());

    // TCPヘッダー (20バイト)
    packet.extend_from_slice(&[
        0x30, 0x39, // Source Port: 12345
        0x00, 0x50, // Destination Port: 80
        0x00, 0x00, 0x03, 0xe8, // Sequence Number: 1000
        0x00, 0x00, 0x00, 0x00, // Acknowledgment Number: 0
        0x50, 0x02, // Data Offset (5), Flags (SYN)
        0xff, 0xff, // Window Size: 65535
        0x00, 0x00, // Checksum
        0x00, 0x00, // Urgent Pointer
    ]);

    // TCPチェックサム計算して更新
    let tcp_checksum = rust_tcp_stack::tcp::calculate_tcp_checksum(
        &packet[34..],
        Ipv4Addr::new(192, 168, 1, 1),
        Ipv4Addr::new(192, 168, 1, 2),
    );
    packet[50..52].copy_from_slice(&tcp_checksum.to_be_bytes());

    // パース
    let eth_frame = EthernetFrame::new(&packet).unwrap();
    assert_eq!(eth_frame.ether_type(), EtherType::Ipv4);

    let ip_packet = Ipv4Packet::new(eth_frame.payload()).unwrap();
    assert_eq!(ip_packet.source(), Ipv4Addr::new(192, 168, 1, 1));
    assert_eq!(ip_packet.destination(), Ipv4Addr::new(192, 168, 1, 2));
    assert_eq!(ip_packet.protocol(), IpProtocol::Tcp);

    let tcp_packet = TcpPacket::new(ip_packet.payload()).unwrap();
    assert_eq!(tcp_packet.source_port(), 12345);
    assert_eq!(tcp_packet.destination_port(), 80);
    assert_eq!(tcp_packet.sequence_number(), 1000);
    assert!(tcp_packet.is_syn());
}
```

---

## テスト2: スタック全体の構築

### ビルダーで構築してパース

```rust
#[test]
fn スタック全体を構築できる() {
    let src_mac = MacAddress::new([0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
    let dst_mac = MacAddress::broadcast();
    let src_ip = Ipv4Addr::new(192, 168, 1, 1);
    let dst_ip = Ipv4Addr::new(192, 168, 1, 2);

    // TCP SYNセグメント
    let tcp_segment = TcpPacketBuilder::new()
        .source_port(12345)
        .destination_port(80)
        .sequence_number(1000)
        .flags(TcpFlags::SYN)
        .build_with_checksum(src_ip, dst_ip);

    // IPv4パケット
    let ipv4_packet = Ipv4PacketBuilder::new()
        .source(src_ip)
        .destination(dst_ip)
        .protocol(IpProtocol::Tcp)
        .payload(&tcp_segment)
        .build();

    // Ethernetフレーム
    let ethernet_frame = EthernetFrameBuilder::new()
        .source(src_mac)
        .destination(dst_mac)
        .ether_type(EtherType::Ipv4)
        .payload(&ipv4_packet)
        .build();

    // パースして検証
    let eth_frame = EthernetFrame::new(&ethernet_frame).unwrap();
    assert_eq!(eth_frame.destination(), dst_mac);
    assert_eq!(eth_frame.source(), src_mac);

    let ip_packet = Ipv4Packet::new(eth_frame.payload()).unwrap();
    assert_eq!(ip_packet.source(), src_ip);
    assert_eq!(ip_packet.destination(), dst_ip);

    let tcp_packet = TcpPacket::new(ip_packet.payload()).unwrap();
    assert_eq!(tcp_packet.source_port(), 12345);
    assert_eq!(tcp_packet.destination_port(), 80);
    assert!(tcp_packet.is_syn());
}
```

---

## テスト3: 構築とパースの往復

### ラウンドトリップテスト

```rust
#[test]
fn 構築とパースの往復で同じになる() {
    let original_src_mac = MacAddress::new([0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
    let original_dst_mac = MacAddress::new([0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]);
    let original_src_ip = Ipv4Addr::new(10, 0, 0, 1);
    let original_dst_ip = Ipv4Addr::new(10, 0, 0, 2);
    let original_src_port = 54321;
    let original_dst_port = 443;
    let original_seq = 99999;

    // 構築
    let tcp_segment = TcpPacketBuilder::new()
        .source_port(original_src_port)
        .destination_port(original_dst_port)
        .sequence_number(original_seq)
        .flags(TcpFlags::SYN)
        .build_with_checksum(original_src_ip, original_dst_ip);

    let ipv4_packet = Ipv4PacketBuilder::new()
        .source(original_src_ip)
        .destination(original_dst_ip)
        .protocol(IpProtocol::Tcp)
        .payload(&tcp_segment)
        .build();

    let ethernet_frame = EthernetFrameBuilder::new()
        .source(original_src_mac)
        .destination(original_dst_mac)
        .ether_type(EtherType::Ipv4)
        .payload(&ipv4_packet)
        .build();

    // パース
    let eth_frame = EthernetFrame::new(&ethernet_frame).unwrap();
    let ip_packet = Ipv4Packet::new(eth_frame.payload()).unwrap();
    let tcp_packet = TcpPacket::new(ip_packet.payload()).unwrap();

    // 検証: すべての値が元と一致
    assert_eq!(eth_frame.source(), original_src_mac);
    assert_eq!(eth_frame.destination(), original_dst_mac);
    assert_eq!(ip_packet.source(), original_src_ip);
    assert_eq!(ip_packet.destination(), original_dst_ip);
    assert_eq!(tcp_packet.source_port(), original_src_port);
    assert_eq!(tcp_packet.destination_port(), original_dst_port);
    assert_eq!(tcp_packet.sequence_number(), original_seq);
    assert!(tcp_packet.is_syn());
}
```

TDDにおいて、往復テストは非常に重要な技法です。ビルダーで構築したデータをパーサーで読み取り、元のデータと比較することで、ビルダーとパーサーの両方が正しいことを保証できます。また、データが変換プロセスを経ても情報が失われないことを確認できます。

---

## テスト4: 3-wayハンドシェイクのシミュレーション

### 実際のTCP接続確立を再現

```rust
#[test]
fn 3wayハンドシェイクをシミュレートできる() {
    let client_mac = MacAddress::new([0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
    let server_mac = MacAddress::new([0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]);
    let client_ip = Ipv4Addr::new(192, 168, 1, 100);
    let server_ip = Ipv4Addr::new(192, 168, 1, 1);
    let client_port = 54321;
    let server_port = 80;

    // Step 1: クライアント → サーバー (SYN)
    let syn_packet = create_full_packet(
        client_mac,
        server_mac,
        client_ip,
        server_ip,
        client_port,
        server_port,
        1000,  // Seq
        0,     // Ack
        TcpFlags::SYN,
    );

    // パース
    let eth = EthernetFrame::new(&syn_packet).unwrap();
    let ip = Ipv4Packet::new(eth.payload()).unwrap();
    let tcp = TcpPacket::new(ip.payload()).unwrap();

    assert!(tcp.is_syn());
    assert!(!tcp.is_ack());
    assert_eq!(tcp.sequence_number(), 1000);

    // Step 2: サーバー → クライアント (SYN-ACK)
    let syn_ack_packet = create_full_packet(
        server_mac,
        client_mac,
        server_ip,
        client_ip,
        server_port,
        client_port,
        2000,  // Seq
        1001,  // Ack (クライアントのSeq + 1)
        TcpFlags::SYN_ACK,
    );

    let eth = EthernetFrame::new(&syn_ack_packet).unwrap();
    let ip = Ipv4Packet::new(eth.payload()).unwrap();
    let tcp = TcpPacket::new(ip.payload()).unwrap();

    assert!(tcp.is_syn());
    assert!(tcp.is_ack());
    assert_eq!(tcp.sequence_number(), 2000);
    assert_eq!(tcp.acknowledgment_number(), 1001);

    // Step 3: クライアント → サーバー (ACK)
    let ack_packet = create_full_packet(
        client_mac,
        server_mac,
        client_ip,
        server_ip,
        client_port,
        server_port,
        1001,  // Seq (前回のSeq + 1)
        2001,  // Ack (サーバーのSeq + 1)
        TcpFlags::ACK,
    );

    let eth = EthernetFrame::new(&ack_packet).unwrap();
    let ip = Ipv4Packet::new(eth.payload()).unwrap();
    let tcp = TcpPacket::new(ip.payload()).unwrap();

    assert!(!tcp.is_syn());
    assert!(tcp.is_ack());
    assert_eq!(tcp.sequence_number(), 1001);
    assert_eq!(tcp.acknowledgment_number(), 2001);
}

// ヘルパー関数
fn create_full_packet(
    src_mac: MacAddress,
    dst_mac: MacAddress,
    src_ip: Ipv4Addr,
    dst_ip: Ipv4Addr,
    src_port: u16,
    dst_port: u16,
    seq: u32,
    ack: u32,
    flags: TcpFlags,
) -> Vec<u8> {
    let tcp_segment = TcpPacketBuilder::new()
        .source_port(src_port)
        .destination_port(dst_port)
        .sequence_number(seq)
        .acknowledgment_number(ack)
        .flags(flags)
        .build_with_checksum(src_ip, dst_ip);

    let ipv4_packet = Ipv4PacketBuilder::new()
        .source(src_ip)
        .destination(dst_ip)
        .protocol(IpProtocol::Tcp)
        .payload(&tcp_segment)
        .build();

    EthernetFrameBuilder::new()
        .source(src_mac)
        .destination(dst_mac)
        .ether_type(EtherType::Ipv4)
        .payload(&ipv4_packet)
        .build()
}
```

このテストには3つの重要なポイントがあります。まず、3-wayハンドシェイクの各ステップ（SYN、SYN-ACK、ACK）を正確に再現しています。次に、シーケンス番号と確認応答番号の関係性が正しいことを検証しています。最後に、ヘルパー関数を導入することでテストコードの重複を削減し、保守性を向上させています。

---

## 統合テストの実行

### テストの実行

```bash
# すべてのテスト（ユニット + 統合）
cargo test

# 統合テストのみ
cargo test --test integration_test

# 特定のテスト
cargo test 3wayハンドシェイク
```

### 成功例

```text
running 4 tests
test スタック全体をパースできる ... ok
test スタック全体を構築できる ... ok
test 構築とパースの往復で同じになる ... ok
test 3wayハンドシェイクをシミュレートできる ... ok

test result: ok. 4 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out
```

---

## 統合テストのベストプラクティス

### 1. シナリオベースのテスト

実際の使用シナリオを再現する：

- 接続確立（3-wayハンドシェイク）
- データ送受信
- 接続終了（4-wayハンドシェイク）

### 2. エッジケースのテスト

- 不正なデータの処理
- 境界値（最大パケットサイズ等）
- エラーハンドリング

### 3. パフォーマンステスト

- 大量のパケット処理
- メモリ使用量の確認

---

## 統合テストのまとめ

このセクションでは、以下を学びました：

### 統合テストの重要性

統合テストの価値を理解しました。個別のコンポーネントが正しく動作するだけでなく、全体が連携して動作することを確認する重要性を学びました。また、実際の使用シナリオを再現することで、現実的な問題を早期に発見できることを体験しました。

### TDDの完成

TDDの全体像を理解しました。ユニットテストで個別の機能を検証し、統合テストで全体の動作を確認するという、完全なテスト戦略を実践しました。

### 実践的なスキル

実践的なテスト技法を習得しました。3-wayハンドシェイクの実装を通じてプロトコルの理解を深め、ヘルパー関数によるテストの効率化手法を学びました。また、往復テストによる双方向の検証パターンも習得しました。

---

## 次のステップ

統合テストが完了しました！次は[まとめと次のステップ](./summary.md)に進みましょう。

ここまでのハンズオンを振り返り、学んだこと、さらなる学習の方向性について確認します。

---

## ナビゲーション

- 前へ：[Phase 5: パケットビルダー](./phase5-packet-builder.md)
- 次へ：[まとめと次のステップ](./summary.md)
- ホーム：[README](../README.md)
