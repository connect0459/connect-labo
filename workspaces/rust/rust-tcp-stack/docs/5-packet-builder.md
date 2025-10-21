# Phase 5: パケットビルダー（TDDで）

## このフェーズで学ぶこと

このフェーズでは、パケットを構築（ビルド）する実装方法を学びます。具体的には、ビルダーパターンを活用した実装を行い、パーサーとビルダーを組み合わせた往復テストによって、完全なパケットを作成できるようになります。

---

## パケットビルダーとは？

これまでのフェーズでは、バイト列からパケットを読み取る（パース）機能を実装しました。Phase 5では、パケットを構築する（ビルド）機能を実装します。

### パーサー vs ビルダー

```text
パーサー（Parser）:
  バイト列 → 構造化データ
  [0xaa, 0xbb, ...] → MacAddress, EthernetFrame, Ipv4Packet, TcpPacket

ビルダー（Builder）:
  構造化データ → バイト列
  MacAddress, EthernetFrame, ... → [0xaa, 0xbb, ...]
```

### ビルダーの用途

ビルダーは主に3つの用途で使用されます。まず、実際のネットワークにパケットを送信する際にパケットを構築します。次に、ユニットテストや結合テストで使用するテストデータを作成します。さらに、ルーターでのTTL減算のように、既存のパケットを変更する際にも活用できます。

---

## ビルダーパターン

ビルダーパターンは、複雑なオブジェクトを段階的に構築するデザインパターンです。

### 利点

ビルダーパターンには3つの主要な利点があります。第一に、メソッドチェーンを使うことでコードの意図が明確になり可読性が向上します。第二に、必須フィールドとオプションフィールドを区別できるため、柔軟なオブジェクト構築が可能になります。第三に、一度構築したオブジェクトを変更できないようにすることで、不変性を保証できます。

### 基本的な使い方

```rust
let frame = EthernetFrameBuilder::new()
    .destination(dst_mac)
    .source(src_mac)
    .ether_type(EtherType::Ipv4)
    .payload(&data)
    .build();
```

---

## TODOリスト（Phase 5）

```text
Ethernetフレームビルダー
□ ヘッダーのみのフレームを構築できる
□ ペイロード付きフレームを構築できる
□ 構築したフレームをパースして検証できる

IPv4パケットビルダー
□ 基本的なIPv4パケットを構築できる
□ チェックサムを自動計算できる
□ 構築したパケットをパースして検証できる

TCPセグメントビルダー
□ 基本的なTCPセグメントを構築できる
□ フラグを設定できる
□ チェックサムを自動計算できる（疑似ヘッダー含む）
□ 構築したセグメントをパースして検証できる
```

---

## Iteration 30: Ethernetフレームビルダー

### Step 1: テストを書く（Red）

`src/ethernet.rs`に追加。

```rust
#[test]
fn ethernetフレームを構築できる() {
    let src = MacAddress::new([0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
    let dst = MacAddress::broadcast();

    let builder = EthernetFrameBuilder::new()
        .destination(dst)
        .source(src)
        .ether_type(EtherType::Ipv4);

    let frame_bytes = builder.build();

    assert_eq!(frame_bytes.len(), 14);
    assert_eq!(&frame_bytes[0..6], &[0xff, 0xff, 0xff, 0xff, 0xff, 0xff]);
    assert_eq!(&frame_bytes[6..12], &[0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
    assert_eq!(&frame_bytes[12..14], &[0x08, 0x00]); // IPv4
}
```

### Step 2-4: Red → Green

```rust
pub struct EthernetFrameBuilder {
    destination: MacAddress,
    source: MacAddress,
    ether_type: EtherType,
    payload: Vec<u8>,
}

impl EthernetFrameBuilder {
    pub fn new() -> Self {
        EthernetFrameBuilder {
            destination: MacAddress([0; 6]),
            source: MacAddress([0; 6]),
            ether_type: EtherType::Ipv4,
            payload: Vec::new(),
        }
    }

    pub fn destination(mut self, mac: MacAddress) -> Self {
        self.destination = mac;
        self
    }

    pub fn source(mut self, mac: MacAddress) -> Self {
        self.source = mac;
        self
    }

    pub fn ether_type(mut self, ether_type: EtherType) -> Self {
        self.ether_type = ether_type;
        self
    }

    pub fn payload(mut self, data: &[u8]) -> Self {
        self.payload = data.to_vec();
        self
    }

    pub fn build(self) -> Vec<u8> {
        let mut bytes = Vec::with_capacity(14 + self.payload.len());

        // 宛先MAC
        bytes.extend_from_slice(&self.destination.0);

        // 送信元MAC
        bytes.extend_from_slice(&self.source.0);

        // EtherType
        let ether_type_value = match self.ether_type {
            EtherType::Ipv4 => 0x0800u16,
            EtherType::Arp => 0x0806u16,
            EtherType::Unknown(v) => v,
        };
        bytes.extend_from_slice(&ether_type_value.to_be_bytes());

        // ペイロード
        bytes.extend_from_slice(&self.payload);

        bytes
    }
}
```

この実装のポイントは3つあります。まず、ビルダーパターンでは各メソッドが`mut self`を引数に取り、変更後のselfを返すことで状態を更新します。次に、各メソッドが`self`を返すことでメソッドチェーンが可能になり、流暢なインターフェースを実現しています。最後に、`to_be_bytes()`メソッドを使ってu16型の値をビッグエンディアンのバイト列に変換しています。

#### なぜこのコードを書くのか？

#### 1. ビルダーパターンの仕組み

ビルダーパターンは、`mut self`を取って`self`を返すメソッドチェーンによって実現されます。この設計により、直感的で読みやすいAPIを提供できます。

```rust
pub fn destination(mut self, mac: MacAddress) -> Self {
    self.destination = mac;  // フィールドを変更
    self                      // 変更後の自分自身を返す
}
```

重要なポイント。

- `mut self`: 値渡しで自分自身の所有権を受け取り、変更可能にする
- `self`を返す: 所有権を呼び出し側に返すことで、次のメソッド呼び出しが可能になる

これにより、メソッドチェーンが実現されます。

```rust
let frame = EthernetFrameBuilder::new()
    .destination(dst)  // selfを受け取り、変更して返す
    .source(src)       // ↑で返されたselfを受け取り、変更して返す
    .ether_type(...)   // ↑で返されたselfを受け取り、変更して返す
    .build();          // 最終的にVec<u8>を返す
```

#### 2. なぜ`mut self`なのか

Rustでは、メソッドの第一引数として以下の3つの選択肢があります。

```rust
// 1. 参照を借用（&self）
fn get_destination(&self) -> MacAddress {
    self.destination
}

// 2. 可変参照を借用（&mut self）
fn set_destination(&mut self, mac: MacAddress) {
    self.destination = mac;
}

// 3. 所有権を移動（mut self）
fn destination(mut self, mac: MacAddress) -> Self {
    self.destination = mac;
    self
}
```

ビルダーパターンでは、3番目の`mut self`を使います。理由は。

所有権の移動: メソッドチェーン中、各メソッドが所有権を受け取って返す

```rust
// ビルダーの所有権の流れ:
let builder = EthernetFrameBuilder::new();  // builder作成
let builder = builder.destination(dst);      // 所有権移動 → 返却
let builder = builder.source(src);           // 所有権移動 → 返却
let frame = builder.build();                 // 所有権消費 → Vec<u8>生成
```

不変性の保証: 中間状態のビルダーを再利用できない（意図しない変更を防ぐ）

```rust
let builder = EthernetFrameBuilder::new();
let builder2 = builder.destination(dst);
// ここで builder は使えなくなる（所有権が移動した）
// builder.source(src);  // コンパイルエラー！
```

#### 3. build()メソッドの実装

`build()`メソッドは、ビルダーの状態から最終的なバイト列を生成します。

```rust
pub fn build(self) -> Vec<u8> {
    let mut bytes = Vec::with_capacity(14 + self.payload.len());

    // 宛先MAC（6バイト）
    bytes.extend_from_slice(&self.destination.0);

    // 送信元MAC（6バイト）
    bytes.extend_from_slice(&self.source.0);

    // EtherType（2バイト、ビッグエンディアン）
    let ether_type_value = match self.ether_type {
        EtherType::Ipv4 => 0x0800u16,
        EtherType::Arp => 0x0806u16,
        EtherType::Unknown(v) => v,
    };
    bytes.extend_from_slice(&ether_type_value.to_be_bytes());

    // ペイロード（可変長）
    bytes.extend_from_slice(&self.payload);

    bytes
}
```

重要なポイント。

効率的なメモリ確保: `Vec::with_capacity()`で事前にメモリを確保し、再割り当てを防ぐ

```rust
// 事前にサイズが分かっているので、一度だけメモリ確保
let mut bytes = Vec::with_capacity(14 + self.payload.len());
```

ビッグエンディアン変換: `to_be_bytes()`でネットワークバイトオーダー（ビッグエンディアン）に変換

```rust
let value = 0x0800u16;
let bytes = value.to_be_bytes();  // [0x08, 0x00]
```

#### 4. なぜビッグエンディアンなのか

ネットワークプロトコルでは、マルチバイトの数値は常にビッグエンディアン（Big-Endian）で送信されます。これは「ネットワークバイトオーダー」とも呼ばれます。

```text
値: 0x0800 (16進数)

ビッグエンディアン（ネットワーク）:
バイト位置: [0]   [1]
値:        0x08  0x00
           ↑     ↑
         上位   下位

リトルエンディアン（多くのCPU）:
バイト位置: [0]   [1]
値:        0x00  0x08
           ↑     ↑
         下位   上位
```

Rustの`to_be_bytes()`メソッドは、現在のCPUアーキテクチャに関係なく、常にビッグエンディアンのバイト列を生成します。

```rust
let value = 0x0800u16;

// CPUがリトルエンディアンでも...
let bytes = value.to_be_bytes();
// 結果は常に [0x08, 0x00]（ビッグエンディアン）
```

#### 5. デフォルト値の設計

ビルダーの`new()`メソッドでは、各フィールドにデフォルト値を設定します。

```rust
pub fn new() -> Self {
    EthernetFrameBuilder {
        destination: MacAddress([0; 6]),  // ゼロアドレス
        source: MacAddress([0; 6]),       // ゼロアドレス
        ether_type: EtherType::Ipv4,      // 最も一般的なタイプ
        payload: Vec::new(),              // 空のペイロード
    }
}
```

この設計により。

- すべてのフィールドに安全な初期値が設定される
- ユーザーは必要なフィールドだけを設定できる
- テストコードが簡潔になる

```rust
// デフォルト値のおかげで、必要なフィールドだけ設定
let frame = EthernetFrameBuilder::new()
    .destination(dst)
    .source(src)
    // ether_typeはデフォルトのIpv4
    // payloadはデフォルトの空
    .build();
```

---

## Iteration 31: パーサーとの往復テスト

### ビルドしたデータをパースして検証

```rust
#[test]
fn ビルドしたフレームをパースできる() {
    let src = MacAddress::new([0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);
    let dst = MacAddress::new([0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]);
    let payload = b"Hello, Ethernet!";

    let frame_bytes = EthernetFrameBuilder::new()
        .destination(dst)
        .source(src)
        .ether_type(EtherType::Ipv4)
        .payload(payload)
        .build();

    // パース
    let frame = EthernetFrame::new(&frame_bytes).unwrap();

    // 検証
    assert_eq!(frame.destination(), dst);
    assert_eq!(frame.source(), src);
    assert_eq!(frame.ether_type(), EtherType::Ipv4);
    assert_eq!(frame.payload(), payload);
}
```

TDDにおいて、このような往復テストは非常に重要です。ビルダーで構築したデータをパーサーで読み取ることで、自分で作ったデータを自分で正しく解釈できることを確認します。このアプローチにより、ビルダーとパーサー両方の実装が正しいことを同時に検証でき、一方の実装に問題があればテストが失敗することで早期に発見できます。

---

## Iteration 32: IPv4パケットビルダー

`src/ipv4.rs`に追加。

### テスト

```rust
use std::net::Ipv4Addr;

#[test]
fn ipv4パケットを構築できる() {
    let src_ip = Ipv4Addr::new(192, 168, 1, 1);
    let dst_ip = Ipv4Addr::new(192, 168, 1, 2);
    let payload = b"Hello, IPv4!";

    let packet_bytes = Ipv4PacketBuilder::new()
        .source(src_ip)
        .destination(dst_ip)
        .protocol(IpProtocol::Tcp)
        .payload(payload)
        .build();

    // パース
    let packet = Ipv4Packet::new(&packet_bytes).unwrap();

    // 検証
    assert_eq!(packet.source(), src_ip);
    assert_eq!(packet.destination(), dst_ip);
    assert_eq!(packet.protocol(), IpProtocol::Tcp);
    assert_eq!(packet.payload(), payload);
}
```

### 実装

```rust
pub struct Ipv4PacketBuilder {
    source: Ipv4Addr,
    destination: Ipv4Addr,
    protocol: IpProtocol,
    ttl: u8,
    payload: Vec<u8>,
}

impl Ipv4PacketBuilder {
    pub fn new() -> Self {
        Ipv4PacketBuilder {
            source: Ipv4Addr::new(0, 0, 0, 0),
            destination: Ipv4Addr::new(0, 0, 0, 0),
            protocol: IpProtocol::Tcp,
            ttl: 64,
            payload: Vec::new(),
        }
    }

    pub fn source(mut self, ip: Ipv4Addr) -> Self {
        self.source = ip;
        self
    }

    pub fn destination(mut self, ip: Ipv4Addr) -> Self {
        self.destination = ip;
        self
    }

    pub fn protocol(mut self, protocol: IpProtocol) -> Self {
        self.protocol = protocol;
        self
    }

    pub fn ttl(mut self, ttl: u8) -> Self {
        self.ttl = ttl;
        self
    }

    pub fn payload(mut self, data: &[u8]) -> Self {
        self.payload = data.to_vec();
        self
    }

    pub fn build(self) -> Vec<u8> {
        let total_length = 20 + self.payload.len();
        let mut bytes = vec![0u8; total_length];

        // Version (4) + IHL (5)
        bytes[0] = 0x45;

        // Total Length
        bytes[2..4].copy_from_slice(&(total_length as u16).to_be_bytes());

        // TTL
        bytes[8] = self.ttl;

        // Protocol
        let protocol_value = match self.protocol {
            IpProtocol::Icmp => 1,
            IpProtocol::Tcp => 6,
            IpProtocol::Udp => 17,
            IpProtocol::Unknown(v) => v,
        };
        bytes[9] = protocol_value;

        // Source IP
        bytes[12..16].copy_from_slice(&self.source.octets());

        // Destination IP
        bytes[16..20].copy_from_slice(&self.destination.octets());

        // Checksum計算（10-11バイト目は0のまま）
        let checksum = super::ipv4::calculate_ipv4_checksum(&bytes[..20]);
        bytes[10..12].copy_from_slice(&checksum.to_be_bytes());

        // Payload
        bytes[20..].copy_from_slice(&self.payload);

        bytes
    }
}
```

IPv4パケットビルダーでは、2つの重要な自動計算を行っています。まず、ヘッダーを構築した後にチェックサムを計算し、適切な位置に埋め込みます。これにより、ユーザーが手動でチェックサムを計算する必要がなくなります。また、Total Lengthフィールドも自動的に計算されます。これはヘッダーサイズ（20バイト）とペイロードの長さを合計したものです。

#### なぜこのコードを書くのか？

#### 1. チェックサムの自動計算

ビルダーパターンの大きな利点の一つは、複雑な計算をユーザーから隠蔽できることです。IPv4パケットでは、チェックサムの計算が必要ですが、ユーザーは意識する必要がありません。

```rust
// ユーザー側のコード（チェックサムを意識しない）
let packet = Ipv4PacketBuilder::new()
    .source(src_ip)
    .destination(dst_ip)
    .payload(&data)
    .build();  // build()内で自動的にチェックサムが計算される
```

`build()`メソッド内部の処理。

```rust
pub fn build(self) -> Vec<u8> {
    // 1. ヘッダーを構築（チェックサムは0）
    bytes[10..12].copy_from_slice(&[0x00, 0x00]);

    // 2. チェックサムを計算
    let checksum = calculate_ipv4_checksum(&bytes[..20]);

    // 3. チェックサムフィールドに埋め込む
    bytes[10..12].copy_from_slice(&checksum.to_be_bytes());

    bytes
}
```

この自動計算により、ユーザーは以下のエラーを回避できます。

- チェックサムの計算忘れ
- チェックサムの計算ミス
- チェックサムの埋め込み位置ミス

#### 2. Total Lengthの自動計算

Total Lengthフィールドも自動的に計算されます。

```rust
let total_length = 20 + self.payload.len();
bytes[2..4].copy_from_slice(&(total_length as u16).to_be_bytes());
```

これにより、ペイロードのサイズが変わっても常に正しいTotal Lengthが設定されます。

#### 3. octets()メソッドの利用

`Ipv4Addr`型には、IPアドレスをバイト配列に変換する`octets()`メソッドがあります。

```rust
let ip = Ipv4Addr::new(192, 168, 1, 1);
let bytes = ip.octets();  // [192, 168, 1, 1]

// ビルダー内での使用
bytes[12..16].copy_from_slice(&self.source.octets());
```

---

## Iteration 33: TCPセグメントビルダー

`src/tcp.rs`に追加。

### テスト

```rust
#[test]
fn tcpセグメントを構築できる() {
    let src_port = 12345;
    let dst_port = 80;
    let seq = 100;
    let ack = 0;

    let segment_bytes = TcpPacketBuilder::new()
        .source_port(src_port)
        .destination_port(dst_port)
        .sequence_number(seq)
        .acknowledgment_number(ack)
        .flags(TcpFlags::SYN)
        .build();

    // パース
    let segment = TcpPacket::new(&segment_bytes).unwrap();

    // 検証
    assert_eq!(segment.source_port(), src_port);
    assert_eq!(segment.destination_port(), dst_port);
    assert_eq!(segment.sequence_number(), seq);
    assert!(segment.is_syn());
    assert!(!segment.is_ack());
}
```

### 実装

```rust
pub struct TcpFlags {
    pub syn: bool,
    pub ack: bool,
    pub fin: bool,
    pub rst: bool,
}

impl TcpFlags {
    pub const SYN: Self = TcpFlags {
        syn: true,
        ack: false,
        fin: false,
        rst: false,
    };

    pub const SYN_ACK: Self = TcpFlags {
        syn: true,
        ack: true,
        fin: false,
        rst: false,
    };

    pub const ACK: Self = TcpFlags {
        syn: false,
        ack: true,
        fin: false,
        rst: false,
    };

    pub const FIN_ACK: Self = TcpFlags {
        syn: false,
        ack: true,
        fin: true,
        rst: false,
    };

    fn to_byte(&self) -> u8 {
        let mut flags = 0u8;
        if self.fin {
            flags |= 0x01;
        }
        if self.syn {
            flags |= 0x02;
        }
        if self.rst {
            flags |= 0x04;
        }
        if self.ack {
            flags |= 0x10;
        }
        flags
    }
}

pub struct TcpPacketBuilder {
    source_port: u16,
    destination_port: u16,
    sequence_number: u32,
    acknowledgment_number: u32,
    flags: TcpFlags,
    window_size: u16,
    payload: Vec<u8>,
}

impl TcpPacketBuilder {
    pub fn new() -> Self {
        TcpPacketBuilder {
            source_port: 0,
            destination_port: 0,
            sequence_number: 0,
            acknowledgment_number: 0,
            flags: TcpFlags::ACK,
            window_size: 65535,
            payload: Vec::new(),
        }
    }

    pub fn source_port(mut self, port: u16) -> Self {
        self.source_port = port;
        self
    }

    pub fn destination_port(mut self, port: u16) -> Self {
        self.destination_port = port;
        self
    }

    pub fn sequence_number(mut self, seq: u32) -> Self {
        self.sequence_number = seq;
        self
    }

    pub fn acknowledgment_number(mut self, ack: u32) -> Self {
        self.acknowledgment_number = ack;
        self
    }

    pub fn flags(mut self, flags: TcpFlags) -> Self {
        self.flags = flags;
        self
    }

    pub fn window_size(mut self, window: u16) -> Self {
        self.window_size = window;
        self
    }

    pub fn payload(mut self, data: &[u8]) -> Self {
        self.payload = data.to_vec();
        self
    }

    pub fn build(self) -> Vec<u8> {
        let total_length = 20 + self.payload.len();
        let mut bytes = vec![0u8; total_length];

        // Source Port
        bytes[0..2].copy_from_slice(&self.source_port.to_be_bytes());

        // Destination Port
        bytes[2..4].copy_from_slice(&self.destination_port.to_be_bytes());

        // Sequence Number
        bytes[4..8].copy_from_slice(&self.sequence_number.to_be_bytes());

        // Acknowledgment Number
        bytes[8..12].copy_from_slice(&self.acknowledgment_number.to_be_bytes());

        // Data Offset (5 = 20 bytes) + Reserved
        bytes[12] = 0x50;

        // Flags
        bytes[13] = self.flags.to_byte();

        // Window Size
        bytes[14..16].copy_from_slice(&self.window_size.to_be_bytes());

        // Checksum (0で初期化、後で計算する場合は別途)
        bytes[16..18].copy_from_slice(&[0, 0]);

        // Payload
        bytes[20..].copy_from_slice(&self.payload);

        bytes
    }

    // 疑似ヘッダーを使ったチェックサム付きビルド
    pub fn build_with_checksum(self, src_ip: Ipv4Addr, dst_ip: Ipv4Addr) -> Vec<u8> {
        let mut bytes = self.build();

        // チェックサム計算
        let checksum = super::tcp::calculate_tcp_checksum(&bytes, src_ip, dst_ip);
        bytes[16..18].copy_from_slice(&checksum.to_be_bytes());

        bytes
    }
}
```

TCPセグメントビルダーには3つの重要な設計上のポイントがあります。まず、`TcpFlags`構造体を導入することで、個々のフラグビットを扱いやすくしています。次に、SYNやSYN_ACKなど、よく使われるフラグの組み合わせを定数として定義することで、コードの可読性を向上させています。最後に、`build_with_checksum`メソッドはIPv4ヘッダー情報（送信元・宛先IPアドレス）を受け取り、疑似ヘッダーを含めた正しいチェックサムを計算します。

#### なぜこのコードを書くのか？

#### 1. TcpFlags構造体の設計理由

TCPフラグをビット操作で直接扱うのではなく、構造体として定義することで、コードの可読性と安全性が向上します。

```rust
// ビット操作（読みにくい）
let flags = 0x02;  // これが何を意味するか分からない

// 構造体（読みやすい）
let flags = TcpFlags::SYN;  // SYNフラグだと一目瞭然
```

`TcpFlags`構造体の定義。

```rust
pub struct TcpFlags {
    pub syn: bool,
    pub ack: bool,
    pub fin: bool,
    pub rst: bool,
}
```

よく使われる組み合わせを定数として定義。

```rust
impl TcpFlags {
    pub const SYN: Self = TcpFlags {
        syn: true, ack: false, fin: false, rst: false,
    };

    pub const SYN_ACK: Self = TcpFlags {
        syn: true, ack: true, fin: false, rst: false,
    };
}
```

使用例。

```rust
// 3-way handshake
let syn = TcpPacketBuilder::new().flags(TcpFlags::SYN).build();
let syn_ack = TcpPacketBuilder::new().flags(TcpFlags::SYN_ACK).build();
let ack = TcpPacketBuilder::new().flags(TcpFlags::ACK).build();
```

#### 2. to_byte()メソッドによるビット変換

`TcpFlags`をバイト値に変換する`to_byte()`メソッド。

```rust
fn to_byte(&self) -> u8 {
    let mut flags = 0u8;
    if self.fin { flags |= 0x01; }
    if self.syn { flags |= 0x02; }
    if self.rst { flags |= 0x04; }
    if self.ack { flags |= 0x10; }
    flags
}
```

ビット位置。

```text
TCPフラグフィールド（8ビット）:

ビット位置:  7  6  5  4  3  2  1  0
           +--+--+--+--+--+--+--+--+
           |...|...|...|ACK|...|RST|SYN|FIN|
           +--+--+--+--+--+--+--+--+
                    16   8   4   2   1  (値)

OR演算で各フラグを設定:
flags = 0x00  (0000 0000)
flags |= 0x02 (0000 0010) → SYN
flags |= 0x10 (0001 0000) → ACK
結果: 0x12    (0001 0010) → SYN + ACK
```

#### 3. build_with_checksum()メソッド

TCPチェックサムは疑似ヘッダーを含むため、IPアドレス情報が必要です。そのため、2つのbuildメソッドを提供します。

```rust
// 通常のbuild（チェックサム0）
pub fn build(self) -> Vec<u8> {
    // チェックサムフィールドは0のまま
    bytes[16..18].copy_from_slice(&[0, 0]);
    bytes
}

// チェックサム付きbuild
pub fn build_with_checksum(self, src_ip: Ipv4Addr, dst_ip: Ipv4Addr) -> Vec<u8> {
    let mut bytes = self.build();

    // IPアドレスを使ってチェックサムを計算
    let checksum = calculate_tcp_checksum(&bytes, src_ip, dst_ip);
    bytes[16..18].copy_from_slice(&checksum.to_be_bytes());

    bytes
}
```

使い分け。

```rust
// テスト時など、チェックサムが不要な場合
let segment = TcpPacketBuilder::new().build();

// 実際の通信で使う場合（チェックサム必須）
let segment = TcpPacketBuilder::new()
    .build_with_checksum(src_ip, dst_ip);
```

#### 4. Data Offsetフィールドの設定

Data Offsetは、TCPヘッダーの長さを32ビットワード単位で表します（IPv4のIHLと同じ概念）。

```rust
// Data Offset (5 = 20 bytes) + Reserved
bytes[12] = 0x50;
```

詳細。

```text
バイト12の構造:
+--------+--------+
| Data   |Reserved|
| Offset | (4bit) |
| (4bit) |        |
+--------+--------+
  0x5      0x0

0x50 = 0101 0000
       ^^^^ ^^^^
       5    0

Data Offset = 5
ヘッダー長 = 5 × 4 = 20バイト
```

---

## Iteration 34: 完全なパケットの構築

### 3-wayハンドシェイクのSYNパケット

```rust
#[test]
fn 完全なsynパケットを構築できる() {
    // TCP SYN
    let tcp_segment = TcpPacketBuilder::new()
        .source_port(12345)
        .destination_port(80)
        .sequence_number(1000)
        .flags(TcpFlags::SYN)
        .build_with_checksum(
            Ipv4Addr::new(192, 168, 1, 1),
            Ipv4Addr::new(192, 168, 1, 2),
        );

    // IPv4パケット
    let ipv4_packet = Ipv4PacketBuilder::new()
        .source(Ipv4Addr::new(192, 168, 1, 1))
        .destination(Ipv4Addr::new(192, 168, 1, 2))
        .protocol(IpProtocol::Tcp)
        .payload(&tcp_segment)
        .build();

    // Ethernetフレーム
    let ethernet_frame = EthernetFrameBuilder::new()
        .source(MacAddress::new([0x00, 0x11, 0x22, 0x33, 0x44, 0x55]))
        .destination(MacAddress::new([0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]))
        .ether_type(EtherType::Ipv4)
        .payload(&ipv4_packet)
        .build();

    // 全体をパースして検証
    let eth_frame = EthernetFrame::new(&ethernet_frame).unwrap();
    let ip_packet = Ipv4Packet::new(eth_frame.payload()).unwrap();
    let tcp_packet = TcpPacket::new(ip_packet.payload()).unwrap();

    assert_eq!(tcp_packet.source_port(), 12345);
    assert_eq!(tcp_packet.destination_port(), 80);
    assert!(tcp_packet.is_syn());
}
```

このテストはTCPスタック全体の統合性を検証しています。TCP、IPv4、Ethernetの各層のビルダーを組み合わせて完全なパケットを構築し、それを各層のパーサーで逆にパースすることで、スタック全体が正しく連携していることを確認します。

---

## Phase 5のまとめ

このフェーズでは、以下を学びました。

### ビルダーパターンの実装

ビルダーパターンを実装することで、メソッドチェーンによる直感的なAPIを提供できました。また、必須フィールドとオプションフィールドを明確に区別し、段階的にオブジェクトを構築できる柔軟な設計を実現しました。

### パーサーとビルダーの往復

ビルダーで構築したデータをパーサーで読み取る往復テストを実装しました。これにより、ビルダーとパーサー両方の実装が正しいことを確認でき、さらに各層を組み合わせて完全なパケットを構築できることを検証しました。

### TCP/IPスタック全体の理解

Ethernet、IPv4、TCPという階層構造を理解し、各層がどのようにカプセル化されるかを学びました。また、IPv4ヘッダーチェックサムやTCP疑似ヘッダーチェックサムの計算方法と、それらをパケットに埋め込む実装についても習得しました。

---

## 次のステップ

Phase 5が完了しました！次は[統合テスト](./integration-testing.md)に進みましょう。

統合テストでは、スタック全体を使った実践的なシナリオ（3-wayハンドシェイク、データ送受信等）をテストします。これにより、実際のネットワーク通信をシミュレートできます。

---

## ナビゲーション

- 前へ：[Phase 4: TCPパケットパーサー](./phase4-tcp-packet.md)
- 次へ：[統合テスト](./integration-testing.md)
- ホーム：[README](../README.md)
